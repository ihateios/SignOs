//
//  AutoUpdateManager.swift
//  Feather
//
//  App Store-style automatic updates: periodically compares installed
//  apps against their repositories, silently downloads, signs and
//  (where the installation method allows) installs updates.
//

import Foundation
import CoreData
import Network
import UIKit
import UserNotifications
import BackgroundTasks
import AltSourceKit

enum SignOsAuto {
	/// Prefix marking downloads that were started by the automatic updater.
	static let downloadPrefix = "SignOsAutoDownload"
}

@MainActor
final class AutoUpdateManager: ObservableObject {
	static let shared = AutoUpdateManager()

	static let autoDownloadPrefix = SignOsAuto.downloadPrefix

	private enum Keys {
		static let autoUpdateEnabled = "SignOs.autoUpdateEnabled"
		static let autoRenewEnabled = "SignOs.autoRenewEnabled"
		static let notificationsEnabled = "SignOs.notificationsEnabled"
		static let perAppAutoUpdate = "SignOs.perAppAutoUpdate"
		static let lastCheck = "SignOs.lastUpdateCheck"
		static let intervalHours = "SignOs.autoUpdateInterval"
		static let renewThresholdDays = "SignOs.renewThresholdDays"
		static let renewedUUIDs = "SignOs.renewedUUIDs"
	}

	@Published private(set) var isAutoChecking = false

	private var _timer: Timer?
	private let _pathMonitor = NWPathMonitor()
	private var _networkPath: NWPath?

	// MARK: - Settings (UserDefaults backed so views can bind with @AppStorage)

	var isWifiOnly: Bool {
		get { UserDefaults.standard.object(forKey: "SignOs.autoUpdateWifiOnly") as? Bool ?? false }
		set { UserDefaults.standard.set(newValue, forKey: "SignOs.autoUpdateWifiOnly") }
	}

	var isNightWindowOnly: Bool {
		get { UserDefaults.standard.object(forKey: "SignOs.autoUpdateNightOnly") as? Bool ?? false }
		set { UserDefaults.standard.set(newValue, forKey: "SignOs.autoUpdateNightOnly") }
	}

	var isAutoUpdateEnabled: Bool {
		get { UserDefaults.standard.object(forKey: Keys.autoUpdateEnabled) as? Bool ?? true }
		set {
			UserDefaults.standard.set(newValue, forKey: Keys.autoUpdateEnabled)
			if newValue { tick() }
		}
	}

	var isAutoRenewEnabled: Bool {
		get { UserDefaults.standard.object(forKey: Keys.autoRenewEnabled) as? Bool ?? true }
		set { UserDefaults.standard.set(newValue, forKey: Keys.autoRenewEnabled) }
	}

	var notificationsEnabled: Bool {
		get { UserDefaults.standard.object(forKey: Keys.notificationsEnabled) as? Bool ?? true }
		set {
			UserDefaults.standard.set(newValue, forKey: Keys.notificationsEnabled)
			if newValue { requestNotificationAuthorization() }
		}
	}

	var intervalHours: Double {
		get { UserDefaults.standard.object(forKey: Keys.intervalHours) as? Double ?? 6.0 }
		set { UserDefaults.standard.set(newValue, forKey: Keys.intervalHours) }
	}

	var renewThresholdDays: Int {
		get { UserDefaults.standard.object(forKey: Keys.renewThresholdDays) as? Int ?? 3 }
		set { UserDefaults.standard.set(newValue, forKey: Keys.renewThresholdDays) }
	}

	var lastCheckDate: Date? {
		get { UserDefaults.standard.object(forKey: Keys.lastCheck) as? Date }
		set { UserDefaults.standard.set(newValue, forKey: Keys.lastCheck) }
	}

	// MARK: - Init

	private init() {}

	/// Boots the periodic checker. Called once on app launch.
	func start() {
		_pathMonitor.pathUpdateHandler = { [weak self] path in
			Task { @MainActor [weak self] in
				self?._networkPath = path
			}
		}
		_pathMonitor.start(queue: DispatchQueue.global(qos: .utility))

		_timer?.invalidate()
		_timer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { [weak self] _ in
			Task { @MainActor [weak self] in
				self?.tick()
			}
		}
		tick()
	}

	/// Runs a check if the configured interval has elapsed and the
	/// network/time constraints allow it.
	func tick() {
		if let last = lastCheckDate, Date().timeIntervalSince(last) < intervalHours * 3600 {
			checkRenewals()
			return
		}

		guard _networkAllowed(), _withinWindow() else {
			checkRenewals()
			return
		}

		Task { await checkNow(notifyWhenClean: false) }
	}

	private func _networkAllowed() -> Bool {
		guard isWifiOnly else { return true }
		guard let path = _networkPath, path.status == .satisfied else { return true }
		return !path.isExpensive
	}

