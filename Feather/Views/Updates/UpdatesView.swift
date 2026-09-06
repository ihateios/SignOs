//
//  UpdatesView.swift
//  Feather
//
//  App Store-style updates surface, built from scratch: available
//  updates, the background install queue, active downloads and
//  recently updated apps.
//

import SwiftUI
import CoreData
import NimbleViews

// MARK: - View
struct UpdatesView: View {
	@StateObject private var autoUpdateManager = AutoUpdateManager.shared
	@ObservedObject private var updateManager = UpdateManager.shared
	@ObservedObject private var downloadManager = DownloadManager.shared
	@ObservedObject private var autoSignManager = AutoSignManager.shared
	@State private var _heldTick = 0

	@FetchRequest(
		entity: Signed.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Signed.date, ascending: false)],
		animation: .snappy
	) private var _signedApps: FetchedResults<Signed>

	@FetchRequest(
		entity: Imported.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Imported.date, ascending: false)],
		animation: .snappy
	) private var _importedApps: FetchedResults<Imported>

	private var _recentlyUpdated: [Signed] {
		let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
		return _signedApps.filter { ($0.date ?? .distantPast) >= cutoff }.prefix(10).map { $0 }
	}

	private var _sortedUpdates: [AppUpdate] {
		updateManager.updates.values.sorted {
			$0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending
		}
	}

	private var _isChecking: Bool {
		autoUpdateManager.isAutoChecking || updateManager.isChecking
	}

	// MARK: Body
	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 30) {
					WSHeroHeader(eyebrow: "SignOs", title: "Updates")

					_automationSection()

					if !_sortedUpdates.isEmpty {
						_availableUpdatesSection()
					}

					_heldSection()

					if autoSignManager.currentJob != nil || !autoSignManager.queue.isEmpty || !downloadManager.downloads.isEmpty {
						_activitySection()
					}

					if !_recentlyUpdated.isEmpty {
						_recentlyUpdatedSection()
					}

					if
						_sortedUpdates.isEmpty,
						downloadManager.downloads.isEmpty,
						autoSignManager.currentJob == nil,
						!_isChecking
					{
						_emptyCard()
					}
				}
				.padding(.horizontal, 16)
				.padding(.top, 4)
				.padding(.bottom, 28)
			}
			.background(Color(uiColor: .systemGroupedBackground))
			.toolbar(.hidden, for: .navigationBar)
			.refreshable {
				await autoUpdateManager.checkNow(notifyWhenClean: false)
			}
		}
	}
}

