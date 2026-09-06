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
						_cleanDuplicates()
					} label: {
						Label(.localized("Remove Imported Duplicates"), systemImage: "square.stack.3d.up.slash")
					}
					.disabled(_isCleaning || _duplicateCount == 0)

					Button {
						_clearArchives()
					} label: {
						Label(.localized("Clear Archives"), systemImage: "archivebox")
					}
					.disabled(_isCleaning || (_sizes[.archives] ?? 0) == 0)
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
}

// MARK: - Matching
extension StorageView {
	/// PPQ protection can change identifiers between signs, so group
	/// by display name first and fall back to the identifier.
	private func _matchKey(_ name: String?, _ identifier: String?) -> String? {
		if let name, !name.isEmpty { return "name:" + name.lowercased() }
		if let identifier, !identifier.isEmpty { return "id:" + identifier }
		return nil
	}
}

// MARK: - Counts
extension StorageView {
	private var _supersededCount: Int {
		_supersededVictims().count
	}

	private var _duplicateCount: Int {
		_duplicateVictims().count
	}

	private func _supersededVictims() -> [Signed] {
		var newestByKey: [String: Date] = [:]
		for app in _signedApps {
			guard let key = _matchKey(app.name, app.identifier) else { continue }
			let date = app.date ?? .distantPast
			if date > (newestByKey[key] ?? .distantPast) {
				newestByKey[key] = date
			}
		}

		return _signedApps.filter { app in
			guard let key = _matchKey(app.name, app.identifier) else { return false }
			guard let newest = newestByKey[key] else { return false }
			return (app.date ?? .distantPast) < newest
		}
	}

	private func _duplicateVictims() -> [Imported] {
		let installedNames = Set(_signedApps.compactMap { $0.name?.lowercased() })
		let installedIds = Set(_signedApps.compactMap { $0.identifier })

		return _importedApps.filter { imported in
			if let identifier = imported.identifier, installedIds.contains(identifier) { return true }
			if let name = imported.name?.lowercased(), installedNames.contains(name) { return true }
			return false
		}
	}
}

// MARK: - Actions
extension StorageView {
	private func _cleanSuperseded() {
		UIImpactFeedbackGenerator(style: .medium).impactOccurred()
		_isCleaning = true

		let victims = _supersededVictims()
		for victim in victims {
			Storage.shared.deleteApp(for: victim)
		}

		_isCleaning = false
		_cleanedMessage = victims.isEmpty
			? .localized("Nothing to clean up.")
			: .localized("Removed %lld old copies.", arguments: victims.count)
		_refreshSizes()
	}

	private func _cleanDuplicates() {
		UIImpactFeedbackGenerator(style: .medium).impactOccurred()
		_isCleaning = true

		let victims = _duplicateVictims()
		for victim in victims {
			Storage.shared.deleteApp(for: victim)
		}

		_isCleaning = false
		_cleanedMessage = victims.isEmpty
			? .localized("Nothing to clean up.")
			: .localized("Removed %lld imported duplicates.", arguments: victims.count)
		_refreshSizes()
	}

	private func _clearArchives() {
		UIImpactFeedbackGenerator(style: .medium).impactOccurred()
		try? FileManager.default.removeItem(at: FileManager.default.archives)
		try? FileManager.default.createDirectoryIfNeeded(at: FileManager.default.archives)
		_cleanedMessage = .localized("Archives cleared.")
		_refreshSizes()
	}

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
}
