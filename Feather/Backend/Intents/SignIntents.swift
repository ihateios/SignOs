//
//  SignIntents.swift
//  Feather
//
//  Shortcuts app integration.
//

import AppIntents
import Foundation

struct CheckUpdatesIntent: AppIntent {
	static var title: LocalizedStringResource = "Check for Updates"
	static var description = IntentDescription("Checks every source for app updates.")
	static var openAppWhenRun: Bool = false

	func perform() async throws -> some IntentResult & ProvidesDialog {
		let count = await AutoUpdateManager.shared.checkNow(notifyWhenClean: false)
		let text = count == 0
			? "All apps are up to date."
			: "\(count) updates found and prepared."
		return .result(dialog: IntentDialog(stringLiteral: text))
	}
}

struct InstallPendingUpdatesIntent: AppIntent {
	static var title: LocalizedStringResource = "Install Pending Updates"
	static var description = IntentDescription("Downloads and installs all pending app updates in the background.")
	static var openAppWhenRun: Bool = false

	func perform() async throws -> some IntentResult & ProvidesDialog {
		let started = await AutoUpdateManager.shared.downloadAllPendingUpdates()
		let text = started == 0
			? "No updates to install."
			: "Installing \(started) updates in the background."
		return .result(dialog: IntentDialog(stringLiteral: text))
	}
}
