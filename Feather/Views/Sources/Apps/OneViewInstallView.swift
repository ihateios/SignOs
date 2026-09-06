//
//  OneViewInstallView.swift
//  Feather
//
//  One-view install: GET → downloading → installing → open,
//  the entire journey on a single screen.
//

import SwiftUI
import Combine
import CoreData
import AltSourceKit
import NimbleViews

// MARK: - Phase
enum OneViewPhase: Equatable {
	case idle
	case downloading
	case preparing
	case needsSign
	case ready
	case installed

	var buttonTitle: String {
		switch self {
		case .idle: return "Get"
		case .downloading: return ""
		case .preparing: return "Installing"
		case .needsSign: return "Sign & Install"
		case .ready: return "Install"
		case .installed: return "Open"
		}
	}
}

// MARK: - Phase resolver
struct OneViewTracker {
	let sourceURL: URL?
	let source: ASRepository?
	let app: ASRepository.App
	var startedAt: Date

	@MainActor
	func phase(downloadManager: DownloadManager, autoSignManager: AutoSignManager, signed: [Signed], imported: [Imported]) -> OneViewPhase {
		if downloadManager.getDownload(by: app.currentUniqueId) != nil {
			return .downloading
		}

		let queueJobs = (autoSignManager.currentJob.map { [$0] } ?? []) + autoSignManager.queue
		if queueJobs.contains(where: { $0.appIdentifier == app.id }) {
			return .preparing
		}

		let identifier = app.id
		let newestSigned = signed
			.filter { $0.identifier == identifier && ($0.date ?? .distantPast) >= startedAt }
			.max { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
		if newestSigned != nil {
			return .installed
		}

		let newestImported = imported
			.filter { $0.identifier == identifier && ($0.date ?? .distantPast) >= startedAt }
			.max { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
		if newestImported != nil, AutoSignManager.shared.isAutoSignEnabled == false {
			return .needsSign
		}

		return .idle
	}
}

// MARK: - Inline Get button (lists & carousels)
struct WSOneViewGetButton: View {
	let sourceURL: URL?
	let source: ASRepository?
	let app: ASRepository.App

	@ObservedObject private var downloadManager = DownloadManager.shared
	@ObservedObject private var autoSignManager = AutoSignManager.shared
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

	@State private var _startedAt = Date()
	@State private var _progress: Double = 0
	@State private var _presenting = false
	@State private var _cancellable: AnyCancellable?

	var body: some View {
		let tracker = OneViewTracker(sourceURL: sourceURL, source: source, app: app, startedAt: _startedAt)
		let phase = tracker.phase(
			downloadManager: downloadManager,
			autoSignManager: autoSignManager,
			signed: Array(_signedApps),
			imported: Array(_importedApps)
		)

		Group {
			switch phase {
			case .idle, .needsSign:
				Button {
					_presenting = true
				} label: {
					_getLabel(phase)
				}
				.buttonStyle(.borderless)
			case .downloading:
				ZStack {
					Circle()
						.trim(from: 0, to: max(0.02, _progress))
						.stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2.3, lineCap: .round))
						.rotationEffect(.degrees(-90))
						.frame(width: 31, height: 31)
					Image(systemName: "xmark")
						.font(.caption2.bold())
						.foregroundStyle(.tint)
				}
				.onTapGesture {
					if let download = downloadManager.getDownload(by: app.currentUniqueId) {
						downloadManager.cancelDownload(download)
					}
				}
			case .preparing:
				ProgressView()
					.frame(width: 64, minHeight: 30)
			case .ready:
				Button {
					_presenting = true
				} label: {
					Text(.localized("Install"))
						.lineLimit(0)
						.font(.headline.bold())
						.foregroundStyle(Color.white)
						.padding(.horizontal, 20)
						.padding(.vertical, 6)
						.background(Color.accentColor)
						.clipShape(Capsule())
				}
				.buttonStyle(.borderless)
			case .installed:
				Button {
					UIApplication.openApp(with: app.id)
				} label: {
					Text(.localized("Open"))
						.lineLimit(0)
						.font(.headline.bold())
						.foregroundStyle(Color.white)
						.padding(.horizontal, 20)
						.padding(.vertical, 6)
						.background(Color.green)
						.clipShape(Capsule())
				}
				.buttonStyle(.borderless)
			}
		}
		.animation(.easeInOut(duration: 0.3), value: phase)
		.sheet(isPresented: $_presenting) {
			OneViewInstallView(sourceURL: sourceURL, source: source, app: app)
		}
		.onAppear {
			_startedAt = Date()
			_setupObserver()
		}
		.onDisappear { _cancellable?.cancel() }
		.onChange(of: downloadManager.downloads.description) { _ in
			_setupObserver()
		}
	}

