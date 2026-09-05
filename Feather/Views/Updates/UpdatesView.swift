//
//  UpdatesView.swift
//  Feather
//
//  App Store-style updates surface: available updates from sources,
//  the background signing queue, active downloads and recently
//  updated apps, with automatic updates fully controllable.
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

	@FetchRequest(
		entity: Signed.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Signed.date, ascending: false)],
		animation: .snappy
	) private var _signedApps: FetchedResults<Signed>

	private var _recentlyUpdated: [Signed] {
		let cutoff = Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date()
		return _signedApps.filter { ($0.date ?? .distantPast) >= cutoff }.prefix(10).map { $0 }
	}

	private var _sortedUpdates: [AppUpdate] {
		updateManager.updates.values.sorted {
			$0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending
		}
	}

	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Updates")) {
			NBListAdaptable {
				_automationSection()
				_emptyStateSection()
				_availableUpdatesSection()
				_signingQueueSection()
				_activeDownloadsSection()
				_recentlyUpdatedSection()
			}
			.refreshable {
				await autoUpdateManager.checkNow(notifyWhenClean: false)
			}
		}
		.navigationTitle(.localized("Updates"))
	}

	// MARK: Sections

	@ViewBuilder
	private func _automationSection() -> some View {
		NBSection(.localized("Automatic Updates")) {
			Toggle(isOn: Binding(
				get: { autoUpdateManager.isAutoUpdateEnabled },
				set: { autoUpdateManager.isAutoUpdateEnabled = $0 }
			)) {
				NBTitleWithSubtitleView(
					title: .localized("Update Automatically"),
					subtitle: .localized("Download, sign and prepare updates in the background")
				)
			}
			.tint(.accentColor)

			Toggle(isOn: Binding(
				get: { autoUpdateManager.isAutoRenewEnabled },
				set: { autoUpdateManager.isAutoRenewEnabled = $0 }
			)) {
				NBTitleWithSubtitleView(
					title: .localized("Keep Apps Signed"),
					subtitle: .localized("Re-sign apps automatically before their certificate expires")
				)
			}
			.tint(.accentColor)

			HStack {
				if autoUpdateManager.isAutoChecking || updateManager.isChecking {
					ProgressView()
					Text(.localized("Checking for Updates"))
						.font(.subheadline)
						.foregroundStyle(.secondary)
				} else {
					if let last = autoUpdateManager.lastCheckDate {
						Text(verbatim: .localized("Last checked %@.", arguments: last.formatted(.relative(presentation: .named))))
							.font(.subheadline)
							.foregroundStyle(.secondary)
					} else {
						Text(.localized("Never checked."))
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}
				}
				Spacer()
				WSActionButton(title: .localized("Check"), systemImage: "arrow.triangle.2.circlepath") {
					Task { await autoUpdateManager.checkNow(notifyWhenClean: false) }
				}
			}
		} footer: {
			Text(.localized("Updates are signed with the app's existing certificate when it is still valid, so app data is preserved."))
		}
	}

	@ViewBuilder
	private func _emptyStateSection() -> some View {
		if
			_sortedUpdates.isEmpty,
			downloadManager.downloads.isEmpty,
			autoSignManager.currentJob == nil,
			_recentlyUpdated.isEmpty
		{
			Section {
				if #available(iOS 17, *) {
					ContentUnavailableView {
						Label(.localized("All Apps Up to Date"), systemImage: "checkmark.seal.fill")
					} description: {
						Text(.localized("Apps from your repositories will appear here when updates are available."))
					}
					.frame(maxWidth: .infinity)
					.padding(.vertical, 24)
				}
			}
			.listRowBackground(Color.clear)
		}
	}

	@ViewBuilder
	private func _availableUpdatesSection() -> some View {
		let updates = _sortedUpdates
		if !updates.isEmpty {
			NBSection(.localized("Available Updates"), secondary: updates.count.description) {
				ForEach(updates, id: \.id) { update in
					_updateRow(update)
				}

				WSActionButton(
					title: .localized("Update All"),
					systemImage: "arrow.down.circle.fill",
					style: .prominent
				) {
					_downloadAll(updates)
				}
				.frame(maxWidth: .infinity, alignment: .trailing)
				.padding(.vertical, 4)
				.listRowBackground(Color.clear)
			}
		}
	}

	@ViewBuilder
	private func _signingQueueSection() -> some View {
		if autoSignManager.currentJob != nil || !autoSignManager.queue.isEmpty {
			NBSection(.localized("Signing Queue")) {
				if let job = autoSignManager.currentJob {
					_queueRow(job, isActive: true)
				}
				ForEach(autoSignManager.queue) { job in
					_queueRow(job, isActive: false)
				}
			}
		}
	}

	@ViewBuilder
	private func _activeDownloadsSection() -> some View {
		if !downloadManager.downloads.isEmpty {
			NBSection(.localized("Downloading")) {
				ForEach(downloadManager.downloads, id: \.id) { download in
					HStack(spacing: 14) {
						Image(systemName: "arrow.down.circle.fill")
							.font(.title2)
							.foregroundStyle(.tint)

						VStack(alignment: .leading, spacing: 6) {
							Text(download.fileName)
								.font(.subheadline.weight(.medium))
								.lineLimit(1)
							ProgressView(value: download.overallProgress)
								.progressViewStyle(.linear)
							HStack {
								Text(verbatim: "\(Int(download.overallProgress * 100))%")
									.font(.caption2.monospacedDigit())
									.foregroundStyle(.secondary)
								Spacer()
								if download.totalBytes > 0 {
									Text(verbatim: download.totalBytes.formattedByteCount)
										.font(.caption2)
										.foregroundStyle(.tertiary)
								}
							}
						}
					}
					.padding(.vertical, 2)
				}
			}
		}
	}

	@ViewBuilder
	private func _recentlyUpdatedSection() -> some View {
		let apps = _recentlyUpdated
		if !apps.isEmpty {
			NBSection(.localized("Recently Updated")) {
				ForEach(apps, id: \.uuid) { app in
					HStack(spacing: 18) {
						FRAppIconView(app: app, size: 57)

						NBTitleWithSubtitleView(
							title: app.name ?? .localized("Unknown"),
							subtitle: [
								app.version,
								(app.date ?? .distantPast).formatted(.relative(presentation: .named))
							].compactMap { $0 }.joined(separator: " • ")
						)

						Spacer()

						WSActionButton(title: .localized("Open")) {
							UIApplication.openApp(with: app.identifier ?? "")
						}
					}
					.padding(.vertical, 2)
				}
			}
		}
	}

	// MARK: Rows

	@ViewBuilder
	private func _updateRow(_ update: AppUpdate) -> some View {
		HStack(spacing: 18) {
			FRAppIconView(app: _resolvePresentable(update), size: 57)
				.overlay(alignment: .topTrailing) {
					Circle()
						.fill(Color.accentColor)
						.frame(width: 10, height: 10)
						.offset(x: 4, y: -4)
				}

			NBTitleWithSubtitleView(
				title: update.appName,
				subtitle: _versionText(update),
				linelimit: 2
			)

			Spacer()

			WSActionButton(title: .localized("Update")) {
				_download(update)
			}
		}
		.padding(.vertical, 2)
		.swipeActions(edge: .leading) {
			Button {
				let enabled = autoUpdateManager.isAutoUpdateEnabled(for: update.bundleIdentifier)
				autoUpdateManager.setAutoUpdate(!enabled, for: update.bundleIdentifier)
			} label: {
				Label(
					autoUpdateManager.isAutoUpdateEnabled(for: update.bundleIdentifier)
						? .localized("Disable Auto")
						: .localized("Enable Auto"),
					systemImage: "automatic"
				)
			}
			.tint(.indigo)
		}
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
		}
	}

	@ViewBuilder
	private func _queueRow(_ job: AutoSignManager.Job, isActive: Bool) -> some View {
		HStack(spacing: 14) {
			if isActive {
				ProgressView()
			} else {
				Image(systemName: "hourglass")
					.foregroundStyle(.secondary)
			}

			VStack(alignment: .leading, spacing: 2) {
				Text(job.appName ?? .localized("Unknown"))
					.font(.subheadline.weight(.medium))
					.lineLimit(1)
				Text(_reasonLabel(job.reason))
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			Spacer()

			if isActive {
				Text(.localized("Signing"))
					.font(.caption.weight(.semibold))
					.textCase(.uppercase)
					.foregroundStyle(.tint)
			}
		}
		.padding(.vertical, 2)
	}

	private func _reasonLabel(_ reason: AutoSignManager.Reason) -> String {
		switch reason {
		case .autoSign: return .localized("Auto-Signed")
		case .autoUpdate: return .localized("Automatic Update")
		case .renewal: return .localized("Certificate Renewal")
		}
	}

	private func _versionText(_ update: AppUpdate) -> String {
		if let local = update.localVersion, !local.isEmpty {
			return "\(local) → \(update.remoteVersion)"
		}
		return update.remoteVersion
	}

	private func _resolvePresentable(_ update: AppUpdate) -> (any AppInfoPresentable)? {
		let signed = _signedApps.first { $0.uuid == update.localUUID }
		return signed
	}

	// MARK: Actions

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
