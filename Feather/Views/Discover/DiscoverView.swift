//
//  DiscoverView.swift
//  Feather
//
//  App Store "Today"-style discover surface, built from scratch.
//

import SwiftUI
import CoreData
import AltSourceKit
import NukeUI
import NimbleViews

// MARK: - View
struct DiscoverView: View {
	@StateObject private var viewModel = SourcesViewModel.shared
	@State private var _isAddingPresenting = false

	@FetchRequest(
		entity: AltSource.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
		animation: .snappy
	) private var _sources: FetchedResults<AltSource>

	private var _hasContent: Bool {
		!_sources.isEmpty && viewModel.sources.values.contains { !$0.apps.isEmpty }
	}

	private var _featured: [(source: AltSource, repository: ASRepository, app: ASRepository.App)] {
		var result: [(AltSource, ASRepository, ASRepository.App)] = []
		for source in _sources {
			guard let repository = viewModel.sources[source] else { continue }
			for app in repository.apps.prefix(3) {
				guard result.count < 8 else { break }
				result.append((source, repository, app))
			}
			if result.count >= 8 { break }
		}
		return result
	}

	// MARK: Body
	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 30) {
					WSHeroHeader(
						eyebrow: Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()),
						title: "Discover"
					)

					if !_featured.isEmpty {
						_featuredSection()
					}

					_sourcesSection()

					if _sources.isEmpty {
						_emptyCard()
					} else {
						_addCard()
					}
				}
				.padding(.horizontal, 16)
				.padding(.top, 4)
				.padding(.bottom, 28)
			}
			.background(Color(uiColor: .systemGroupedBackground))
			.toolbar(.hidden, for: .navigationBar)
			.refreshable {
				await viewModel.fetchSources(_sources, refresh: true)
			}
			.sheet(isPresented: $_isAddingPresenting) {
				SourcesAddView()
			}
		}
		.task(id: Array(_sources)) {
			await viewModel.fetchSources(_sources)
		}
	}
}

// MARK: - Sections
extension DiscoverView {
	@ViewBuilder
	private func _featuredSection() -> some View {
		VStack(alignment: .leading, spacing: 12) {
			WSSectionTitle(title: "Featured")

			ScrollView(.horizontal, showsIndicators: false) {
				HStack(alignment: .top, spacing: 14) {
					ForEach(_featured, id: \.app.currentUniqueId) { item in
						NavigationLink {
							SourceAppsDetailView(
								sourceURL: item.source.sourceURL,
								source: item.repository,
								app: item.app
							)
						} label: {
							_featuredCard(item)
						}
						.buttonStyle(.plain)
					}
				}
				}
		}
	}

	private func _featuredCard(
		_ item: (source: AltSource, repository: ASRepository, app: ASRepository.App)
	) -> some View {
		VStack(alignment: .leading, spacing: 10) {
			WSAppIcon(url: item.app.iconURL, size: 60)

			Text(item.app.currentName)
				.font(.headline)
				.lineLimit(2)
				.multilineTextAlignment(.leading)
				.foregroundStyle(.primary)

			Text(verbatim: [
				item.app.currentVersion,
				item.source.name
			].compactMap { $0 }.joined(separator: " • "))
				.font(.caption)
				.foregroundStyle(.secondary)
				.lineLimit(1)

			DownloadButtonView(
				sourceURL: item.source.sourceURL,
				source: item.repository,
				app: item.app
			)
		}
		.frame(width: 168, alignment: .leading)
		.padding(14)
		.background(
			RoundedRectangle(cornerRadius: 20, style: .continuous)
				.fill(Color(uiColor: .secondarySystemGroupedBackground))
		)
		.foregroundStyle(.primary)
	}

	@ViewBuilder
	private func _sourcesSection() -> some View {
		VStack(alignment: .leading, spacing: 12) {
			WSSectionTitle(title: "Your Sources")

			if _sources.isEmpty {
				Text("Add a repository to start installing apps.")
					.font(.subheadline)
					.foregroundStyle(.secondary)
			} else {
				VStack(spacing: 10) {
					NavigationLink {
						SourceAppsView(object: Array(_sources), viewModel: viewModel)
					} label: {
						_allAppsCard()
					}
					.buttonStyle(.plain)

					ForEach(_sources) { source in
						NavigationLink {
							SourceAppsView(object: [source], viewModel: viewModel)
						} label: {
							_sourceCard(source)
						}
						.buttonStyle(.plain)
					}
				}
			}
		}
	}