	private func _setupObserver() {
		_cancellable?.cancel()
		guard let download = downloadManager.getDownload(by: app.currentUniqueId) else {
			_progress = 0
			return
		}
		_progress = download.overallProgress
		_cancellable = Publishers.CombineLatest(download.$progress, download.$unpackageProgress).sink { _, _ in
			_progress = download.overallProgress
		}
	}

	@ViewBuilder
	private func _getLabel(_ phase: OneViewPhase) -> some View {
		Text(verbatim: phase == .needsSign ? .localized("Sign & Install") : .localized("Get"))
			.lineLimit(0)
			.font(.headline.bold())
			.foregroundStyle(Color.accentColor)
			.padding(.horizontal, 24)
			.padding(.vertical, 6)
			.background(Color(uiColor: .quaternarySystemFill))
			.clipShape(Capsule())
	}
}

// MARK: - The one-view sheet
struct OneViewInstallView: View {
	@Environment(\.dismiss) var dismiss

	let sourceURL: URL?
	let source: ASRepository?
	let app: ASRepository.App

	@ObservedObject private var downloadManager = DownloadManager.shared
	@ObservedObject private var autoSignManager = AutoSignManager.shared
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

	@State private var _startedAt = Date()
	@State private var _presentingInstall = false
	@State private var _signingApp: Imported?

	private var tracker: OneViewTracker {
		OneViewTracker(sourceURL: sourceURL, source: source, app: app, startedAt: _startedAt)
	}

	private var _download: Download? {
		downloadManager.getDownload(by: app.currentUniqueId)
	}

	private var _newestInstalled: Signed? {
		_signedApps
			.filter { $0.identifier == app.id && ($0.date ?? .distantPast) >= _startedAt }
			.max { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
	}

	private var _newestImported: Imported? {
		_importedApps
			.filter { $0.identifier == app.id && ($0.date ?? .distantPast) >= _startedAt }
			.max { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
	}

	private var _phase: OneViewPhase {
		tracker.phase(
			downloadManager: downloadManager,
			autoSignManager: autoSignManager,
			signed: Array(_signedApps),
			imported: Array(_importedApps)
		)
	}

	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(spacing: 22) {
					VStack(spacing: 12) {
						WSAppIcon(url: app.iconURL, size: 100)
						Text(app.currentName)
							.font(.title2.weight(.bold))
							.multilineTextAlignment(.center)
						Text(verbatim: [
							app.currentVersion,
							source?.name
						].compactMap { $0 }.joined(separator: " • "))
							.font(.caption)
							.foregroundStyle(.secondary)
					}
					.frame(maxWidth: .infinity)

					_statusCard()

					if let whatsNew = app.currentAppVersion?.localizedDescription,
					   !whatsNew.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
						VStack(alignment: .leading, spacing: 8) {
							Text("What's New")
								.font(.headline)
							Text(whatsNew)
								.font(.subheadline)
								.foregroundStyle(.secondary)
						}
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding(16)
						.background(
							RoundedRectangle(cornerRadius: 20, style: .continuous)
								.fill(Color(uiColor: .secondarySystemGroupedBackground))
						)
					}

					if let description = app.localizedDescription {
						VStack(alignment: .leading, spacing: 8) {
							Text("Description")
								.font(.headline)
							Text(description)
								.font(.subheadline)
								.foregroundStyle(.secondary)
						}
						.frame(maxWidth: .infinity, alignment: .leading)
						.padding(16)
						.background(
							RoundedRectangle(cornerRadius: 20, style: .continuous)
								.fill(Color(uiColor: .secondarySystemGroupedBackground))
						)
					}
				}
				.padding(16)
				.padding(.bottom, 24)
			}
			.background(Color(uiColor: .systemGroupedBackground))
			.navigationTitle("Install")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				NBToolbarButton(role: .dismiss)
			}
			.sheet(isPresented: $_presentingInstall) {
				if let installed = _newestInstalled {
					InstallPreviewView(app: installed)
				}
			}
			.fullScreenCover(item: $_signingApp) { imported in
				SigningView(app: imported)
			}
			.onAppear { _startedAt = Date() }
		}
	}
}