	private func _withinWindow() -> Bool {
		guard isNightWindowOnly else { return true }
		let hour = Calendar.current.component(.hour, from: Date())
		return hour >= 22 || hour < 6
	}

	// MARK: - Checking

	@discardableResult
	func checkNow(notifyWhenClean: Bool = true) async -> Int {
		guard !isAutoChecking else { return UpdateManager.shared.updates.count }
		isAutoChecking = true
		defer {
			isAutoChecking = false
			lastCheckDate = Date()
		}

		await UpdateManager.shared.checkForUpdates(
			sources: _fetchSources(),
			localApps: _fetchSignedApps().map { $0 as AppInfoPresentable }
				+ _fetchImportedApps().map { $0 as AppInfoPresentable }
		)

		checkRenewals()

		let updates = UpdateManager.shared.updates.values
			.sorted { $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending }

		ActivityLog.shared.log(.checked, app: "SignOs", detail: updates.isEmpty ? "all apps up to date" : "\(updates.count) found")

		if updates.isEmpty {
			_updateBadge(0)
			if notifyWhenClean {
				notify(
					title: "All Apps Up to Date",
					body: "Every app matches the latest version in its repository.",
					identifier: "signos.updates.clean"
				)
			}
			return 0
		}

		_updateBadge(updates.count)

		if !isAutoUpdateEnabled {
			notify(
				title: "Updates Available",
				body: updates.count == 1
					? "\(updates[0].appName) has a new version available."
					: "\(updates.count) apps have new versions available.",
				identifier: "signos.updates.available"
			)
			return updates.count
		}

		let disabledSourceURLs = _disabledSourceURLs()

		var started = 0
		for update in updates {
			guard isAutoUpdateEnabled(for: update.bundleIdentifier) else { continue }
			guard !_matchesDisabledSource(update.sourceURL, disabled: disabledSourceURLs) else { continue }
			let jobId = "\(Self.autoDownloadPrefix)_\(update.localUUID)"
			guard DownloadManager.shared.getDownload(by: jobId) == nil else { continue }

			_ = DownloadManager.shared.startDownload(
				from: update.downloadURL,
				id: jobId,
				sourceProvenance: update.sourceProvenance
			)
			ActivityLog.shared.log(.downloaded, app: update.appName)
			started += 1
		}

		if started > 0 {
			notify(
				title: "Updating Apps",
				body: started == 1
					? "Downloading \(updates.count == 1 ? updates[0].appName : "1 app") in the background."
					: "Downloading \(started) app updates in the background.",
				identifier: "signos.updates.downloading"
			)
		}

		return updates.count
	}

	private func _updateBadge(_ count: Int) {
		let enabled = UserDefaults.standard.object(forKey: "SignOs.badgeUpdates") as? Bool ?? false
		UIApplication.shared.applicationIconBadgeNumber = enabled ? min(max(count, 0), 99) : 0
	}

	// MARK: - Per-source rules

	func isSourceAutoUpdateEnabled(_ source: AltSource) -> Bool {
		let overrides = UserDefaults.standard.dictionary(forKey: "SignOs.sourceAutoUpdate") as? [String: Bool] ?? [:]
		return overrides[source.identifier ?? ""] ?? true
	}

	func setSourceAutoUpdate(_ enabled: Bool, for source: AltSource) {
		var overrides = UserDefaults.standard.dictionary(forKey: "SignOs.sourceAutoUpdate") as? [String: Bool] ?? [:]
		overrides[source.identifier ?? ""] = enabled
		UserDefaults.standard.set(overrides, forKey: "SignOs.sourceAutoUpdate")
	}

	private func _disabledSourceURLs() -> Set<String> {
		let overrides = UserDefaults.standard.dictionary(forKey: "SignOs.sourceAutoUpdate") as? [String: Bool] ?? [:]
		return Set(
			_fetchSources()
				.filter { overrides[$0.identifier ?? ""] == false }
				.compactMap { $0.sourceURL?.absoluteString }
		)
	}

	private func _matchesDisabledSource(_ url: URL, disabled: Set<String>) -> Bool {
		var string = url.absoluteString
		if string.hasSuffix("/") {
			string = String(string.dropLast())
		}
		return disabled.contains(string)
	}

	// MARK: - Shortcuts

	/// Downloads every pending update through the automatic pipeline.
	func downloadAllPendingUpdates() async -> Int {
		await checkNow(notifyWhenClean: false)

		var started = 0
		for update in UpdateManager.shared.updates.values {
			let jobId = "\(Self.autoDownloadPrefix)_\(update.localUUID)"
			guard DownloadManager.shared.getDownload(by: jobId) == nil else { continue }

			_ = DownloadManager.shared.startDownload(
				from: update.downloadURL,
				id: jobId,
				sourceProvenance: update.sourceProvenance
			)
			started += 1
		}
		return started
	}

	// MARK: - Per-app auto-update

