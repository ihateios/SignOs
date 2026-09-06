//
//  LibraryView.swift
//  Feather
//
//  From-scratch App Store-style library surface.
//

import SwiftUI
import CoreData
import NimbleViews

// MARK: - View
struct LibraryView: View {
	@StateObject var downloadManager = DownloadManager.shared
	@StateObject var updateManager = UpdateManager.shared
	@ObservedObject private var autoSignManager = AutoSignManager.shared

	@State private var _selectedInfoAppPresenting: AnyApp?
	@State private var _selectedSigningAppPresenting: AnyApp?
	@State private var _selectedInstallAppPresenting: AnyApp?
	@State private var _isImportingPresenting = false
	@State private var _isDownloadingPresenting = false
	@State private var _alertDownloadString = ""

	@State private var _searchText = ""
	@State private var _selectedScope: Scope = .all

	// MARK: Fetch
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

	@FetchRequest(
		entity: AltSource.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
		animation: .snappy
	) private var _sources: FetchedResults<AltSource>

	private var _filteredSigned: [Signed] {
		_signedApps.filter { _matches($0.name) }
	}

	private var _filteredImported: [Imported] {
		_importedApps.filter { _matches($0.name) }
	}

	private var _showSigned: Bool {
		_selectedScope == .all || _selectedScope == .signed
	}

	private var _showImported: Bool {
		_selectedScope == .all || _selectedScope == .imported
	}

	private var _isCompletelyEmpty: Bool {
		_filteredSigned.isEmpty && _filteredImported.isEmpty
	}

	private func _matches(_ name: String?) -> Bool {
		_searchText.isEmpty || (name?.localizedCaseInsensitiveContains(_searchText) ?? false)
	}

	// MARK: Body
	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 22) {
					WSHeroHeader(
						eyebrow: _countText,
						title: "Library"
					)

					_searchBar()

					if _showSigned && !_filteredSigned.isEmpty {
						_appSection(title: "Installed", apps: _filteredSigned)
					}

					if _showImported && !_filteredImported.isEmpty {
						_appSection(title: "Ready to Install", apps: _filteredImported)
					}

					if _isCompletelyEmpty {
						_emptyCard()
					}

					_addCard()
				}
				.padding(.horizontal, 16)
				.padding(.top, 4)
				.padding(.bottom, 28)
			}
			.background(Color(uiColor: .systemGroupedBackground))
			.toolbar(.hidden, for: .navigationBar)
			.refreshable {
				await _checkForUpdates()
			}
			.sheet(item: $_selectedInfoAppPresenting) { app in
				LibraryInfoView(app: app.base)
			}
			.sheet(item: $_selectedInstallAppPresenting) { app in
				InstallPreviewView(app: app.base, isSharing: app.archive)
					.presentationDetents([.height(200)])
					.presentationDragIndicator(.visible)
			}
			.fullScreenCover(item: $_selectedSigningAppPresenting) { app in
				SigningView(app: app.base)
			}
			.sheet(isPresented: $_isImportingPresenting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.ipa, .tipa],
					allowsMultipleSelection: true,
					directoryURL: WSFiles.pickerDirectory,
					onDocumentsPicked: { urls in
						guard !urls.isEmpty else { return }
						for url in urls {
							let id = "FeatherManualDownload_\(UUID().uuidString)"
							let dl = downloadManager.startArchive(from: url, id: id)
							try? downloadManager.handlePachageFile(url: url, dl: dl)
						}
					}
				)
				.ignoresSafeArea()
			}
			.alert(.localized("Import from URL"), isPresented: $_isDownloadingPresenting) {
				TextField(.localized("URL"), text: $_alertDownloadString)
					.textInputAutocapitalization(.never)
				Button(.localized("Cancel"), role: .cancel) {
					_alertDownloadString = ""
				}
				Button(.localized("OK")) {
					if let url = URL(string: _alertDownloadString) {
						_ = downloadManager.startDownload(from: url, id: "FeatherManualDownload_\(UUID().uuidString)")
					}
				}
			}
			.onReceive(NotificationCenter.default.publisher(for: Notification.Name("Feather.installApp"))) { _ in
				if let latest = _signedApps.first {
					_selectedInstallAppPresenting = AnyApp(base: latest)
				}
			}
		}
	}
}

