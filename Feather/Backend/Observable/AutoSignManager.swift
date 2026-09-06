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
import UIKit
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
		var certificate: CertificatePair? = nil
		var options: Options? = nil
	}

	@Published private(set) var queue: [Job] = []
	@Published private(set) var currentJob: Job?
	@Published private(set) var completedCount = 0
	@Published private(set) var lastErrorMessage: String?

	private var _isRunning = false

	/// Keeps local install servers alive until the system fetches the payload.
	private static var _liveInstallers: [ServerInstaller] = []

	private init() {
		NotificationCenter.default.addObserver(
			forName: Notification.Name("SignOs.autoInstallRequested"),
			object: nil,
			queue: .main
		) { [weak self] note in
			guard let uuid = note.userInfo?["uuid"] as? String else { return }
			Task { @MainActor in
				await self?._handleInstallRequest(uuid: uuid)
			}
		}
	}

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
	func enqueue(
		app: AppInfoPresentable,
		reason: Reason = .autoSign,
		certificate: CertificatePair? = nil,
		options: Options? = nil,
		force: Bool = false
	) {
		guard force || isAutoSignEnabled else { return }
		guard let uuid = app.uuid else { return }

		let job = Job(
			appUUID: uuid,
			reason: reason,
			appIdentifier: app.identifier,
			appName: app.name,
			certificate: certificate,
			options: options
		)
		enqueue(job: job)
	}

	/// Clones an app: same app, new identity, parallel install.
	func cloneApp(app: AppInfoPresentable) {
		var options = OptionsManager.shared.options
		let base = app.identifier ?? UUID().uuidString
		options.appIdentifier = "\(base).clone\(Int.random(in: 100...999))"
		options.appName = "\(app.name ?? "App") \(Int.random(in: 2...9))"
		options.signingOption = .default

		let certificate = Storage.shared.getCertificate(from: app)
			?? _certificate(for: app, options: options)

		enqueue(app: app, reason: .autoSign, certificate: certificate, options: options, force: true)
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

		let options = job.options ?? OptionsManager.shared.options
		let certificate = job.certificate ?? _certificate(for: app, options: options)

		if certificate == nil && options.signingOption == .default {
			lastErrorMessage = "No valid certificate available for automatic signing."
			AutoUpdateManager.shared.notify(
				title: "Signing Failed",
				body: "\(job.appName ?? "App") could not be signed automatically. Import a certificate in Settings.",
				identifier: "signos.sign.failed.\(job.appUUID)"
			)
			return
		}

		var signingError: Error?
		await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
			FR.signPackageFile(app, using: options, icon: nil, certificate: certificate) { error in
				signingError = error
				continuation.resume()
			}
		}

		if let signingError {
			lastErrorMessage = signingError.localizedDescription
			ActivityLog.shared.log(.failed, app: job.appName ?? "App", detail: signingError.localizedDescription)
			AutoUpdateManager.shared.notify(
				title: "Couldn't Install \(job.appName ?? "App")",
				body: "Open SignOs and try again.",
				identifier: "signos.failed.\(job.appUUID)"
			)
			AutoUpdateManager.shared.updateBadgeFromState()
			return
		}

		guard let identifier = job.appIdentifier ?? app.identifier else { return }

		var signedApps = _signedApps().filter { $0.identifier == identifier }
		if let newestEntry = signedApps.max(by: { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }) {
			// PPQ-protected apps change identifiers on every sign; catch
			// those old versions by display name so they never pile up.
			let sameName = _signedApps().filter {
				$0.uuid != newestEntry.uuid && $0.name != nil && $0.name == newestEntry.name
			}
			for extra in sameName where !signedApps.contains(where: { $0.uuid == extra.uuid }) {
				signedApps.append(extra)
			}
		}
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

		switch job.reason {
		case .renewal:
			ActivityLog.shared.log(.renewed, app: newest.name ?? identifier)
		default:
			ActivityLog.shared.log(.updated, app: newest.name ?? identifier, detail: newest.version)
		}

		await _attemptSilentInstall(newest)
		AutoUpdateManager.shared.updateBadgeFromState()
	}

	// MARK: - Install

	/// App Store-style finishing move: after signing, the install happens
	/// with the least friction the active method allows. Paired-device
	/// installs are fully silent; local-server installs either fire the
	/// system prompt immediately (app in foreground) or present a
	/// "tap to install" notification that completes on open.
	private func _attemptSilentInstall(_ app: Signed) async {
		let method = UserDefaults.standard.integer(forKey: "Feather.installationMethod")
		guard method == 0 || method == 1 else { return }

		ArchiveHandler.fastestCompressionOverride = true
		defer { ArchiveHandler.fastestCompressionOverride = false }

		do {
			if method == 1 {
				let viewModel = InstallerStatusViewModel(isIdevice: true)
				let handler = ArchiveHandler(app: app, viewModel: viewModel)
				try await handler.move()
				let packageUrl = try await handler.archive()

				let proxy = InstallationProxy(viewModel: viewModel)
				try await proxy.install(at: packageUrl, suspend: false)

				ActivityLog.shared.log(.installed, app: app.name ?? "App")

				AutoUpdateManager.shared.notify(
					title: "Installed \(app.name ?? "App")",
					body: "The app is ready on your home screen.",
					identifier: "signos.installed.\(app.uuid ?? UUID().uuidString)"
				)
			} else {
				try await _serverInstall(app)
			}
		} catch {
			lastErrorMessage = error.localizedDescription
			ActivityLog.shared.log(.failed, app: app.name ?? "App", detail: error.localizedDescription)
			AutoUpdateManager.shared.notify(
				title: "Couldn't Install \(app.name ?? "App")",
				body: "Open SignOs to try again.",
				identifier: "signos.failed.\(app.uuid ?? UUID().uuidString)"
			)
		}
	}

	private func _serverInstall(_ app: Signed) async throws {
		let viewModel = InstallerStatusViewModel(isIdevice: false)
		let handler = ArchiveHandler(app: app, viewModel: viewModel)
		try await handler.move()
		let packageUrl = try await handler.archive()

		let installer = try ServerInstaller(app: app, viewModel: viewModel)
		installer.packageUrl = packageUrl
		Self._retainInstaller(installer)

		if UIApplication.shared.applicationState == .active {
			if let url = URL(string: installer.iTunesLink) {
				await UIApplication.shared.open(url)
				ActivityLog.shared.log(.installed, app: app.name ?? "App", detail: "install prompt shown")
			}
		} else if let uuid = app.uuid {
			AutoUpdateManager.shared.notify(
				title: "\(app.name ?? "App") is ready",
				body: "Tap to install it now.",
				identifier: "signos.install.\(uuid)",
				category: "SIGNOS_INSTALL"
			)
		}
	}

	private static func _retainInstaller(_ installer: ServerInstaller) {
		_liveInstallers.append(installer)
		Task { @MainActor in
			try? await Task.sleep(nanoseconds: 600_000_000_000)
			_liveInstallers.removeAll { $0 === installer }
		}
	}

	/// Fires the pending install when the user opens SignOs from the
	/// "tap to install" notification.
	private func _handleInstallRequest(uuid: String) async {
		let request: NSFetchRequest<Signed> = Signed.fetchRequest()
		request.predicate = NSPredicate(format: "uuid == %@", uuid)
		guard let app = (try? Storage.shared.context.fetch(request))?.first else { return }

		do {
			try await _serverInstall(app)
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
