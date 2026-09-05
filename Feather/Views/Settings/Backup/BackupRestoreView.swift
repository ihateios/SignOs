//
//  BackupRestoreView.swift
//  Feather
//
//  Export and restore sources + preferences.
//

import SwiftUI
import UniformTypeIdentifiers
import NimbleViews

// MARK: - View
struct BackupRestoreView: View {
	@State private var _statusMessage: String?
	@State private var _isImporting = false

	/// Every preference key SignOs owns, in both directions.
	private static let _managedKeys: [String] = [
		"SignOs.autoUpdateEnabled",
		"SignOs.autoUpdateInterval",
		"SignOs.autoUpdateWifiOnly",
		"SignOs.autoUpdateNightOnly",
		"SignOs.autoSignEnabled",
		"SignOs.autoRenewEnabled",
		"SignOs.autoDeleteOldVersions",
		"SignOs.notificationsEnabled",
		"SignOs.badgeUpdates",
		"SignOs.biometricLock",
		"SignOs.perAppAutoUpdate",
		"SignOs.sourceAutoUpdate",
		"SignOs.recentSearches",
		"feather.selectedCert",
		"Feather.userTintColor"
	]

	var body: some View {
		NBNavigationView(.localized("Backup & Restore")) {
			Form {
				NBSection(.localized("Backup")) {
					Button {
						_export()
					} label: {
						Label(.localized("Export Sources & Settings"), systemImage: "square.and.arrow.up")
					}
				} footer: {
					Text(.localized("Exports your repositories and all SignOs preferences to a file. Certificates are not included."))
				}

				NBSection(.localized("Restore")) {
					Button {
						_isImporting = true
					} label: {
						Label(.localized("Import Backup File"), systemImage: "square.and.arrow.down")
					}
				} footer: {
					Text(.localized("Adds the repositories from a backup and applies its preferences."))
				}

				if let message = _statusMessage {
					Section {
						Text(message)
							.font(.footnote)
							.foregroundStyle(.secondary)
					}
				}
			}
		}
		.navigationTitle(.localized("Backup & Restore"))
		.sheet(isPresented: $_isImporting) {
			FileImporterRepresentableView(
				allowedContentTypes: [.json],
				onDocumentsPicked: { urls in
					guard let url = urls.first else { return }
					_import(url)
				}
			)
			.ignoresSafeArea()
		}
	}
}

// MARK: - Actions
extension BackupRestoreView {
	private var _backupPayload: [String: Any] {
		var settings: [String: Any] = [:]
		for key in Self._managedKeys {
			if let value = UserDefaults.standard.object(forKey: key) {
				settings[key] = value
			}
		}

		let sources = Storage.shared.getSources().compactMap { $0.sourceURL?.absoluteString }

		return [
			"format": "signos-backup",
			"version": 1,
			"exportedAt": ISO8601DateFormatter().string(from: Date()),
			"sources": sources,
			"settings": settings
		]
	}

	private func _export() {
		let payload = _backupPayload

		guard JSONSerialization.isValidJSONObject(payload) else {
			_statusMessage = .localized("Backup failed: invalid data.")
			return
		}

		do {
			let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
			let stamp = Int(Date().timeIntervalSince1970)
			let url = URL.documentsDirectory.appendingPathComponent("SignOs-Backup-\(stamp).json")
			try data.write(to: url)
			_statusMessage = .localized("Backup saved to Documents.")
			UIActivityViewController.show(activityItems: [url])
		} catch {
			_statusMessage = .localized("Backup failed: %@").replacingOccurrences(of: "%@", with: error.localizedDescription)
		}
	}

	private func _import(_ url: URL) {
		let secured = url.startAccessingSecurityScopedResource()
		defer { if secured { url.stopAccessingSecurityScopedResource() } }

		do {
			let data = try Data(contentsOf: url)
			guard
				let payload = try JSONSerialization.jsonObject(with: data) as? [String: Any],
				payload["format"] as? String == "signos-backup"
			else {
				_statusMessage = .localized("Not a valid SignOs backup file.")
				return
			}

			var restored = 0
			if let settings = payload["settings"] as? [String: Any] {
				for key in Self._managedKeys where settings[key] != nil {
					UserDefaults.standard.set(settings[key], forKey: key)
					restored += 1
				}
			}

			let sources = payload["sources"] as? [String] ?? []
			for sourceString in sources {
				if let _ = URL(string: sourceString) {
					FR.handleSource(sourceString) { }
				}
			}

			_statusMessage = .localized("Restored %lld settings and %lld sources.")
				.replacingOccurrences(of: "%lld", with: "\(restored), \(sources.count)")
		} catch {
			_statusMessage = .localized("Restore failed: %@").replacingOccurrences(of: "%@", with: error.localizedDescription)
		}
	}
}
