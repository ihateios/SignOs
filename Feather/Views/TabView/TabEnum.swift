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
	case search
	case library
	case updates
	case settings
	case certificates

	var title: String {
		switch self {
		case .discover: 	return .localized("Discover")
		case .search: 		return .localized("Search")
		case .library: 		return .localized("Library")
		case .updates: 		return .localized("Updates")
		case .settings: 	return .localized("Settings")
		case .certificates:	return .localized("Certificates")
		}
	}

	var icon: String {
		switch self {
		case .discover: 	return "newspaper.fill"
		case .search: 		return "magnifyingglass"
		case .library: 		return "square.stack.3d.up.fill"
		case .updates: 		return "arrow.triangle.2.circlepath"
		case .settings: 	return "gearshape.fill"
		case .certificates: return "person.text.rectangle"
		}
	}

	@ViewBuilder
	static func view(for tab: TabEnum) -> some View {
		switch tab {
		case .discover: DiscoverView()
		case .search: SearchView()
		case .library: LibraryView()
		case .updates: UpdatesView()
		case .settings: SettingsView()
		case .certificates: NBNavigationView(.localized("Certificates")) { CertificatesView() }
		}
	}

	static var defaultTabs: [TabEnum] {
		return [
			.discover,
			.search,
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
