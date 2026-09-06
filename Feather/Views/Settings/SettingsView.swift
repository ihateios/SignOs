//
//  SettingsView.swift
//  Feather
//
//  Production-grade settings, Apple Settings-style icon tiles.
//

import SwiftUI
import NimbleViews
import UIKit
import IDeviceSwift

// MARK: - Icon tile (Settings.app style colored square)
struct WSIconTile: View {
	let systemImage: String
	var color: Color = .accentColor

	var body: some View {
		Image(systemName: systemImage)
			.font(.system(size: 14, weight: .semibold))
			.foregroundStyle(.white)
			.frame(width: 28, height: 28)
			.background(
				RoundedRectangle(cornerRadius: 6.5, style: .continuous)
					.fill(color)
			)
	}
}

// MARK: - View
struct SettingsView: View {
	@AppStorage("SignOs.autoDeleteOldVersions") private var _autoDeleteOldVersions: Bool = true
	@AppStorage("SignOs.biometricLock") private var _biometricLock: Bool = false
	@AppStorage("SignOs.defaultTab") private var _defaultTabRaw: String = TabEnum.discover.rawValue
	@State private var _isFolderPickerPresenting = false
	@AppStorage("SignOs.badgeUpdates") private var _badgeUpdates: Bool = false
	@StateObject private var autoUpdateManager = AutoUpdateManager.shared
	@StateObject private var autoSignManager = AutoSignManager.shared

	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Settings")) {
			Form {
				_profile()
				_general()
				_automation()
				_data()
				_signing()
				_appearance()
				_privacy()
				_misc()
				_danger()
				_footer()
			}
		}
		.sheet(isPresented: $_isFolderPickerPresenting) {
			FileImporterRepresentableView(
				allowedContentTypes: [.folder],
				directoryURL: WSFiles.pickerDirectory,
				asCopy: false,
				onDocumentsPicked: { urls in
					guard let url = urls.first else { return }
					WSFiles.saveBookmark(for: url)
				}
			)
			.ignoresSafeArea()
		}
	}
}

// MARK: - Sections
extension SettingsView {
	@ViewBuilder
	private func _profile() -> some View {
		Section {
			NavigationLink(destination: AboutView()) {
				HStack(spacing: 16) {
					FRAppIconView(size: 58)

					VStack(alignment: .leading, spacing: 3) {
						Text("SignOs")
							.font(.title2.weight(.bold))
						Text(verbatim: "Made By @ihateios")
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}

					Spacer()

					Text(verbatim: Bundle.main.version)
						.font(.caption.weight(.bold))
						.foregroundStyle(.tint)
						.padding(.horizontal, 9)
						.padding(.vertical, 4)
						.background(Capsule().fill(Color.accentColor.opacity(0.12)))
				}
				.padding(.vertical, 6)
			}
		}
	}

