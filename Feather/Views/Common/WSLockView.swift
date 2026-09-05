//
//  WSLockView.swift
//  Feather
//
//  Biometric lock screen.
//

import SwiftUI
import LocalAuthentication

struct WSLockView: View {
	let onUnlock: () -> Void

	@State private var _isAuthenticating = false

	var body: some View {
		ZStack {
			Color(uiColor: .systemBackground)
				.ignoresSafeArea()

			VStack(spacing: 18) {
				Image(systemName: "lock.shield.fill")
					.font(.system(size: 56, weight: .light))
					.foregroundStyle(.tint)

				Text("SignOs Locked")
					.font(.title2.weight(.bold))

				Text("Unlock to continue.")
					.font(.subheadline)
					.foregroundStyle(.secondary)

				Button {
					_authenticate()
				} label: {
					HStack(spacing: 8) {
						Image(systemName: "faceid")
						Text("Unlock")
							.font(.headline)
					}
					.foregroundStyle(.white)
					.padding(.horizontal, 32)
					.frame(minHeight: 50)
					.background(
						RoundedRectangle(cornerRadius: 16, style: .continuous)
							.fill(.tint)
					)
				}
				.buttonStyle(.plain)
				.padding(.top, 8)
				.disabled(_isAuthenticating)
			}
			.padding(32)
		}
		.onAppear { _authenticate() }
	}

	private func _authenticate() {
		guard !_isAuthenticating else { return }

		let context = LAContext()
		var error: NSError?
		guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return }

		_isAuthenticating = true
		context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock SignOs") { success, _ in
			DispatchQueue.main.async {
				_isAuthenticating = false
				if success {
					onUnlock()
				}
			}
		}
	}
}