	func isAutoUpdateEnabled(for identifier: String) -> Bool {
		guard isAutoUpdateEnabled else { return false }
		let overrides = UserDefaults.standard.dictionary(forKey: Keys.perAppAutoUpdate) as? [String: Bool]
		return overrides?[identifier] ?? true
	}

	func setAutoUpdate(_ enabled: Bool, for identifier: String) {
		var overrides = UserDefaults.standard.dictionary(forKey: Keys.perAppAutoUpdate) as? [String: Bool] ?? [:]
		overrides[identifier] = enabled
		UserDefaults.standard.set(overrides, forKey: Keys.perAppAutoUpdate)
	}

	// MARK: - Certificate renewal

	/// Re-signs apps whose certificate is about to expire (or was revoked)
	/// using the healthiest available certificate, so installs survive
	/// past the 7/365-day signing windows.
	func checkRenewals() {
		guard isAutoRenewEnabled else { return }

		let threshold = Double(renewThresholdDays) * 86400
		var renewed = Set(UserDefaults.standard.stringArray(forKey: Keys.renewedUUIDs) ?? [])

		for app in _fetchSignedApps() {
			guard let uuid = app.uuid, !renewed.contains(uuid) else { continue }

			let needsRenewal: Bool
			if let cert = app.certificate {
				if cert.revoked {
					needsRenewal = true
				} else if let expiration = cert.expiration {
					needsRenewal = expiration.timeIntervalSinceNow <= threshold
				} else {
					needsRenewal = false
				}
			} else {
				needsRenewal = false
			}

			guard needsRenewal else { continue }

			// Only renew when a healthy replacement certificate exists.
			guard let replacement = _healthiestCertificate(excluding: app.certificate) else { continue }

			renewed.insert(uuid)
			UserDefaults.standard.set(Array(renewed), forKey: Keys.renewedUUIDs)

			AutoSignManager.shared.enqueue(app: app, reason: .renewal, certificate: replacement)
		}
	}

	private func _healthiestCertificate(excluding: CertificatePair?) -> CertificatePair? {
		let certs = Storage.shared.getAllCertificates().filter { cert in
			guard !cert.revoked, cert != excluding else { return false }
			if let expiration = cert.expiration {
				return expiration.timeIntervalSinceNow > 86400
			}
			return true
		}
		return certs.first { $0.isDefault } ?? certs.first
	}

	// MARK: - Notifications

	func requestNotificationAuthorization() {
		let install = UNNotificationAction(identifier: "SIGNOS_INSTALL_ACTION", title: "Install", options: [.foreground])
		let later = UNNotificationAction(identifier: "SIGNOS_LATER_ACTION", title: "Later", options: [])
		UNUserNotificationCenter.current().setNotificationCategories([
			UNNotificationCategory(identifier: "SIGNOS_INSTALL", actions: [install, later], intentIdentifiers: [])
		])

		UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
	}

	func notify(title: String, body: String, identifier: String = UUID().uuidString, category: String? = nil) {
		guard notificationsEnabled else { return }

		let content = UNMutableNotificationContent()
		content.title = title
		content.body = body
		content.sound = .default
		if let category {
			content.categoryIdentifier = category
		}

		let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
		UNUserNotificationCenter.current().add(request)
	}

	// MARK: - Background refresh

	#if !targetEnvironment(macCatalyst)
	func scheduleBackgroundRefresh() {
		let request = BGAppRefreshTaskRequest(identifier: "\(Bundle.main.bundleIdentifier!).refresh")
		request.earliestBeginDate = Date(timeIntervalSinceNow: 4 * 3600)
		try? BGTaskScheduler.shared.submit(request)
	}

	static func registerBackgroundRefresh() {
		BGTaskScheduler.shared.register(
			forTaskWithIdentifier: "\(Bundle.main.bundleIdentifier!).refresh",
			using: nil
		) { task in
			Task { @MainActor in
				await AutoUpdateManager.shared.checkNow(notifyWhenClean: false)
				AutoUpdateManager.shared.scheduleBackgroundRefresh()
				task.setTaskCompleted(success: true)
			}
		}
	}
	#endif

	// MARK: - Fetch helpers

	private func _fetchSources() -> [AltSource] {
		let request: NSFetchRequest<AltSource> = AltSource.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)]
		return (try? Storage.shared.context.fetch(request)) ?? []
	}

	private func _fetchSignedApps() -> [Signed] {
		let request: NSFetchRequest<Signed> = Signed.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(keyPath: \Signed.date, ascending: false)]
		return (try? Storage.shared.context.fetch(request)) ?? []
	}

	private func _fetchImportedApps() -> [Imported] {
		let request: NSFetchRequest<Imported> = Imported.fetchRequest()
		request.sortDescriptors = [NSSortDescriptor(keyPath: \Imported.date, ascending: false)]
		return (try? Storage.shared.context.fetch(request)) ?? []
	}
}
