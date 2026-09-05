//
//  ActivityLog.swift
//  Feather
//
//  Persistent timeline of everything SignOs does automatically.
//

import Foundation
import Combine

// MARK: - Model
struct ActivityEntry: Codable, Identifiable, Equatable {
	enum Kind: String, Codable {
		case checked
		case downloaded
		case installed
		case updated
		case renewed
		case failed

		var title: String {
			switch self {
			case .checked: return "Checked for Updates"
			case .downloaded: return "Downloaded"
			case .installed: return "Installed"
			case .updated: return "Updated"
			case .renewed: return "Renewed"
			case .failed: return "Failed"
			}
		}

		var symbol: String {
			switch self {
			case .checked: return "arrow.triangle.2.circlepath"
			case .downloaded: return "arrow.down.circle.fill"
			case .installed: return "app.badge.checkmark"
			case .updated: return "arrow.up.circle.fill"
			case .renewed: return "checkmark.seal.fill"
			case .failed: return "exclamationmark.triangle.fill"
			}
		}
	}

	var id: Date { date }
	let date: Date
	let kind: Kind
	let app: String
	let detail: String?
}

// MARK: - Log
@MainActor
final class ActivityLog: ObservableObject {
	static let shared = ActivityLog()

	@Published private(set) var entries: [ActivityEntry] = []

	private let _key = "SignOs.activityLog"
	private let _maxEntries = 200

	private init() {
		if
			let data = UserDefaults.standard.data(forKey: _key),
			let decoded = try? JSONDecoder().decode([ActivityEntry].self, from: data)
		{
			entries = decoded
		}
	}

	func log(_ kind: ActivityEntry.Kind, app: String, detail: String? = nil) {
		let entry = ActivityEntry(date: Date(), kind: kind, app: app, detail: detail)
		entries.insert(entry, at: 0)
		if entries.count > _maxEntries {
			entries = Array(entries.prefix(_maxEntries))
		}
		persist()
	}

	private func persist() {
		if let data = try? JSONEncoder().encode(entries) {
			UserDefaults.standard.set(data, forKey: _key)
		}
	}
}