	@ViewBuilder
	private func _general() -> some View {
		Section {
			Picker(selection: $_defaultTabRaw) {
				Text(.localized("Discover")).tag(TabEnum.discover.rawValue)
				Text(.localized("Search")).tag(TabEnum.search.rawValue)
				Text(.localized("Library")).tag(TabEnum.library.rawValue)
				Text(.localized("Updates")).tag(TabEnum.updates.rawValue)
				Text(.localized("Settings")).tag(TabEnum.settings.rawValue)
			} label: {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "rectangle.on.rectangle", color: .blue)
					Text(.localized("Launch Tab"))
				}
			}
		} header: {
			Text(.localized("General"))
		} footer: {
			Text(.localized("The tab SignOs opens every time you launch it."))
		}
	}

	@ViewBuilder
	private func _automation() -> some View {
		Section {
			Toggle(isOn: Binding(
				get: { autoUpdateManager.isAutoUpdateEnabled },
				set: { autoUpdateManager.isAutoUpdateEnabled = $0 }
			)) {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "arrow.triangle.2.circlepath", color: .blue)
					Text(.localized("Update Automatically"))
				}
			}
			.tint(.accentColor)

			Picker(selection: Binding(
				get: { Int(autoUpdateManager.intervalHours) },
				set: { autoUpdateManager.intervalHours = Double($0) }
			)) {
				Text(.localized("Hourly")).tag(1)
				Text(.localized("Every 3 Hours")).tag(3)
				Text(.localized("Every 6 Hours")).tag(6)
				Text(.localized("Every 12 Hours")).tag(12)
				Text(.localized("Daily")).tag(24)
			} label: {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "clock", color: .indigo)
					Text(.localized("Check Interval"))
				}
			}

			Picker(selection: Binding(
				get: { autoUpdateManager.isWifiOnly },
				set: { autoUpdateManager.isWifiOnly = $0 }
			)) {
				Text(.localized("Any Connection")).tag(false)
				Text(.localized("Wi-Fi Only")).tag(true)
			} label: {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "wifi", color: .cyan)
					Text(.localized("Download Over"))
				}
			}

			Picker(selection: Binding(
				get: { autoUpdateManager.isNightWindowOnly },
				set: { autoUpdateManager.isNightWindowOnly = $0 }
			)) {
				Text(.localized("Anytime")).tag(false)
				Text(.localized("Night Only")).tag(true)
			} label: {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "moon.stars.fill", color: .purple)
					Text(.localized("Active Window"))
				}
			}

			Toggle(isOn: Binding(
				get: { autoSignManager.isAutoSignEnabled },
				set: { autoSignManager.isAutoSignEnabled = $0 }
			)) {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "signature", color: .green)
					Text(.localized("Auto-Sign Imported Apps"))
				}
			}
			.tint(.accentColor)

			Toggle(isOn: Binding(
				get: { autoUpdateManager.isAutoRenewEnabled },
				set: { autoUpdateManager.isAutoRenewEnabled = $0 }
			)) {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "checkmark.seal.fill", color: .teal)
					Text(.localized("Keep Apps Signed"))
				}
			}
			.tint(.accentColor)

			Toggle(isOn: Binding(
				get: { autoUpdateManager.isSelfHealEnabled },
				set: { autoUpdateManager.isSelfHealEnabled = $0 }
			)) {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "arrow.clockwise.heart", color: .mint)
					Text(.localized("Self-Heal Revoked Apps"))
				}
			}
			.tint(.accentColor)

			Toggle(isOn: $_autoDeleteOldVersions) {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "arrow.3.trianglepath", color: .orange)
					Text(.localized("Replace Old Versions"))
				}
			}
			.tint(.accentColor)

			Toggle(isOn: Binding(
				get: { autoUpdateManager.notificationsEnabled },
				set: { autoUpdateManager.notificationsEnabled = $0 }
			)) {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "bell.fill", color: .red)
					Text(.localized("Notifications"))
				}
			}
			.tint(.accentColor)

			Toggle(isOn: $_badgeUpdates) {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "app.badge.fill", color: .mint)
					Text(.localized("Badge App Icon"))
				}
			}
			.tint(.accentColor)
		} header: {
			Text(.localized("Automation"))
		} footer: {
			Text(.localized("SignOs checks your repositories and installs updates in the background, keeping your apps fresh and working. With a paired device, installs happen with no interaction at all."))
		}
	}

	@ViewBuilder
	private func _data() -> some View {
		Section {
			NavigationLink(destination: CertificatesView()) {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "checkmark.seal.fill", color: .green)
					Text(.localized("Certificates"))
				}
			}

			NavigationLink(destination: StorageView()) {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "internaldrive.fill", color: .blue)
					Text(.localized("Storage"))
				}
			}

			Button {
				_isFolderPickerPresenting = true
			} label: {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "folder.badge.gearshape", color: .indigo)
					VStack(alignment: .leading, spacing: 2) {
						Text(.localized("Import & Export Folder"))
						Text(verbatim: WSFiles.folderName)
							.font(.caption)
							.foregroundStyle(.secondary)
							.lineLimit(1)
					}
				}
			}
			.foregroundStyle(.primary)

			if WSFiles.hasCustomFolder {
				Button(role: .destructive) {
					WSFiles.clearBookmark()
				} label: {
					HStack(spacing: 12) {
						WSIconTile(systemImage: "arrow.uturn.backward", color: .gray)
						Text(.localized("Reset Folder to Default"))
					}
				}
			}

			NavigationLink(destination: ActivityView()) {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "clock.arrow.circlepath", color: .indigo)
					Text(.localized("Activity"))
				}
			}

			NavigationLink(destination: CertHealthView()) {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "stethoscope", color: .red)
					Text(.localized("Certificate Health"))
				}
			}

			NavigationLink(destination: BackupRestoreView()) {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "arrow.up.arrow.down.square.fill", color: .brown)
					Text(.localized("Backup & Restore"))
				}
			}
		} header: {
			Text(.localized("Data"))
		} footer: {
			Text(.localized("Certificates used for signing apps, and storage used by the app."))
		}
	}

	@ViewBuilder
	private func _signing() -> some View {
		Section {
			NavigationLink(destination: ConfigurationView()) {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "slider.horizontal.3", color: .purple)
					Text(.localized("Signing Options"))
				}
			}
			NavigationLink(destination: ArchiveView()) {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "archivebox.fill", color: .orange)
					Text(.localized("Archive & Compression"))
				}
			}
			NavigationLink(destination: InstallationView()) {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "arrow.down.circle.fill", color: .blue)
					Text(.localized("Installation"))
				}
			}
			NavigationLink(destination: TweakVaultView()) {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "puzzlepiece.extension.fill", color: .mint)
					Text(.localized("Tweak Vault"))
				}
			}
		} header: {
			Text(.localized("Signing"))
		} footer: {
			Text(.localized("Fine-tune how apps are installed, compressed and modified."))
		}
	}

	@ViewBuilder
	private func _appearance() -> some View {
		Section {
			NavigationLink(destination: AppearanceView()) {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "paintbrush.fill", color: .pink)
					Text(.localized("Appearance"))
				}
			}
		} header: {
			Text(.localized("Appearance"))
		}
	}

	@ViewBuilder
	private func _privacy() -> some View {
		Section {
			Toggle(isOn: $_biometricLock) {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "faceid", color: .blue)
					Text(.localized("Face ID Lock"))
				}
			}
			.tint(.accentColor)
		} header: {
			Text(.localized("Privacy"))
		} footer: {
			Text(.localized("Require Face ID to open SignOs."))
		}
	}

	@ViewBuilder
	private func _misc() -> some View {
		Section {
			Button {
				UIApplication.open(URL.documentsDirectory.toSharedDocumentsURL()!)
			} label: {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "folder.fill", color: .yellow)
					Text(.localized("Open Documents"))
				}
			}
			.foregroundStyle(.primary)

			Button {
				UIApplication.open(FileManager.default.archives.toSharedDocumentsURL()!)
			} label: {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "archivebox.fill", color: .orange)
					Text(.localized("Open Archives"))
				}
			}
			.foregroundStyle(.primary)
		} header: {
			Text(.localized("Files"))
		}
	}

	@ViewBuilder
	private func _danger() -> some View {
		Section {
			NavigationLink(destination: ResetView()) {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "trash.fill", color: .red)
					Text(.localized("Reset"))
						.foregroundStyle(.red)
				}
			}
		}
	}

	@ViewBuilder
	private func _footer() -> some View {
		Section {
			Text(verbatim: "SignOs \(Bundle.main.version) • Made By @ihateios")
				.font(.footnote)
				.foregroundStyle(.tertiary)
				.frame(maxWidth: .infinity, alignment: .center)
				.listRowBackground(Color.clear)
		}
	}
}
