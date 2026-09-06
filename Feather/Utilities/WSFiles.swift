//
//  WSFiles.swift
//  Feather
//
//  User-chosen import and export folders with security-scoped access.
//

import Foundation

enum WSFiles {
	// MARK: - Keys

	static let importBookmarkKey = "SignOs.importFolderBookmark"
	static let importNameKey = "SignOs.importFolderName"
	static let exportBookmarkKey = "SignOs.exportFolderBookmark"
	static let exportNameKey = "SignOs.exportFolderName"

	// MARK: - State

	static var hasImportFolder: Bool {
		UserDefaults.standard.data(forKey: importBookmarkKey) != nil
	}

	static var hasExportFolder: Bool {
		UserDefaults.standard.data(forKey: exportBookmarkKey) != nil
	}

	static var importFolderName: String {
		UserDefaults.standard.string(forKey: importNameKey) ?? "Last visited"
	}

	static var exportFolderName: String {
		UserDefaults.standard.string(forKey: exportNameKey) ?? "Documents/Archives"
	}

	// MARK: - Saving

	static func saveImportBookmark(for url: URL) {
		_save(url, key: importBookmarkKey, nameKey: importNameKey)
	}

	static func saveExportBookmark(for url: URL) {
		_save(url, key: exportBookmarkKey, nameKey: exportNameKey)
	}

	static func clearImportFolder() {
		UserDefaults.standard.removeObject(forKey: importBookmarkKey)
		UserDefaults.standard.removeObject(forKey: importNameKey)
	}

	static func clearExportFolder() {
		UserDefaults.standard.removeObject(forKey: exportBookmarkKey)
		UserDefaults.standard.removeObject(forKey: exportNameKey)
	}

	private static func _save(_ url: URL, key: String, nameKey: String) {
		let scoped = url.startAccessingSecurityScopedResource()
		let data = try? url.bookmarkData()
		if scoped { url.stopAccessingSecurityScopedResource() }
		UserDefaults.standard.set(data, forKey: key)
		UserDefaults.standard.set(url.lastPathComponent, forKey: nameKey)
	}

	// MARK: - Resolution

	/// Starting directory for file pickers (no security scope needed).
	static var importPickerDirectory: URL? {
		guard let data = UserDefaults.standard.data(forKey: importBookmarkKey) else { return nil }
		var stale = false
		return try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
	}

	/// Runs `body` with the export folder resolved and security scope active.
	/// Returns nil when no export folder is set (or it is no longer readable).
	static func withExportFolder<T>(_ body: (URL) throws -> T) -> T? {
		guard let data = UserDefaults.standard.data(forKey: exportBookmarkKey) else { return nil }
		var stale = false
		guard
			let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
		else {
			return nil
		}

		let scoped = url.startAccessingSecurityScopedResource()
		defer { if scoped { url.stopAccessingSecurityScopedResource() } }
		return try? body(url)
	}
}
