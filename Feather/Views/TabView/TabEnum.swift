//
//  TabEnum.swift
//  feather
//
//  Created by samara on 22.03.2025.
//

import SwiftUI
import NimbleViews

enum TabEnum: String, CaseIterable, Hashable {
	case discover
	case library
	case updates
	case settings
	case certificates

	var title: String {
		switch self {
		case .discover: 	return .localized("Discover")
		case .library: 		return .localized("Library")
		case .updates: 		return .localized("Updates")
		case .settings: 	return .localized("Settings")
		case .certificates:	return .localized("Certificates")
		}
	}

	var icon: String {
		switch self {
		case .discover: 	return "newspaper"
		case .library: 		return "square.stack.3d.up"
		case .updates: 		return "arrow.triangle.2.circlepath"
		case .settings: 	return "gearshape"
		case .certificates: return "person.text.rectangle"
		}
	}

	@ViewBuilder
	static func view(for tab: TabEnum) -> some View {
		switch tab {
		case .discover: SourcesView()
		case .library: LibraryView()
		case .updates: UpdatesView()
		case .settings: SettingsView()
		case .certificates: NBNavigationView(.localized("Certificates")) { CertificatesView() }
		}
	}

	static var defaultTabs: [TabEnum] {
		return [
			.discover,
			.library,
			.updates,
			.settings
		]
	}

	static var customizableTabs: [TabEnum] {
		return [
			.certificates
		]
	}
}