// MARK: - Sections
extension LibraryView {
	private var _countText: String {
		let total = _filteredSigned.count + _filteredImported.count
		return total == 1 ? "1 APP" : "\(total) APPS"
	}

	@ViewBuilder
	private func _searchBar() -> some View {
		HStack(spacing: 8) {
			Image(systemName: "magnifyingglass")
				.foregroundStyle(.secondary)
			TextField("Search apps", text: $_searchText)
				.textInputAutocapitalization(.never)
				.autocorrectionDisabled()
			if !_searchText.isEmpty {
				Button {
					_searchText = ""
				} label: {
					Image(systemName: "xmark.circle.fill")
						.foregroundStyle(.tertiary)
				}
			}
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 10)
		.background(
			RoundedRectangle(cornerRadius: 14, style: .continuous)
				.fill(Color(uiColor: .secondarySystemGroupedBackground))
		)

		Picker("", selection: $_selectedScope) {
			Text("All").tag(Scope.all)
			Text("Installed").tag(Scope.signed)
			Text("Imports").tag(Scope.imported)
		}
		.pickerStyle(.segmented)
	}

	@ViewBuilder
	private func _appSection(title: String, apps: [any AppInfoPresentable]) -> some View {
		VStack(alignment: .leading, spacing: 12) {
			WSSectionTitle(title: title, actionTitle: "\(apps.count)")

			VStack(spacing: 10) {
				ForEach(apps, id: \.uuid) { app in
					_appCard(app)
				}
			}
		}
	}

	@ViewBuilder
	private func _appCard(_ app: any AppInfoPresentable) -> some View {
		HStack(spacing: 14) {
			FRAppIconView(app: app, size: 57)
				.overlay(alignment: .topTrailing) {
					if updateManager.update(for: app) != nil {
						Circle()
							.fill(Color.accentColor)
							.frame(width: 10, height: 10)
							.offset(x: 4, y: -4)
					}
				}

			VStack(alignment: .leading, spacing: 3) {
				Text(app.name ?? "Unknown")
					.font(.body.weight(.semibold))
					.foregroundStyle(.primary)
					.lineLimit(1)
				Text(verbatim: app.version ?? "")
					.font(.caption)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}

			Spacer()

			_actionPill(app)
		}
		.padding(14)
		.background(
			RoundedRectangle(cornerRadius: 20, style: .continuous)
				.fill(Color(uiColor: .secondarySystemGroupedBackground))
		)
		.contextMenu {
			_contextActions(app)
		}
	}

	@ViewBuilder
	private func _actionPill(_ app: any AppInfoPresentable) -> some View {
		if let update = updateManager.update(for: app) {
			WSActionButton(title: "Update") {
				_startUpdateDownload(update)
			}
		} else if app.isSigned {
			WSActionButton(title: "Open") {
				UIApplication.openApp(with: app.identifier ?? "")
			}
		} else {
			WSActionButton(title: "Get", systemImage: "arrow.down.circle") {
				if autoSignManager.isAutoSignEnabled {
					UIImpactFeedbackGenerator(style: .medium).impactOccurred()
					AutoSignManager.shared.enqueue(app: app, reason: .autoSign)
				} else {
					_selectedSigningAppPresenting = AnyApp(base: app)
				}
			}
		}
	}

