//
//  WSTheme.swift
//  Feather
//
//  Centralized design tokens. Every visual decision routes through
//  this file so the entire product stays coherent as it grows.
//

import SwiftUI

// MARK: - Spacing

enum WSSpacing {
	static let xs: CGFloat = 4
	static let sm: CGFloat = 8
	static let md: CGFloat = 12
	static let lg: CGFloat = 16
	static let xl: CGFloat = 20
	static let xxl: CGFloat = 28
	static let sectionGap: CGFloat = 30
	static let cardPadding: CGFloat = 14
	static let screenPadding: CGFloat = 16
}

// MARK: - Corner Radii

enum WSRadius {
	static let sm: CGFloat = 10
	static let md: CGFloat = 14
	static let lg: CGFloat = 20
	static let xl: CGFloat = 24
	static let capsule: CGFloat = 999

	static func continuous(_ r: CGFloat) -> RoundedRectangle {
		RoundedRectangle(cornerRadius: r, style: .continuous)
	}
}

// MARK: - Typography

enum WSType {
	static let heroTitle = Font.system(size: 34, weight: .bold)
	static let sectionTitle = Font.title2.weight(.bold)
	static let cardTitle = Font.headline
	static let cardSubtitle = Font.caption
	static let body = Font.subheadline
	static let micro = Font.caption2
	static let eyebrow = Font.footnote.weight(.bold)
}

// MARK: - Surfaces

enum WSSurface {
	static let background = Color(uiColor: .systemGroupedBackground)
	static let card = Color(uiColor: .secondarySystemGroupedBackground)
	static let cardFaded = Color(uiColor: .secondarySystemGroupedBackground).opacity(0.6)
	static let input = Color(uiColor: .tertiarySystemFill)
}

// MARK: - Semantic Colors

enum WSSemantic {
	static let success = Color.green
	static let warning = Color.orange
	static let error = Color.red
	static let info = Color.blue
}

// MARK: - Empty State (unified across the app)

struct WSEmptyState: View {
	let icon: String
	let title: String
	let message: String

	var body: some View {
		VStack(spacing: WSSpacing.sm + 2) {
			Image(systemName: icon)
				.font(.system(size: 38))
				.foregroundStyle(.tint)
				.accessibilityHidden(true)

			Text(title)
				.font(.headline)

			Text(message)
				.font(.caption)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.padding(.horizontal, WSSpacing.xl)
		}
		.frame(maxWidth: .infinity)
		.padding(.vertical, WSSpacing.xxl)
		.padding(.horizontal, WSSpacing.lg)
		.background(
			WSRadius.continuous(WSRadius.xl)
				.fill(WSSurface.cardFaded)
		)
	}
}

// MARK: - Section Header

