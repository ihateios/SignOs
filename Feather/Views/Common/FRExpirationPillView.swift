//
//  FRExpirationPillView.swift
//  Feather
//
//  Created by samara on 7.05.2025.
//

import SwiftUI

// MARK: - View
struct FRExpirationPillView: View {
	let title: String
	let revoked: Bool
	let expiration: Date.ExpirationInfo?

	var body: some View {
		let textLabel = revoked
			? .localized("Revoked")
			: expiration?.formatted ?? title

		let hasWarning = revoked || expiration != nil

		Text(textLabel)
			.lineLimit(1)
			.font(.caption.weight(.bold))
			.textCase(hasWarning ? nil : .uppercase)
			.foregroundStyle(_foreground(hasWarning))
			.padding(.horizontal, 12)
			.frame(minHeight: 30)
			.background(_background(hasWarning))
			.clipShape(Capsule())
	}

	private func _foreground(_ hasWarning: Bool) -> Color {
		guard hasWarning else { return .accentColor }
		return revoked ? .white : (expiration?.color ?? .white)
	}

	@ViewBuilder
	private func _background(_ hasWarning: Bool) -> some View {
		if hasWarning {
			Capsule().fill(expiration?.color.opacity(0.85) ?? .red)
		} else if #available(iOS 26.0, *) {
			Color.clear.glassEffect(.regular.interactive(), in: Capsule())
		} else {
			Capsule().fill(Color(uiColor: .secondarySystemFill))
		}
	}
}