// MARK: - Status card
extension OneViewInstallView {
	@ViewBuilder
	private func _statusCard() -> some View {
		let phase = _phase

		VStack(spacing: 14) {
			switch phase {
			case .idle, .needsSign:
				Button {
					if phase == .needsSign, let imported = _newestImported {
						// signing automation is off — hand it to the sign flow
						_dismissAndPresentSign(imported)
						return
					}
					if let url = app.currentDownloadUrl {
						_ = downloadManager.startDownload(
							from: url,
							id: app.currentUniqueId,
							sourceProvenance: _provenance()
						)
					}
				} label: {
					_prominentButton(
						title: phase == .needsSign ? "Sign & Install" : "Get",
						systemImage: "arrow.down.circle.fill",
						color: .accentColor
					)
				}
				.buttonStyle(.plain)

				Text(phase == .needsSign
					? "Downloaded. Turn on Auto-Sign in Settings for one-tap installs."
					: "Downloads, signs and installs automatically.")
					.font(.caption)
					.foregroundStyle(.secondary)

			case .downloading:
				if let download = _download {
					HStack {
						Text("Downloading")
							.font(.subheadline.weight(.semibold))
						Spacer()
						Text(verbatim: "\(Int(download.overallProgress * 100))%")
							.font(.subheadline.weight(.semibold).monospacedDigit())
							.contentTransition(.numericText())
					}
					ProgressView(value: download.overallProgress)
						.progressViewStyle(.linear)
					HStack {
						if download.totalBytes > 0 {
							Text(verbatim: "\(download.bytesDownloaded.formattedByteCount) of \(download.totalBytes.formattedByteCount)")
						}
						Spacer()
						Button {
							downloadManager.cancelDownload(download)
						} label: {
							Text("Cancel")
								.font(.footnote.weight(.semibold))
								.foregroundStyle(.red)
						}
					}
					.font(.caption2)
					.foregroundStyle(.secondary)
					Text("After the download it signs and installs automatically.")
						.font(.caption2)
						.foregroundStyle(.tertiary)
						.frame(maxWidth: .infinity, alignment: .leading)
				}

			case .preparing:
				HStack(spacing: 12) {
					ProgressView()
					VStack(alignment: .leading, spacing: 3) {
						Text("Installing…")
							.font(.subheadline.weight(.semibold))
						Text("Signing and preparing. You'll be notified when it's ready.")
							.font(.caption)
							.foregroundStyle(.secondary)
					}
					Spacer()
				}

			case .ready:
				Button {
					_presentingInstall = true
				} label: {
					_prominentButton(title: "Install Now", systemImage: "square.and.arrow.down.fill", color: .accentColor)
				}
				.buttonStyle(.plain)
				Text("Signed and ready. One tap to install.")
					.font(.caption)
					.foregroundStyle(.secondary)

			case .installed:
				Button {
					UIApplication.openApp(with: app.id)
				} label: {
					_prominentButton(title: "Open", systemImage: "app.badge.fill", color: .green)
				}
				.buttonStyle(.plain)
				Text("Installed on this device.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
		}
		.padding(16)
		.frame(maxWidth: .infinity)
		.background(
			RoundedRectangle(cornerRadius: 22, style: .continuous)
				.fill(Color(uiColor: .secondarySystemGroupedBackground))
		)
		.animation(.smooth, value: phase)
	}

	private func _prominentButton(title: String, systemImage: String, color: Color) -> some View {
		HStack(spacing: 8) {
			Image(systemName: systemImage)
			Text(title)
				.font(.headline)
		}
		.foregroundStyle(.white)
		.frame(maxWidth: .infinity, minHeight: 48)
		.background(
			RoundedRectangle(cornerRadius: 15, style: .continuous)
				.fill(color)
		)
	}

	private func _provenance() -> SourceAppProvenance? {
		guard let source else { return nil }
		return SourceAppProvenance(sourceURL: sourceURL, repository: source, app: app)
	}

	private func _dismissAndPresentSign(_ imported: Imported) {
		_signingApp = imported
	}
}