	@ViewBuilder
	private func _contextActions(_ app: any AppInfoPresentable) -> some View {
		Button {
			_selectedInfoAppPresenting = AnyApp(base: app)
		} label: {
			Label("Get Info", systemImage: "info.circle")
		}

		if let update = updateManager.update(for: app) {
			Button {
				_startUpdateDownload(update)
			} label: {
				Label("Update", systemImage: "arrow.down.circle")
			}
		}

		if app.isSigned {
			Button {
				UIApplication.openApp(with: app.identifier ?? "")
			} label: {
				Label("Open", systemImage: "app.badge.checkmark")
			}
			Button {
				_selectedInstallAppPresenting = AnyApp(base: app)
			} label: {
				Label("Install", systemImage: "square.and.arrow.down")
			}
			Button {
				_selectedSigningAppPresenting = AnyApp(base: app)
			} label: {
				Label("Re-sign", systemImage: "signature")
			}
			Button {
				UIImpactFeedbackGenerator(style: .medium).impactOccurred()
				AutoSignManager.shared.cloneApp(app: app)
			} label: {
			Label("Clone App", systemImage: "plus.square.on.square")
			}
			Button {
				_selectedInstallAppPresenting = AnyApp(base: app, archive: true)
			} label: {
				Label("Export", systemImage: "square.and.arrow.up")
			}
		} else {
			Button {
				_selectedInstallAppPresenting = AnyApp(base: app)
			} label: {
				Label("Install", systemImage: "square.and.arrow.down")
			}
			Button {
				_selectedSigningAppPresenting = AnyApp(base: app)
			} label: {
				Label("Sign", systemImage: "signature")
			}
			Button {
				UIImpactFeedbackGenerator(style: .medium).impactOccurred()
				AutoSignManager.shared.cloneApp(app: app)
			} label: {
			Label("Clone App", systemImage: "plus.square.on.square")
			}
		}

		Divider()

		Button(role: .destructive) {
			Storage.shared.deleteApp(for: app)
		} label: {
			Label("Remove", systemImage: "trash")
		}
	}

	private func _emptyCard() -> some View {
		VStack(spacing: 10) {
			Image(systemName: "square.stack.3d.up.slash")
				.font(.system(size: 40))
				.foregroundStyle(.tint)
			Text("No Apps Yet")
				.font(.headline)
			Text("Import an app or grab one from your sources.")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, 36)
		.background(
			RoundedRectangle(cornerRadius: 24, style: .continuous)
				.fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.6))
		)
	}

	private func _addCard() -> some View {
		Menu {
			Button("Import from Files") {
				_isImportingPresenting = true
			}
			Button("Import from URL") {
				_isDownloadingPresenting = true
			}
		} label: {
			HStack(spacing: 10) {
				Image(systemName: "plus.circle.fill")
					.font(.title3)
					.foregroundStyle(.tint)
				Text("Add App")
					.font(.body.weight(.semibold))
					.foregroundStyle(.tint)
				Spacer()
			}
			.padding(16)
			.background(
				RoundedRectangle(cornerRadius: 20, style: .continuous)
					.fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.6))
					.overlay(
						RoundedRectangle(cornerRadius: 20, style: .continuous)
							.strokeBorder(
								Color(uiColor: .separator).opacity(0.4),
								style: StrokeStyle(lineWidth: 1.2, dash: [6])
							)
					)
			)
		}
	}
}

// MARK: - Actions
extension LibraryView {
	enum Scope: CaseIterable {
		case all
		case signed
		case imported
	}

	private func _checkForUpdates() async {
		let localApps = _signedApps.map { $0 as AppInfoPresentable }
			+ _importedApps.map { $0 as AppInfoPresentable }
		await updateManager.checkForUpdates(
			sources: Array(_sources),
			localApps: localApps
		)
	}

	private func _startUpdateDownload(_ update: AppUpdate) {
		UIImpactFeedbackGenerator(style: .light).impactOccurred()
		_ = DownloadManager.shared.startDownload(
			from: update.downloadURL,
			id: "SignOsManualUpdate_\(update.localUUID)",
			sourceProvenance: update.sourceProvenance
		)
	}
}
