//
//  AboutView.swift
//  Feather
//
//  Created by samara on 30.04.2025.
//

import SwiftUI
import NimbleViews
import NimbleJSON

// MARK: - Extension: Model
extension AboutView {
	struct CreditsModel: Codable, Hashable {
		let name: String?
		let desc: String?
		let github: String
	}
}

// MARK: - View
struct AboutView: View {
	@State private var _credits: [CreditsModel] = [
		.init(name: "claration", desc: "Feather Developer", github: "claration"),
		.init(name: "Asami", desc: "Feather Developer", github: "Nyasami"),
		.init(name: "Lakhan Lothiyi", desc: "AltStore Repositories", github: "llsc12"),
	]

	@State private var _handleCopied = false

	// MARK: Body
	var body: some View {
		NBList(.localized("About")) {
			Section {
				VStack(spacing: 10) {
					FRAppIconView(size: 96)

					Text(verbatim: "SignOs")
						.font(.largeTitle.weight(.bold))
						.foregroundStyle(Color.accentColor)

					HStack(spacing: 4) {
						Text(.localized("Version"))
						Text(Bundle.main.version)
					}
					.font(.footnote)
					.foregroundStyle(.secondary)
				}
			}
			.frame(maxWidth: .infinity)
			.listRowBackground(EmptyView())

			Section {
				Button {
					UIPasteboard.general.string = "@ihateios"
					UIImpactFeedbackGenerator(style: .light).impactOccurred()
					_handleCopied = true
					DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
						_handleCopied = false
					}
				} label: {
					HStack {
						Image(systemName: "signature")
							.font(.title3)
							.foregroundStyle(.tint)
							.frame(width: 45)

						NBTitleWithSubtitleView(
							title: "@ihateios",
							subtitle: _handleCopied
								? .localized("Copied to Clipboard")
								: .localized("Made By @ihateios — tap to copy")
						)

						Spacer()

						if _handleCopied {
							Image(systemName: "checkmark.circle.fill")
								.foregroundStyle(.green)
								.transition(.scale.combined(with: .opacity))
						}
					}
				}
				.animation(.smooth, value: _handleCopied)
			}

			NBSection(.localized("Credits")) {
				ForEach(_credits, id: \.github) { credit in
					_credit(name: credit.name, desc: credit.desc, github: credit.github)
				}
			} footer: {
				Text(.localized("Thank you to the Feather team — SignOs is built on their open-source work."))
			}
		}
	}
}

// MARK: - Extension: view
extension AboutView {
	@ViewBuilder
	private func _credit(
		name: String?,
		desc: String?,
		github: String
	) -> some View {
		Button {
			UIApplication.open("https://github.com/\(github)")
		} label: {
			HStack {
				FRIconCellView(
					title: name ?? github,
					subtitle: desc ?? "",
					iconUrl: URL(string: "https://github.com/\(github).png")!,
					size: 45,
					isCircle: true
				)

				Image(systemName: "arrow.up.right")
					.foregroundColor(.secondary.opacity(0.65))
			}
		}
	}
}
