//
//  DownloadHeaderView.swift
//  Feather
//
//  Created by samara on 16.05.2025.
//

import SwiftUI
import Combine
import NimbleExtensions

struct DownloadHeaderView: View {
	@ObservedObject var downloadManager: DownloadManager

	var body: some View {
		ZStack {
			if !downloadManager.manualDownloads.isEmpty {
				VStack {
					VStack(spacing: 12) {
						if let firstDownload = downloadManager.manualDownloads.first {
							DownloadItemView(download: firstDownload)

							if downloadManager.manualDownloads.count > 1 {
								HStack {
									Spacer()
									Text(verbatim: "+\(downloadManager.manualDownloads.count - 1)")
										.font(.caption.weight(.semibold))
										.foregroundStyle(.secondary)
								}
							}
						}
					}
					.padding(.horizontal, 16)
					.padding(.vertical, 6)
				}
				.background {
					ZStack {
						RoundedRectangle(cornerRadius: 22, style: .continuous)
							.fill(.regularMaterial)
						RoundedRectangle(cornerRadius: 22, style: .continuous)
							.strokeBorder(.quaternary, lineWidth: 0.5)
					}
				}
				.padding(.horizontal, 12)
				.transition(.move(edge: .top).combined(with: .opacity))
			}
		}
		.animation(.spring(), value: downloadManager.manualDownloads.count)
	}
}

struct DownloadItemView: View {
	let download: Download
	@State private var progress: Double = 0
	@State private var bytesDownloaded: Int64 = 0
	@State private var totalBytes: Int64 = 0
	@State private var unpackageProgress: Double = 0
	@State private var _speedometer = WSSpeedometer()
	@State private var _speedText = ""
	@State private var _etaText = ""

	var body: some View {
		VStack(alignment: .leading, spacing: 6) {
			HStack(spacing: 10) {
				Image(systemName: "arrow.down.circle.fill")
					.font(.title3)
					.foregroundStyle(.tint)
					.symbolRenderingMode(.hierarchical)

				Text(download.fileName)
					.font(.footnote.weight(.semibold))
					.lineLimit(1)

				Spacer()

				Text(verbatim: "\(Int(overallProgress * 100))%")
					.font(.caption.weight(.semibold).monospacedDigit())
					.foregroundStyle(.secondary)
					.contentTransition(.numericText())
			}

			ProgressView(value: overallProgress)
				.progressViewStyle(.linear)
				.tint(.accentColor)

			HStack(spacing: 6) {
				if totalBytes > 0 {
					Text(verbatim: "\(bytesDownloaded.formattedByteCount) of \(totalBytes.formattedByteCount)")
				}
				if !_speedText.isEmpty {
					Text(verbatim: "• \(_speedText)")
				}
				if !_etaText.isEmpty {
					Text(verbatim: "• \(_etaText)")
				}
			}
			.font(.caption2)
			.foregroundStyle(.tertiary)
		}
		.onReceive(download.$progress) { self.progress = $0 }
		.onReceive(download.$bytesDownloaded) {
			self.bytesDownloaded = $0
			let speed = _speedometer.sample($0)
			_speedText = speed.formattedSpeed
			if speed > 0, totalBytes > $0 {
				_etaText = (Double(totalBytes - $0) / speed).formattedEta
			} else {
				_etaText = ""
			}
		}
		.onReceive(download.$totalBytes) { self.totalBytes = $0 }
		.onReceive(download.$unpackageProgress) { self.unpackageProgress = $0 }
	}

	private var overallProgress: Double {
		download.onlyArchiving
			? unpackageProgress
			: (0.3 * unpackageProgress) + (0.7 * progress)
	}
}