// MARK: - Sections
extension UpdatesView {
	@ViewBuilder
	private func _automationSection() -> some View {
		VStack(spacing: 10) {
			WSCard {
				Toggle(isOn: Binding(
					get: { autoUpdateManager.isAutoUpdateEnabled },
					set: { autoUpdateManager.isAutoUpdateEnabled = $0 }
				)) {
					VStack(alignment: .leading, spacing: 3) {
						Text("Automatic Updates")
							.font(.body.weight(.semibold))
							.foregroundStyle(.primary)
						Text("Updates install themselves in the background")
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
				.tint(.accentColor)
			}

			WSCard {
				Toggle(isOn: Binding(
					get: { autoUpdateManager.isAutoRenewEnabled },
					set: { autoUpdateManager.isAutoRenewEnabled = $0 }
				)) {
					VStack(alignment: .leading, spacing: 3) {
						Text("Keep Apps Signed")
							.font(.body.weight(.semibold))
							.foregroundStyle(.primary)
						Text("Renews your apps automatically in the background")
							.font(.caption)
							.foregroundStyle(.secondary)
					}
				}
				.tint(.accentColor)
			}

			HStack(spacing: 10) {
				if _isChecking {
					ProgressView()
				}

				Text(_checkStatusText)
					.font(.footnote)
					.foregroundStyle(.secondary)

				Spacer()

				WSActionButton(title: "Check", systemImage: "arrow.triangle.2.circlepath") {
					Task { await autoUpdateManager.checkNow(notifyWhenClean: false) }
				}
			}
			.padding(.horizontal, 6)
		}
	}

	private var _checkStatusText: String {
		if _isChecking {
			return .localized("Checking for Updates")
		}
		if let last = autoUpdateManager.lastCheckDate {
			return .localized("Last checked %@.", arguments: last.formatted(.relative(presentation: .named)))
		}
		return .localized("Never checked.")
	}

	@ViewBuilder
	private func _availableUpdatesSection() -> some View {
		VStack(alignment: .leading, spacing: 12) {
			WSSectionTitle(
				title: "Available Updates",
				actionTitle: "Update All"
			) {
				_downloadAll(_sortedUpdates)
			}

			VStack(spacing: 10) {
				ForEach(_sortedUpdates, id: \.id) { update in
					_updateCard(update)
				}
			}
		}
	}

	private func _updateCard(_ update: AppUpdate) -> some View {
		HStack(spacing: 14) {
			FRAppIconView(app: _resolvePresentable(update), size: 57)
				.overlay(alignment: .topTrailing) {
					Circle()
						.fill(Color.accentColor)
						.frame(width: 10, height: 10)
						.offset(x: 4, y: -4)
				}

			VStack(alignment: .leading, spacing: 3) {
				Text(update.appName)
					.font(.body.weight(.semibold))
					.foregroundStyle(.primary)
					.lineLimit(1)
				Text(verbatim: _versionText(update))
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(2)
			}

			Spacer()

			WSActionButton(title: "Update") {
				_download(update)
			}
		}
		.padding(14)
		.background(
			RoundedRectangle(cornerRadius: 20, style: .continuous)
				.fill(Color(uiColor: .secondarySystemGroupedBackground))
		)
		.contextMenu {
			Button {
				_download(update)
			} label: {
				Label(.localized("Update"), systemImage: "arrow.down.circle")
			}

			Divider()

			Menu {
				Button {
					autoUpdateManager.setAutoUpdate(true, for: update.bundleIdentifier)
				} label: {
					Label(.localized("Automatic"), systemImage: "checkmark.circle.fill")
				}
				Button {
					autoUpdateManager.setAutoUpdate(false, for: update.bundleIdentifier)
				} label: {
					Label(.localized("Manual"), systemImage: "hand.tap")
				}
			} label: {
				Label(.localized("Auto-Update"), systemImage: "automatic")
			}

			Divider()

			Button {
				updateManager.skip(version: update.remoteVersion, for: update.bundleIdentifier)
				updateManager.dismissUpdate(withLocalUUID: update.id)
			} label: {
				Label(.localized("Skip This Version"), systemImage: "eye.slash")
			}

			Button {
				updateManager.setHeld(true, for: update.bundleIdentifier)
				updateManager.dismissUpdate(withLocalUUID: update.id)
			} label: {
				Label(.localized("Hold Updates for This App"), systemImage: "pause.circle")
			}
		}
	}

	@ViewBuilder
	private func _heldSection() -> some View {
		let rows = _heldApps()
		if !rows.isEmpty {
			VStack(alignment: .leading, spacing: 12) {
				WSSectionTitle(title: "Held & Skipped")

				VStack(spacing: 10) {
					ForEach(rows, id: \.identifier) { row in
						HStack(spacing: 14) {
							Image(systemName: row.held ? "pause.circle.fill" : "eye.slash.fill")
								.font(.title3)
								.foregroundStyle(.secondary)
								.frame(width: 30)

							VStack(alignment: .leading, spacing: 3) {
								Text(row.name)
									.font(.body.weight(.semibold))
									.foregroundStyle(.primary)
									.lineLimit(1)
								Text(verbatim: row.held
									? "Updates held"
									: "Skipped version \(row.skipped ?? "")")
									.font(.caption)
									.foregroundStyle(.secondary)
							}

							Spacer()

							WSActionButton(title: row.held ? "Resume" : "Unskip", style: .quiet) {
								if row.held {
									updateManager.setHeld(false, for: row.identifier)
								} else {
									updateManager.clearSkip(for: row.identifier)
								}
								_heldTick += 1
							}
						}
						.padding(14)
						.background(
							RoundedRectangle(cornerRadius: 20, style: .continuous)
								.fill(Color(uiColor: .secondarySystemGroupedBackground))
						)
					}
				}
			}
		}
	}

	@ViewBuilder
	private func _activitySection() -> some View {
		VStack(alignment: .leading, spacing: 12) {
			WSSectionTitle(title: "Activity")

			VStack(spacing: 10) {
				if let job = autoSignManager.currentJob {
					_queueCard(job, isActive: true)
				}
				ForEach(autoSignManager.queue) { job in
					_queueCard(job, isActive: false)
				}

				ForEach(downloadManager.downloads, id: \.id) { download in
					WSDownloadCard(download: download)
				}
			}
		}
	}

	private func _queueCard(_ job: AutoSignManager.Job, isActive: Bool) -> some View {
		HStack(spacing: 14) {
			Image(systemName: isActive ? "square.and.arrow.down.fill" : "hourglass")
				.font(.title3)
				.foregroundStyle(isActive ? Color.accentColor : Color.secondary)
				.frame(width: 30)

			VStack(alignment: .leading, spacing: 3) {
				Text(job.appName ?? "Unknown")
					.font(.body.weight(.semibold))
					.foregroundStyle(.primary)
					.lineLimit(1)
				Text(_reasonLabel(job.reason))
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			Spacer()

			if isActive {
				ProgressView()
			}
		}
		.padding(14)
		.background(
			RoundedRectangle(cornerRadius: 20, style: .continuous)
				.fill(Color(uiColor: .secondarySystemGroupedBackground))
		)
	}

	@ViewBuilder
	private func _recentlyUpdatedSection() -> some View {
		VStack(alignment: .leading, spacing: 12) {
			WSSectionTitle(title: "Recently Updated")

			VStack(spacing: 10) {
				ForEach(_recentlyUpdated, id: \.uuid) { app in
					HStack(spacing: 14) {
						FRAppIconView(app: app, size: 57)

						VStack(alignment: .leading, spacing: 3) {
							Text(app.name ?? "Unknown")
								.font(.body.weight(.semibold))
								.foregroundStyle(.primary)
								.lineLimit(1)
							Text(verbatim: [
								app.version,
								(app.date ?? .distantPast).formatted(.relative(presentation: .named))
							].compactMap { $0 }.joined(separator: " • "))
								.font(.caption)
								.foregroundStyle(.secondary)
								.lineLimit(2)
						}

						Spacer()

						WSActionButton(title: "Open") {
							UIApplication.openApp(with: app.identifier ?? "")
						}
					}
					.padding(14)
					.background(
						RoundedRectangle(cornerRadius: 20, style: .continuous)
							.fill(Color(uiColor: .secondarySystemGroupedBackground))
					)
				}
			}
		}
	}

	private func _emptyCard() -> some View {
		VStack(spacing: 10) {
			if #available(iOS 17, *) {
				ContentUnavailableView {
					Label("All Apps Up to Date", systemImage: "checkmark.seal.fill")
				} description: {
					Text("Apps from your repositories will appear here when updates are available.")
				}
			} else {
				Image(systemName: "checkmark.seal.fill")
					.font(.system(size: 44))
					.foregroundStyle(.tint)
				Text("All Apps Up to Date")
					.font(.headline)
			}
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 32)
		.padding(.horizontal, 16)
		.background(
			RoundedRectangle(cornerRadius: 24, style: .continuous)
				.fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.6))
		)
	}
}

