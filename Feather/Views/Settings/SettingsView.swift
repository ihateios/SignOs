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
	@AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
	@AppStorage("SignOs.autoDeleteOldVersions") private var _autoDeleteOldVersions: Bool = true
	@AppStorage("SignOs.biometricLock") private var _biometricLock: Bool = false
	@StateObject private var autoUpdateManager = AutoUpdateManager.shared
	@StateObject private var autoSignManager = AutoSignManager.shared

	// MARK: Fetch
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var _certificates: FetchedResults<CertificatePair>

	private var selectedCertificate: CertificatePair? {
		guard
			_storedSelectedCert >= 0,
			_storedSelectedCert < _certificates.count
		else {
			return nil
		}
		return _certificates[_storedSelectedCert]
	}

	// MARK: Body
	var body: some View {
		NBNavigationView(.localized("Settings")) {
			Form {
				_profile()
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
		} header: {
			Text(.localized("Automation"))
		} footer: {
			Text(.localized("SignOs checks your repositories and installs updates in the background, keeping your apps fresh and working. With a paired device, installs happen with no interaction at all."))
		}
	}

	@ViewBuilder
	private func _data() -> some View {
		Section {
			if let cert = selectedCertificate {
				CertificatesCellView(cert: cert)
			} else {
				HStack(spacing: 12) {
					WSIconTile(systemImage: "checkmark.seal", color: .gray)
					Text(.localized("No Certificate"))
						.foregroundStyle(.secondary)
				}
			}

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