	private func _allAppsCard() -> some View {
		HStack(spacing: 14) {
			Image(systemName: "square.grid.2x2.fill")
				.font(.system(size: 22, weight: .medium))
				.foregroundStyle(.white)
				.frame(width: 48, height: 48)
				.background(
					RoundedRectangle(cornerRadius: 11, style: .continuous)
						.fill(Color.accentColor)
				)

			NBTitleWithSubtitleView(
				title: "Browse All Apps",
				subtitle: "Everything from every source"
			)

			Spacer()

			Image(systemName: "chevron.forward")
				.font(.footnote.weight(.semibold))
				.foregroundStyle(.tertiary)
		}
		.padding(14)
		.background(
			RoundedRectangle(cornerRadius: 20, style: .continuous)
				.fill(Color(uiColor: .secondarySystemGroupedBackground))
		)
	}

	private func _sourceCard(_ source: AltSource) -> some View {
		HStack(spacing: 14) {
			WSAppIcon(url: source.iconURL, size: 48, cornerRadius: 11)

			VStack(alignment: .leading, spacing: 2) {
				Text(source.name ?? "Source")
					.font(.body.weight(.semibold))
					.foregroundStyle(.primary)
					.lineLimit(1)
				Text(verbatim: _appCount(source))
					.font(.caption)
					.foregroundStyle(.secondary)
			}

			Spacer()

			Image(systemName: "chevron.forward")
				.font(.footnote.weight(.semibold))
				.foregroundStyle(.tertiary)
		}
		.padding(14)
		.background(
			RoundedRectangle(cornerRadius: 20, style: .continuous)
				.fill(Color(uiColor: .secondarySystemGroupedBackground))
		)
	}

	private func _emptyCard() -> some View {
		Button {
			_isAddingPresenting = true
		} label: {
			VStack(spacing: 12) {
				Image(systemName: "plus")
					.font(.system(size: 26, weight: .medium))
					.foregroundStyle(.tint)
				Text("Add Your First Source")
					.font(.headline)
					.foregroundStyle(.primary)
				Text("Repositories are where apps come from.")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			.frame(maxWidth: .infinity)
			.padding(.vertical, 40)
			.background(
				RoundedRectangle(cornerRadius: 20, style: .continuous)
					.fill(Color(uiColor: .secondarySystemGroupedBackground))
					.overlay(
						RoundedRectangle(cornerRadius: 20, style: .continuous)
							.strokeBorder(
								Color(uiColor: .separator).opacity(0.5),
								style: StrokeStyle(lineWidth: 1.5, dash: [7])
							)
					)
			)
		}
		.buttonStyle(.plain)
	}

	private func _addCard() -> some View {
		Button {
			_isAddingPresenting = true
		} label: {
			HStack(spacing: 10) {
				Image(systemName: "plus.circle.fill")
					.font(.title3)
					.foregroundStyle(.tint)
				Text("Add Source")
					.font(.body.weight(.semibold))
					.foregroundStyle(.tint)
				Spacer()
			}
			.padding(16)
			.background(
				RoundedRectangle(cornerRadius: 20, style: .continuous)
					.fill(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.6))
					.overlay(
						RoundedRectangle(cornerRadius: 20, style: .continuous)
							.strokeBorder(
								Color(uiColor: .separator).opacity(0.4),
								style: StrokeStyle(lineWidth: 1.2, dash: [6])
							)
					)
			)
		}
		.buttonStyle(.plain)
	}
}

// MARK: - Helpers
extension DiscoverView {
	private func _appCount(_ source: AltSource) -> String {
		let count = viewModel.sources[source]?.apps.count ?? 0
		return count == 1 ? "1 app" : "\(count) apps"
	}

}