// MARK: - Rows
struct WSDownloadCard: View {
	let download: Download

	@State private var _speedometer = WSSpeedometer()
	@State private var _speedText = ""
	@State private var _etaText = ""

	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			HStack(spacing: 10) {
				Image(systemName: "arrow.down.circle.fill")
					.font(.title3)
					.foregroundStyle(.tint)
					.symbolRenderingMode(.hierarchical)

				Text(download.fileName)
					.font(.footnote.weight(.semibold))
					.lineLimit(1)

				Spacer()

				Text(verbatim: "\(Int(download.overallProgress * 100))%")
					.font(.caption.weight(.semibold).monospacedDigit())
					.foregroundStyle(.secondary)
					.contentTransition(.numericText())

				Button {
					if let dl = DownloadManager.shared.getDownload(by: download.id) {
						DownloadManager.shared.cancelDownload(dl)
					}
				} label: {
					Image(systemName: "xmark.circle.fill")
						.foregroundStyle(.tertiary)
				}
				.buttonStyle(.plain)
			}

			ProgressView(value: download.overallProgress)
				.progressViewStyle(.linear)

			HStack(spacing: 6) {
				if download.totalBytes > 0 {
					Text(verbatim: download.totalBytes.formattedByteCount)
				}
				if !_speedText.isEmpty {
					Text(verbatim: "• \(_speedText)")
				}
				if !_etaText.isEmpty {
					Text(verbatim: "• \(_etaText)")
				}
			}
			.font(.caption2)
			.foregroundStyle(.tertiary)
		}
		.padding(14)
		.background(
			RoundedRectangle(cornerRadius: 20, style: .continuous)
				.fill(Color(uiColor: .secondarySystemGroupedBackground))
		)
		.onReceive(download.$bytesDownloaded) { bytes in
			let speed = _speedometer.sample(bytes)
			_speedText = speed.formattedSpeed
			if speed > 0, download.totalBytes > bytes {
				_etaText = (Double(download.totalBytes - bytes) / speed).formattedEta
			} else {
				_etaText = ""
			}
		}
	}
}

