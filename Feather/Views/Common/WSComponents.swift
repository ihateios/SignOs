//
//  WSComponents.swift
//  Feather
//
//  App Store-grade shared design components.
//

import SwiftUI

// MARK: - Action Button (App Store "GET" style)

struct WSActionButton: View {
	enum Style {
		case capsule
		case prominent
		case quiet
	}

	let title: String
	var systemImage: String? = nil
	var style: Style = .capsule
	var isDisabled: Bool = false
	let action: () -> Void

	@State private var _isPressed = false

	private var _label: some View {
		HStack(spacing: 4) {
			if let systemImage {
				Image(systemName: systemImage)
					.font(.caption2.weight(.bold))
			}
			Text(title)
				.font(.caption.weight(.bold))
				.textCase(.uppercase)
				.lineLimit(1)
		}
	}

	var body: some View {
		Button {
			UIImpactFeedbackGenerator(style: .light).impactOccurred()
			action()
		} label: {
			_label
				.foregroundStyle(_foreground)
				.padding(.horizontal, 14)
				.frame(minWidth: 68, minHeight: 30)
		}
		.buttonStyle(.plain)
		.background(_background)
		.clipShape(Capsule())
		.opacity(isDisabled ? 0.4 : 1.0)
		.scaleEffect(_isPressed ? 0.94 : 1.0)
		.animation(.spring(response: 0.3, dampingFraction: 0.7), value: _isPressed)
		.onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
			_isPressed = pressing
		}, perform: {})
		.disabled(isDisabled)
	}

	private var _foreground: Color {
		switch style {
		case .capsule: return .accentColor
		case .prominent: return .white
		case .quiet: return .secondary
		}
	}

	@ViewBuilder
	private var _background: some View {
		if #available(iOS 26.0, *) {
			switch style {
			case .capsule:
				Color.clear
					.glassEffect(.regular.interactive(), in: Capsule())
			case .prominent:
				Capsule().fill(.tint)
			case .quiet:
				Capsule().fill(.clear)
			}
		} else {
			switch style {
			case .capsule:
				Capsule().fill(Color(uiColor: .secondarySystemFill))
			case .prominent:
				Capsule().fill(.tint)
			case .quiet:
				Capsule().fill(.clear)
			}
		}
	}
}

// MARK: - Section Header (uppercase App Store style)

struct WSSectionHeader: View {
	let title: String
	var trailing: String? = nil

	var body: some View {
		HStack(alignment: .firstTextBaseline) {
			Text(title)
				.font(.footnote.weight(.semibold))
				.textCase(.uppercase)
				.foregroundStyle(.secondary)
				.kerning(0.4)
			Spacer()
			if let trailing {
				Text(trailing)
					.font(.footnote.weight(.semibold))
					.textCase(.uppercase)
					.foregroundStyle(.tertiary)
					.kerning(0.4)
			}
		}
	}
}

// MARK: - Progress Pill (used for active download / install rows)

struct WSProgressBadge: View {
	let progress: Double

	var body: some View {
		ZStack {
			Circle()
				.stroke(Color(uiColor: .tertiarySystemFill), lineWidth: 3)
			Circle()
				.trim(from: 0, to: max(0.001, min(progress, 1.0)))
				.stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
				.rotationEffect(.degrees(-90))
				.animation(.smooth, value: progress)

			if progress >= 1.0 {
				Image(systemName: "checkmark")
					.font(.system(size: 9, weight: .bold))
					.foregroundStyle(Color.accentColor)
			} else {
				Circle()
					.fill(Color.accentColor)
					.frame(width: 6, height: 6)
			}
		}
		.frame(width: 22, height: 22)
	}
}

// MARK: - Glass modifier (Liquid Glass on iOS 26, material fallback)

extension View {
	@ViewBuilder
	func wsGlassCard(cornerRadius: CGFloat = 18, padding: CGFloat = 14) -> some View {
		self
			.padding(padding)
			.background {
				if #available(iOS 26.0, *) {
					Color.clear
						.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
				} else {
					RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
						.fill(Color(uiColor: .secondarySystemGroupedBackground))
				}
			}
	}
}

// MARK: - Download speed sampler

final class WSSpeedometer {
	private var lastBytes: Int64 = 0
	private var lastDate = Date()
	public private(set) var speed: Double = 0

	func sample(_ bytes: Int64) -> Double {
		let now = Date()
		let elapsed = now.timeIntervalSince(lastDate)
		if elapsed >= 0.5, bytes > lastBytes {
			speed = Double(bytes - lastBytes) / elapsed
			lastBytes = bytes
			lastDate = now
		}
		return speed
	}
}

extension Double {
	var formattedSpeed: String {
		guard self > 0 else { return "" }
		return ByteCountFormatter.string(fromByteCount: Int64(self), countStyle: .file) + "/s"
	}

	var formattedEta: String {
		guard self.isFinite, self > 0 else { return "" }
		let seconds = Int(self)
		if seconds < 60 { return "\(seconds)s left" }
		return "\(seconds / 60)m \(seconds % 60)s left"
	}
}
