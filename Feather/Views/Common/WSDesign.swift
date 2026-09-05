//
//  WSDesign.swift
//  Feather
//
//  SignOs design system: App Store-grade shared layout components.
//

import SwiftUI
import NukeUI

// MARK: - Hero Header (App Store "Today" style)

struct WSHeroHeader: View {
	let eyebrow: String
	let title: String

	var body: some View {
		VStack(alignment: .leading, spacing: 0) {
			Text(eyebrow)
				.font(.footnote.weight(.bold))
				.textCase(.uppercase)
				.foregroundStyle(.tint)
				.kerning(0.8)
			Text(title)
				.font(.system(size: 34, weight: .bold, design: .default))
				.foregroundStyle(.primary)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}

// MARK: - Section Title with trailing action

struct WSSectionTitle: View {
	let title: String
	var actionTitle: String? = nil
	var action: (() -> Void)? = nil

	var body: some View {
		HStack(alignment: .firstTextBaseline) {
			Text(title)
				.font(.title2.weight(.bold))
				.foregroundStyle(.primary)
			Spacer()
			if let actionTitle, let action {
				Button {
					UIImpactFeedbackGenerator(style: .light).impactOccurred()
					action()
				} label: {
					Text(actionTitle)
						.font(.subheadline.weight(.semibold))
						.foregroundStyle(.tint)
				}
				.buttonStyle(.plain)
			}
		}
	}
}

// MARK: - Card container

struct WSCard<Content: View>: View {
	var cornerRadius: CGFloat = 20
	@ViewBuilder var content: Content

	init(cornerRadius: CGFloat = 20, @ViewBuilder content: () -> Content) {
		self.cornerRadius = cornerRadius
		self.content = content()
	}

	var body: some View {
		content
			.padding(16)
			.frame(maxWidth: .infinity, alignment: .leading)
			.background(
				RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
					.fill(Color(uiColor: .secondarySystemGroupedBackground))
			)
	}
}

// MARK: - App icon tile from URL

struct WSAppIcon: View {
	let url: URL?
	var size: CGFloat = 60
	var cornerRadius: CGFloat = 13.5

	var body: some View {
		Group {
			if let url {
				LazyImage(url: url) { state in
					if let image = state.image {
						image
							.resizable()
							.scaledToFill()
					} else {
						placeholder
					}
				}
			} else {
				placeholder
			}
		}
		.frame(width: size, height: size)
		.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
		.overlay(
			RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
				.strokeBorder(.black.opacity(0.06), lineWidth: 0.5)
		)
	}

	private var placeholder: some View {
		ZStack {
			Rectangle()
				.fill(Color(uiColor: .tertiarySystemFill))
			Image(systemName: "app.fill")
				.font(.system(size: size * 0.38, weight: .medium))
				.foregroundStyle(.secondary)
		}
	}
}

// MARK: - Status capsule (Apple "GET" pill)

struct WSCapsuleLabel: View {
	let title: String
	var filled: Bool = false

	var body: some View {
		Text(title)
			.font(.caption.weight(.bold))
			.textCase(.uppercase)
			.foregroundStyle(filled ? Color.white : Color.accentColor)
			.padding(.horizontal, 18)
			.frame(minWidth: 76, minHeight: 32)
			.background(
				Capsule().fill(filled ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(uiColor: .secondarySystemFill)))
			)
	}
}