// MARK: - Helpers
extension UpdatesView {
	private func _reasonLabel(_ reason: AutoSignManager.Reason) -> String {
		switch reason {
		case .autoSign: return .localized("Installing")
		case .autoUpdate: return .localized("Installing Update")
		case .renewal: return .localized("Refreshing")
		}
	}

	private func _versionText(_ update: AppUpdate) -> String {
		if let local = update.localVersion, !local.isEmpty {
			return "\(local) → \(update.remoteVersion)"
		}
		return update.remoteVersion
	}

	private func _resolvePresentable(_ update: AppUpdate) -> (any AppInfoPresentable)? {
		_signedApps.first { $0.uuid == update.localUUID }
	}

	private func _heldApps() -> [(identifier: String, name: String, held: Bool, skipped: String?)] {
		var seen = Set<String>()
		var rows: [(identifier: String, name: String, held: Bool, skipped: String?)] = []
		for app in _signedApps.map({ $0 as (any AppInfoPresentable) }) + _importedApps.map({ $0 as (any AppInfoPresentable) }) {
			guard let identifier = app.identifier, !seen.contains(identifier) else { continue }
			let held = updateManager.isHeld(for: identifier)
			let skipped = updateManager.skippedVersion(for: identifier)
			if held || skipped != nil {
				seen.insert(identifier)
				rows.append((identifier, app.name ?? identifier, held, skipped))
			}
		}
		return rows
	}

	private func _download(_ update: AppUpdate) {
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
		_ = DownloadManager.shared.startDownload(
			from: update.downloadURL,
			id: "SignOsManualUpdate_\(update.localUUID)",
			sourceProvenance: update.sourceProvenance
		)
	}

	private func _downloadAll(_ updates: [AppUpdate]) {
		UIImpactFeedbackGenerator(style: .medium).impactOccurred()
		for update in updates {
			_ = DownloadManager.shared.startDownload(
				from: update.downloadURL,
				id: "SignOsManualUpdate_\(update.localUUID)",
				sourceProvenance: update.sourceProvenance
			)
		}
	}
}
