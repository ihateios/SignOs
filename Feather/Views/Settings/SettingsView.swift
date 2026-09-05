//
//  SettingsView.swift
//  Feather
//
//  Created by samara on 10.04.2025.
//

import SwiftUI
import NimbleViews
import UIKit
import Darwin
import IDeviceSwift

// MARK: - View
struct SettingsView: View {
	@AppStorage("feather.selectedCert") private var _storedSelectedCert: Int = 0
	@AppStorage("SignOs.autoDeleteOldVersions") private var _autoDeleteOldVersions: Bool = true
	@StateObject private var autoUpdateManager = AutoUpdateManager.shared
	@StateObject private var autoSignManager = AutoSignManager.shared
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
				_certificates()
				_features()
				_directories()
				_danger()
			}
		}
	}
}

// MARK: - View extension
extension SettingsView {
	@ViewBuilder
	private func _profile() -> some View {
		Section {
			NavigationLink(destination: AboutView()) {
				HStack(spacing: 16) {
					FRAppIconView(size: 56)

					VStack(alignment: .leading, spacing: 3) {
						Text("SignOs")
							.font(.title2.weight(.bold))
						Text(verbatim: "by @ihateios")
							.font(.subheadline)
							.foregroundStyle(.secondary)
					}

					Spacer()

					Text(verbatim: Bundle.main.version)
						.font(.caption.weight(.semibold))
						.foregroundStyle(.secondary)
						.padding(.horizontal, 8)
						.padding(.vertical, 3)
						.background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
				}
				.padding(.vertical, 4)
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
				Label(.localized("Update Automatically"), systemImage: "arrow.triangle.2.circlepath")
			}

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
				Label(.localized("Check Interval"), systemImage: "clock")
			}

			Toggle(isOn: Binding(
				get: { autoSignManager.isAutoSignEnabled },
				set: { autoSignManager.isAutoSignEnabled = $0 }
			)) {
				Label(.localized("Auto-Sign Imported Apps"), systemImage: "signature")
			}

			Toggle(isOn: Binding(
				get: { autoUpdateManager.isAutoRenewEnabled },
				set: { autoUpdateManager.isAutoRenewEnabled = $0 }
			)) {
				Label(.localized("Keep Apps Signed"), systemImage: "checkmark.seal")
			}

			Picker(selection: Binding(
				get: { autoUpdateManager.renewThresholdDays },
				set: { autoUpdateManager.renewThresholdDays = $0 }
			)) {
				Text(.localized("1 Day Before")).tag(1)
				Text(.localized("2 Days Before")).tag(2)
				Text(.localized("3 Days Before")).tag(3)
				Text(.localized("5 Days Before")).tag(5)
			} label: {
				Label(.localized("Renew Ahead"), systemImage: "calendar.badge.clock")
			}

			Toggle(isOn: $_autoDeleteOldVersions) {
				Label(.localized("Replace Old Versions"), systemImage: "arrow.3.trianglepath")
			}

			Toggle(isOn: Binding(
				get: { autoUpdateManager.notificationsEnabled },
				set: { autoUpdateManager.notificationsEnabled = $0 }
			)) {
				Label(.localized("Notifications"), systemImage: "bell")
			}
		} header: {
			Text(.localized("Automation"))
		} footer: {
			Text(.localized("SignOs checks your repositories, silently downloads, signs and prepares updates, and re-signs apps before their certificate expires. Installations via a paired device are applied without any interaction."))
		}
	}

	@ViewBuilder
	private func _certificates() -> some View {
		NBSection(.localized("Certificates")) {

			if let cert = selectedCertificate {
				CertificatesCellView(cert: cert)
			} else {
				Text(.localized("No Certificate"))
					.font(.footnote)
					.foregroundColor(.disabled())
			}
			NavigationLink(destination: CertificatesView()) {
				Label(.localized("Certificates"), systemImage: "checkmark.seal")
			}

		} footer: {
			Text(.localized("Add and manage certificates used for signing applications."))
		}
	}

	@ViewBuilder
	private func _features() -> some View {
		NBSection(.localized("Signing")) {
			NavigationLink(destination: ConfigurationView()) {
				Label(.localized("Signing Options"), systemImage: "signature")
			}
			NavigationLink(destination: ArchiveView()) {
				Label(.localized("Archive & Compression"), systemImage: "archivebox")
			}
			NavigationLink(destination: InstallationView()) {
				Label(.localized("Installation"), systemImage: "arrow.down.circle")
			}
		} footer: {
			Text(.localized("Configure the apps way of installing, its zip compression levels, and custom modifications to apps."))
		}

		NBSection(.localized("Appearance")) {
			NavigationLink(destination: AppearanceView()) {
				Label(.localized("Appearance"), systemImage: "paintbrush")
			}
		}
	}

	@ViewBuilder
	private func _directories() -> some View {
		NBSection(.localized("Misc")) {
			Button(.localized("Open Documents"), systemImage: "folder") {
				UIApplication.open(URL.documentsDirectory.toSharedDocumentsURL()!)
			}
			Button(.localized("Open Archives"), systemImage: "folder") {
				UIApplication.open(FileManager.default.archives.toSharedDocumentsURL()!)
			}
			Button(.localized("Open Certificates"), systemImage: "folder") {
				UIApplication.open(FileManager.default.certificates.toSharedDocumentsURL()!)
			}
		} footer: {
			Text(.localized("All of the apps files are contained in the documents directory, here are some quick links to these."))
		}
	}

	@ViewBuilder
	private func _danger() -> some View {
		Section {
			NavigationLink(destination: ResetView()) {
				Label(.localized("Reset"), systemImage: "trash")
			}
		} footer: {
			Text(.localized("Reset the applications sources, certificates, apps, and general contents."))
		}
	}
}
