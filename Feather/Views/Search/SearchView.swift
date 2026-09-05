//
//  SearchView.swift
//  Feather
//
//  Unified search across every source, App Store Search-tab style.
//

import SwiftUI
import CoreData
import AltSourceKit
import NukeUI
import NimbleViews

// MARK: - View
struct SearchView: View {
	@StateObject private var viewModel = SourcesViewModel.shared

	@FetchRequest(
		entity: AltSource.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \AltSource.name, ascending: true)],
		animation: .snappy
	) private var _sources: FetchedResults<AltSource>

	@State private var _query = ""
	@State private var _recentSearches: [String] = UserDefaults.standard.stringArray(forKey: "SignOs.recentSearches") ?? []
	@FocusState private var _searchFocused: Bool

	private var _allApps: [(source: AltSource, repository: ASRepository, app: ASRepository.App)] {
		var result: [(AltSource, ASRepository, ASRepository.App)] = []
		for source in _sources {
			guard let repository = viewModel.sources[source] else { continue }
			for app in repository.apps {
				result.append((source, repository, app))
			}
		}
		return result
	}

	private var _results: [(source: AltSource, repository: ASRepository, app: ASRepository.App)] {
		let trimmed = _query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return [] }
		return _allApps.filter { item in
			item.app.currentName.localizedCaseInsensitiveContains(trimmed)
				|| (item.app.developer?.localizedCaseInsensitiveContains(trimmed) ?? false)
		}
	}

	// MARK: Body
	var body: some View {
		NavigationStack {
			ScrollView {
				VStack(alignment: .leading, spacing: 22) {
					if _query.trimmingCharacters(in: .whitespaces).isEmpty {
						if !_recentSearches.isEmpty {
							_recentSection()
						}
						_browseSection()
					} else {
						_resultsSection()
					}
				}
				.padding(.horizontal, 16)
				.padding(.top, 4)
				.padding(.bottom, 28)
			}
			.background(Color(uiColor: .systemGroupedBackground))
			.navigationTitle("Search")
			.searchable(text: $_query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("Apps, developers"))
			.onSubmit(of: .search) { _rememberQuery() }
			.onChange(of: _query) { newValue in
				if newValue.trimmingCharacters(in: .whitespaces).isEmpty {
					// returning to the idle state keeps recents visible
				}
			}
		}
		.task(id: Array(_sources)) {
			await viewModel.fetchSources(_sources)
		}
	}
}

// MARK: - Sections
extension SearchView {
	@ViewBuilder
	private func _recentSection() -> some View {
		VStack(alignment: .leading, spacing: 12) {
			WSSectionTitle(title: "Recent Searches", actionTitle: "Clear") {
				_recentSearches.removeAll()
				UserDefaults.standard.set(_recentSearches, forKey: "SignOs.recentSearches")
			}

			FlowLayoutCompat(items: _recentSearches) { recent in
				Button {
					_query = recent
				} label: {
					Text(recent)
						.font(.subheadline.weight(.medium))
						.foregroundStyle(.primary)
						.padding(.horizontal, 14)
						.padding(.vertical, 9)
						.background(
							Capsule().fill(Color(uiColor: .secondarySystemGroupedBackground))
						)
				}
				.buttonStyle(.plain)
			}
		}
	}

	@ViewBuilder
	private func _browseSection() -> some View {
		VStack(alignment: .leading, spacing: 12) {
			WSSectionTitle(title: "Your Sources")

			if _sources.isEmpty {
				Text("Add a source in Discover to search it here.")
					.font(.subheadline)
					.foregroundStyle(.secondary)
			} else {
				VStack(spacing: 10) {
					ForEach(_sources) { source in
						NavigationLink {
							SourceAppsView(object: [source], viewModel: viewModel)
						} label: {
							HStack(spacing: 14) {
								WSAppIcon(url: source.iconURL, size: 44, cornerRadius: 10)

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
						.buttonStyle(.plain)
					}
				}
			}
		}
	}

	@ViewBuilder
	private func _resultsSection() -> some View {
		VStack(alignment: .leading, spacing: 12) {
			WSSectionTitle(
				title: "Results",
				actionTitle: _results.count == 1 ? nil : "\(_results.count) found"
			)

			if _results.isEmpty {
				Text("No apps match “\(_query)”.")
					.font(.subheadline)
					.foregroundStyle(.secondary)
					.padding(.vertical, 8)
			} else {
				VStack(spacing: 10) {
					ForEach(_results.prefix(60), id: \.app.currentUniqueId) { item in
						NavigationLink {
							SourceAppsDetailView(
								sourceURL: item.source.sourceURL,
								source: item.repository,
								app: item.app
							)
						} label: {
							HStack(spacing: 14) {
								WSAppIcon(url: item.app.iconURL, size: 57)

								VStack(alignment: .leading, spacing: 3) {
									Text(item.app.currentName)
										.font(.body.weight(.semibold))
										.foregroundStyle(.primary)
										.lineLimit(1)
									Text(verbatim: [
										item.app.currentVersion,
										item.source.name
									].compactMap { $0 }.joined(separator: " • "))
										.font(.caption)
										.foregroundStyle(.secondary)
										.lineLimit(1)
								}

								Spacer()

								DownloadButtonView(
									sourceURL: item.source.sourceURL,
									source: item.repository,
									app: item.app
								)
							}
							.padding(14)
							.background(
								RoundedRectangle(cornerRadius: 20, style: .continuous)
									.fill(Color(uiColor: .secondarySystemGroupedBackground))
							)
						}
						.buttonStyle(.plain)
					}
				}
			}
		}
	}
}

// MARK: - Helpers
extension SearchView {
	private func _appCount(_ source: AltSource) -> String {
		let count = viewModel.sources[source]?.apps.count ?? 0
		return count == 1 ? "1 app" : "\(count) apps"
	}

	private func _rememberQuery() {
		let trimmed = _query.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmed.isEmpty else { return }
		var recents = _recentSearches.filter { $0.caseInsensitiveCompare(trimmed) != .orderedSame }
		recents.insert(trimmed, at: 0)
		if recents.count > 8 {
			recents = Array(recents.prefix(8))
		}
		_recentSearches = recents
		UserDefaults.standard.set(recents, forKey: "SignOs.recentSearches")
	}
}

// MARK: - Simple wrapping chip layout (iOS 16 compatible)
struct FlowLayoutCompat<Item: Hashable, Content: View>: View {
	let items: [Item]
	let content: (Item) -> Content

	init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
		self.items = items
		self.content = content
	}

	var body: some View {
		LazyVGrid(
			columns: [GridItem(.adaptive(minimum: 120), spacing: 8)],
			alignment: .leading,
			spacing: 8
		) {
			ForEach(items, id: \.self) { item in
				content(item)
			}
		}
	}
}
