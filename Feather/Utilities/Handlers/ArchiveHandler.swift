//
//  ArchiveHandler.swift
//  Feather
//
//  Created by samara on 22.04.2025.
//

import Foundation
import UIKit.UIApplication
import Zip
import SwiftUI
import IDeviceSwift

final class ArchiveHandler: NSObject {
	@ObservedObject var viewModel: InstallerStatusViewModel
	
	private let _fileManager = FileManager.default
	private let _uuid = UUID().uuidString
	private var _payloadUrl: URL?
	
	private var _app: AppInfoPresentable
	private let _uniqueWorkDir: URL
	
	init(app: AppInfoPresentable, viewModel: InstallerStatusViewModel) {
		self.viewModel = viewModel
		self._app = app
		self._uniqueWorkDir = _fileManager.temporaryDirectory
			.appendingPathComponent("FeatherInstall_\(_uuid)", isDirectory: true)
		
		super.init()
	}
	
	func move() async throws {
		guard let appUrl = Storage.shared.getAppDirectory(for: _app) else {
			throw SigningFileHandlerError.appNotFound
		}
		
		let payloadUrl = _uniqueWorkDir.appendingPathComponent("Payload")
		let movedAppURL = payloadUrl.appendingPathComponent(appUrl.lastPathComponent)

		try _fileManager.createDirectoryIfNeeded(at: payloadUrl)
		
		try _fileManager.copyItem(at: appUrl, to: movedAppURL)
		_payloadUrl = payloadUrl
	}
	
	func archive() async throws -> URL {
		return try await Task.detached(priority: .background) { [self] in
			guard let payloadUrl = await self._payloadUrl else {
				throw SigningFileHandlerError.appNotFound
			}
			
			let zipUrl = self._uniqueWorkDir.appendingPathComponent("Archive.zip")
			let ipaUrl = self._uniqueWorkDir.appendingPathComponent("Archive.ipa")
			
			try await Zip.zipFiles(
				paths: [payloadUrl],
				zipFilePath: zipUrl,
				password: nil,
				compression: ZipCompression.allCases[ArchiveHandler.getCompressionLevel()],
				progress: { progress in
					Task { @MainActor in
						self.viewModel.packageProgress = progress
					}
				})
			
			try FileManager.default.moveItem(at: zipUrl, to: ipaUrl)
			return ipaUrl
		}.value
	}
	
	func moveToArchive(_ package: URL, shouldOpen: Bool = false) async throws -> URL? {
		let appendingString = "\(_app.name!)_\(_app.version!)_\(Int(Date().timeIntervalSince1970)).ipa"
		var dest = _fileManager.archives.appendingPathComponent(appendingString)
		var usedCustomFolder = false

		// Prefer the user's chosen import/export folder when set.
		if let custom = WSFiles.withCustomFolder({ folder -> URL in
			let target = folder.appendingPathComponent(appendingString)
			try? _fileManager.removeItem(at: target)
			try _fileManager.moveItem(at: package, to: target)
			return target
		}) {
			dest = custom
			usedCustomFolder = true
		} else {
			try? _fileManager.removeItem(at: dest)
			try _fileManager.moveItem(at: package, to: dest)
		}
		
		if shouldOpen {
			let openURL = usedCustomFolder ? dest : FileManager.default.archives.toSharedDocumentsURL()!
			await MainActor.run {
				UIApplication.open(openURL)
			}
		}
		
		return dest
	}
	
	/// Background operations (automatic updates/installs) force the
	/// fastest compression so packaging never delays the install.
	static var fastestCompressionOverride: Bool = false

	static func getCompressionLevel() -> Int {
		if fastestCompressionOverride {
			return 0
		}
		return UserDefaults.standard.integer(forKey: "Feather.compressionLevel")
	}
}
