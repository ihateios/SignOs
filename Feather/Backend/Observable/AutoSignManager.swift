//
//  AutoSignManager.swift
//  Feather
//
//  Serial background signing queue. Imported/updated/renewal apps are
//  signed with the correct certificate without any user interaction,
//  old versions are cleaned up, and installation is attempted
//  immediately when the active installation method supports it.
//

import Foundation
import CoreData
import IDeviceSwift

@MainActor
final class AutoSignManager: ObservableObject {
	static let shared = AutoSignManager()

	enum Reason: String {
		case autoSign
		case autoUpdate
		case renewal
	}

	struct Job: Identifiable {
		let id = UUID().uuidString
		let appUUID: String
		let reason: Reason
		let appIdentifier: String?
		let appName: String?
	}

	@Published private(set) var queue: [Job] = []
	@Published private(set) var currentJob: Job?
	@Published private(set) var completedCount = 0
	@Published private(set) var lastErrorMessage: String?

	private var _isRunning = false

	private init() {}

	// MARK: - Settings

	var isAutoSignEnabled: Bool {
		get { UserDefaults.standard.object(forKey: "SignOs.autoSignEnabled") as? Bool ?? true }
		set { UserDefaults.standard.set(newValue, forKey: "SignOs.autoSignEnabled") }
	}

	private var _autoDeleteOldVersions: Bool {
		UserDefaults.standard.object(forKey: "SignOs.autoDeleteOldVersions") as? Bool ?? true
	}

	// MARK: - Enqueueing

	/// Queues an app for background signing.
	func enqueue(app: AppInfoPresentable, reason: Reason = .autoSign) {
		guard isAutoSignEnabled else { return }
		guard let uuid = app.uuid else { return }

		let job = Job(
			appUUID: uuid,
			reason: reason,
			appIdentifier: app.identifier,
			appName: app.name
		)
		enqueue(job: job)
	}

	/// Resolves an imported app by uuid and queues it. Safe to call for
	/// every import: duplicates and already signed apps are filtered.
	func enqueueImported(uuid: String) {
		guard isAutoSignEnabled else { return }

		let request: NSFetchRequest<Imported> = Imported.fetchRequest()
		request.predicate = NSPredicate(format: "uuid == %@", uuid)
		guard let app = (try? Storage.shared.context.fetch(request))?.first else { return }

		enqueue(app: app, reason: .autoSign)
	}

	private func enqueue(job: Job) {
		guard currentJob?.appUUID != job.appUUID else { return }
		guard !queue.contains(where: { $0.appUUID == job.appUUID }) else { return }

		queue.append(job)

		if !_isRunning {
			Task { await _run() }
		}
	}

	// MARK: - Queue processing

	private func _run() async {
		_isRunning = true
		defer { _isRunning = false }

		while let job = queue.first {
			queue.removeFirst()
			currentJob = job
			await _process(job)
			currentJob = nil
			completedCount += 1
		}
	}

	private func _process(_ job: Job) async {
		guard let app = _resolveApp(uuid: job.appUUID) else { return }

		let options = OptionsManager.shared.options
		let certificate = _certificate(for: app, options: options)

		if certificate == nil && options.signingOption == .default {
			lastErrorMessage = "No valid certificate available for automatic signing."
			AutoUpdateManager.shared.notify(
				title: "Signing Failed",
				body: "\(job.appName ?? "App") could not be signed automatically. Import a certificate in Settings.",
				identifier: "signos.sign.failed.\(job.appUUID)"
			)
			return
		}

		await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
			FR.signPackageFile(app, using: options, icon: nil, certificate: certificate) { _ in
				continuation.resume()
			}
		}

		guard let identifier = job.appIdentifier ?? app.identifier else { return }

		let signedApps = _signedApps().filter { $0.identifier == identifier }
		guard let newest = signedApps.max(by: { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }) else {
			lastErrorMessage = "Signing did not produce a new app entry."
			return
		}

		if _autoDeleteOldVersions {
			for old in signedApps where old.uuid != newest.uuid {
				Storage.shared.deleteApp(for: old)
			}
			if !app.isSigned {
				Storage.shared.deleteApp(for: app)
			}
		}

		await _attemptSilentInstall(newest)

		let verb: String
		switch job.reason {
		case .autoSign: verb = "Signed"
		case .autoUpdate: verb = "Updated"
		case .renewal: verb = "Renewed"
		}

		AutoUpdateManager.shared.notify(
			title: "\(verb) \(newest.name ?? identifier)",
			body: "Ready to install. Open SignOs to install it.",
			identifier: "signos.sign.done.\(newest.uuid ?? job.appUUID)"
		)
	}

	// MARK: - Silent install

	private func _attemptSilentInstall(_ app: Signed) async {
		// Server-based installation always requires the user to confirm
		// the system dialog, so it cannot be silent. The direct device
		// (tunnel/pairing) method supports fully silent installs.
		let method = UserDefaults.standard.integer(forKey: "Feather.installationMethod")
		guard method == 1 else { return }

		do {
			let viewModel = InstallerStatusViewModel(isIdevice: true)
			let handler = ArchiveHandler(app: app, viewModel: viewModel)
			try await handler.move()
			let packageUrl = try await handler.archive()

			let proxy = InstallationProxy(viewModel: viewModel)
			try await proxy.install(at: packageUrl, suspend: false)
		} catch {
			lastErrorMessage = error.localizedDescription
		}
	}

	// MARK: - Certificate selection

	private func _certificate(for app: AppInfoPresentable, options: Options) -> CertificatePair? {
		// Updates and renewals keep the app's existing certificate while
		// it is still valid, preserving the signing identity.
		if let existing = Storage.shared.getCertificate(from: app), !existing.revoked {
			if let expiration = existing.expiration {
				if expiration.timeIntervalSinceNow > 0 {
					return existing
				}
			} else {
				return existing
			}
		}

		let certs = Storage.shared.getAllCertificates().filter { cert in
			if cert.revoked { return false }
			if let expiration = cert.expiration {
				return expiration.timeIntervalSinceNow > 0
			}
			return true
		}

		if let defaultCert = certs.first(where: { $0.isDefault }) {
			return defaultCert
		}

		let selectedIndex = UserDefaults.standard.integer(forKey: "feather.selectedCert")
		if
			selectedIndex >= 0,
			let selected = Storage.shared.getCertificate(for: selectedIndex),
			certs.contains(selected)
		{
			return selected
		}

		return certs.first
	}

	// MARK: - Fetch helpers

	private func _resolveApp(uuid: String) -> (any AppInfoPresentable)? {
		let signedRequest: NSFetchRequest<Signed> = Signed.fetchRequest()
		signedRequest.predicate = NSPredicate(format: "uuid == %@", uuid)
		if let signed = (try? Storage.shared.context.fetch(signedRequest))?.first {
			return signed
		}

		let importedRequest: NSFetchRequest<Imported> = Imported.fetchRequest()
		importedRequest.predicate = NSPredicate(format: "uuid == %@", uuid)
		if let imported = (try? Storage.shared.context.fetch(importedRequest))?.first {
			return imported
		}

		return nil
	}

	private func _signedApps() -> [Signed] {
		let request: NSFetchRequest<Signed> = Signed.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(keyPath: \Signed.date, ascending: false)]
		return (try? Storage.shared.context.fetch(request)) ?? []
	}
}
