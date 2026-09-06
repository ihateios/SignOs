//
//  WSFiles.swift
//  Feather
//
//  User-chosen import/export folder with security-scoped access.
//

import Foundation

enum WSFiles {
	static let bookmarkKey = "SignOs.importExportFolderBookmark"
	static let nameKey = "SignOs.importExportFolderName"

	static var hasCustomFolder: Bool {
		UserDefaults.standard.data(forKey: bookmarkKey) != nil
	}

	static var folderName: String {
		UserDefaults.standard.string(forKey: nameKey) ?? "Documents/Archives"
	}

	static func saveBookmark(for url: URL) {
		let scoped = url.startAccessingSecurityScopedResource()
		let data = try? url.bookmarkData()
		if scoped { url.stopAccessingSecurityScopedResource() }
		UserDefaults.standard.set(data, forKey: bookmarkKey)
		UserDefaults.standard.set(url.lastPathComponent, forKey: nameKey)
	}

	static func clearBookmark() {
		UserDefaults.standard.removeObject(forKey: bookmarkKey)
		UserDefaults.standard.removeObject(forKey: nameKey)
	}

	/// Resolves the picker's starting directory (no security scope needed).
	static var pickerDirectory: URL? {
		guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
		var stale = false
		return try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
	}

	/// Runs `body` with the custom folder resolved and security scope active.
	/// Returns nil when no custom folder is set (or it is no longer readable).
	static func withCustomFolder<T>(_ body: (URL) throws -> T) -> T? {
		guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
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
