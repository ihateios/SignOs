//
//  StorageView.swift
//  Feather
//
//  Storage usage and one-tap cleanup.
//

import SwiftUI
import CoreData
import NimbleViews

// MARK: - View
struct StorageView: View {
	@State private var _sizes: [Category: Int64] = [:]
	@State private var _isCleaning = false
	@State private var _cleanedMessage: String?

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

	enum Category: String, CaseIterable {
		case archives = "Archives"
		case certificates = "Certificates"
		case installed = "Installed Apps"
		case imports = "Imported Apps"
	}

	var body: some View {
		NBNavigationView(.localized("Storage")) {
			Form {
				NBSection(.localized("Usage")) {
					ForEach(Category.allCases, id: \.self) { category in
						HStack {
							Label(category.rawValue, systemImage: _icon(for: category))
							Spacer()
							Text(verbatim: (_sizes[category] ?? 0).formattedByteCount)
								.font(.footnote.weight(.semibold).monospacedDigit())
								.foregroundStyle(.secondary)
						}
					}
					HStack {
						Text(.localized("Total"))
							.font(.body.weight(.semibold))
						Spacer()
						Text(verbatim: Category.allCases.reduce(Int64(0)) { $0 + (_sizes[$1] ?? 0) }.formattedByteCount)
							.font(.footnote.weight(.bold).monospacedDigit())
							.foregroundStyle(.tint)
					}
				} footer: {
					Text(.localized("Superseded copies are older versions of apps you already updated."))
				}

				NBSection(.localized("Cleanup")) {
					Button {
						_cleanSuperseded()
					} label: {
						Label(.localized("Remove Superseded Copies"), systemImage: "arrow.3.trianglepath")
					}
					.disabled(_isCleaning || _supersededCount == 0)

					Button {
						_clearArchives()
					} label: {
						Label(.localized("Clear Archives"), systemImage: "archivebox")
					}
					.disabled(_isCleaning || (_sizes[.archives] ?? 0) == 0)
				}

				NBSection(.localized("Duplicates")) {
					Button {
						_cleanDuplicates()
					} label: {
						Label(.localized("Remove Imported Duplicates"), systemImage: "square.stack.3d.up.slash")
					}
					.disabled(_isCleaning || _duplicateCount == 0)
				} footer: {
					Text(.localized("Imported copies of apps that already have an installed version."))
				}

				if let message = _cleanedMessage {
					Section {
						Text(message)
							.font(.footnote)
							.foregroundStyle(.secondary)
					}
				}
			}
		}
		.onAppear { _refreshSizes() }
	}

	private var _supersededCount: Int {
		var newestByIdentifier: [String: Date] = [:]
		for app in _signedApps {
			guard let identifier = app.identifier else { continue }
			let date = app.date ?? .distantPast
			if date > (newestByIdentifier[identifier] ?? .distantPast) {
				newestByIdentifier[identifier] = date
			}
		}
		return _signedApps.filter { app in
			guard let identifier = app.identifier else { return false }
			guard let newest = newestByIdentifier[identifier] else { return false }
			return (app.date ?? .distantPast) < newest
		}.count
	}
}

// MARK: - Actions
extension StorageView {
	private func _icon(for category: Category) -> String {
		switch category {
		case .archives: return "archivebox"
		case .certificates: return "checkmark.seal"
		case .installed: return "square.stack.3d.up.fill"
		case .imports: return "tray.and.arrow.down.fill"
		}
	}

	private func _refreshSizes() {
		let fileManager = FileManager.default
		_sizes = [
			.archives: _directorySize(fileManager.archives),
			.certificates: _directorySize(fileManager.certificates),
			.installed: _directorySize(fileManager.signed),
			.imports: _directorySize(fileManager.unsigned)
		]
	}

	private func _directorySize(_ url: URL) -> Int64 {
		let fileManager = FileManager.default
		guard
			let enumerator = fileManager.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey])
		else {
			return 0
		}

		var total: Int64 = 0
		for case let fileURL as URL in enumerator {
			if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
				total += Int64(size)
			}
		}
		return total
	}

	private var _duplicateCount: Int {
		let installedIdentifiers = Set(_signedApps.compactMap { $0.identifier })
		return _importedApps.filter { imported in
			guard let identifier = imported.identifier else { return false }
			return installedIdentifiers.contains(identifier)
		}.count
	}

	private func _cleanDuplicates() {
		UIImpactFeedbackGenerator(style: .medium).impactOccurred()
		_isCleaning = true

		let installedIdentifiers = Set(_signedApps.compactMap { $0.identifier })
		var removed = 0
		for imported in _importedApps {
			guard let identifier = imported.identifier else { continue }
			if installedIdentifiers.contains(identifier) {
				Storage.shared.deleteApp(for: imported)
				removed += 1
			}
		}

		_isCleaning = false
		_cleanedMessage = removed == 0
			? .localized("Nothing to clean up.")
			: .localized("Removed %lld imported duplicates.", arguments: removed)
		_refreshSizes()
	}

	private func _cleanSuperseded() {
		UIImpactFeedbackGenerator(style: .medium).impactOccurred()
		_isCleaning = true

		var newestByUUID: [String: Date] = [:]
		for app in _signedApps {
			guard let identifier = app.identifier else { continue }
			let date = app.date ?? .distantPast
			if date > (newestByUUID[identifier] ?? .distantPast) {
				newestByUUID[identifier] = date
			}
		}

		var removed = 0
		for app in _signedApps {
			guard let identifier = app.identifier else { continue }
			guard let newest = newestByUUID[identifier] else { continue }
			if (app.date ?? .distantPast) < newest {
				Storage.shared.deleteApp(for: app)
				removed += 1
			}
		}

		_isCleaning = false
		_cleanedMessage = removed == 0
			? .localized("Nothing to clean up.")
			: .localized("Removed %lld old copies.", arguments: removed)
		_refreshSizes()
	}

	private func _clearArchives() {
		UIImpactFeedbackGenerator(style: .medium).impactOccurred()
		try? FileManager.default.removeItem(at: FileManager.default.archives)
		try? FileManager.default.createDirectoryIfNeeded(at: FileManager.default.archives)
		_cleanedMessage = .localized("Archives cleared.")
		_refreshSizes()
	}
}
