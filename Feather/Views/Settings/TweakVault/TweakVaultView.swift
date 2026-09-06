//
//  TweakVaultView.swift
//  Feather
//
//  Persistent library of your favorite tweaks, ready to inject
//  into any signing session.
//

import SwiftUI
import NimbleViews

// MARK: - View
struct TweakVaultView: View {
	@State private var _files: [URL] = []
	@State private var _isImporting = false

	static var vaultDirectory: URL {
		URL.documentsDirectory.appendingPathComponent("TweakVault", isDirectory: true)
	}

	static func vaultFiles() -> [URL] {
		let directory = vaultDirectory
		try? FileManager.default.createDirectoryIfNeeded(at: directory)
		return (try? FileManager.default.contentsOfDirectory(
			at: directory,
			includingPropertiesForKeys: [.fileSizeKey],
			options: .skipsHiddenFiles
		))?
		.sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending } ?? []
	}

	var body: some View {
		NBNavigationView(.localized("Tweak Vault")) {
			Group {
				if _files.isEmpty {
					emptyState
				} else {
					list
				}
			}
			.toolbar {
				NBToolbarButton(
					systemImage: "plus",
					style: .icon,
					placement: .topBarTrailing
				) {
					_isImporting = true
				}
			}
			.sheet(isPresented: $_isImporting) {
				FileImporterRepresentableView(
					allowedContentTypes: [.dylib, .deb],
					allowsMultipleSelection: true,
					onDocumentsPicked: { urls in
						guard !urls.isEmpty else { return }
						for url in urls {
							_store(url)
						}
						_files = Self.vaultFiles()
					}
				)
				.ignoresSafeArea()
			}
			.onAppear { _files = Self.vaultFiles() }
		}
		.navigationTitle(.localized("Tweak Vault"))
	}
}

// MARK: - Sections
extension TweakVaultView {
	private var list: some View {
		List {
			NBSection(.localized("Your Tweaks"), secondary: _files.count.description) {
				ForEach(_files, id: \.absoluteString) { file in
					HStack(spacing: 14) {
						Image(systemName: "puzzlepiece.extension.fill")
							.font(.body)
							.foregroundStyle(.tint)
							.frame(width: 30)

						VStack(alignment: .leading, spacing: 3) {
							Text(file.lastPathComponent)
								.font(.subheadline.weight(.semibold))
								.lineLimit(2)
							Text(verbatim: (try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize)
								.map { Int64($0).formattedByteCount } ?? "")
								.font(.caption2)
								.foregroundStyle(.tertiary)
						}

						Spacer()

						ShareLink(item: file) {
							Image(systemName: "square.and.arrow.up")
								.foregroundStyle(.secondary)
						}
						.buttonStyle(.plain)
					}
					.padding(.vertical, 2)
					.contextMenu {
						Button(role: .destructive) {
							try? FileManager.default.removeItem(at: file)
							_files = Self.vaultFiles()
						} label: {
							Label(.localized("Delete"), systemImage: "trash")
						}
					}
					.swipeActions(edge: .trailing, allowsFullSwipe: true) {
						Button(role: .destructive) {
							try? FileManager.default.removeItem(at: file)
							_files = Self.vaultFiles()
						} label: {
							Label(.localized("Delete"), systemImage: "trash")
						}
					}
				}
			} footer: {
				Text(.localized("Vault tweaks stay here permanently. When signing an app, add them in one tap from Signing → Tweaks."))
			}
		}
	}

	private var emptyState: some View {
		VStack(spacing: 10) {
			Image(systemName: "puzzlepiece.extension")
				.font(.system(size: 40))
				.foregroundStyle(.tint)
			Text("No Tweaks Saved")
				.font(.headline)
			Text("Import the .deb and .dylib tweaks you use most — they'll be one tap away every time you sign.")
				.font(.caption)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.padding(.horizontal, 32)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}

// MARK: - Actions
extension TweakVaultView {
	private func _store(_ url: URL) {
		let secured = url.startAccessingSecurityScopedResource()
		defer { if secured { url.stopAccessingSecurityScopedResource() } }

		let directory = Self.vaultDirectory
		try? FileManager.default.createDirectoryIfNeeded(at: directory)

		var destination = directory.appendingPathComponent(url.lastPathComponent)
		var counter = 1
		while FileManager.default.fileExists(atPath: destination.path) {
			let base = (url.lastPathComponent as NSString).deletingPathExtension
			let ext = (url.lastPathComponent as NSString).pathExtension
			destination = directory.appendingPathComponent("\(base) (\(counter)).\(ext)")
			counter += 1
		}

		try? FileManager.default.copyItem(at: url, to: destination)
	}
}
