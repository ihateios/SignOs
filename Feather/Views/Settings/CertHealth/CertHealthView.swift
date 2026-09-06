//
//  CertHealthView.swift
//  Feather
//
//  Certificate health dashboard: expiry rings, app counts, renew-all.
//

import SwiftUI
import CoreData
import NimbleViews

// MARK: - View
struct CertHealthView: View {
	@FetchRequest(
		entity: CertificatePair.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \CertificatePair.date, ascending: false)],
		animation: .snappy
	) private var _certificates: FetchedResults<CertificatePair>

	@FetchRequest(
		entity: Signed.entity(),
		sortDescriptors: [NSSortDescriptor(keyPath: \Signed.date, ascending: false)],
		animation: .snappy
	) private var _signedApps: FetchedResults<Signed>

	@State private var _renewMessage: String?
	@State private var _revocationMessage: String?
	@State private var _reinstallEverything = false

	var body: some View {
		NBNavigationView(.localized("Certificate Health")) {
			Form {
				if _certificates.isEmpty {
					Section {
						Text(.localized("No certificates imported."))
							.foregroundStyle(.secondary)
					}
				} else {
					NBSection(.localized("Certificates")) {
						ForEach(_certificates, id: \.uuid) { cert in
							_certRow(cert)
						}
					} footer: {
						Text(.localized("Apps are renewed automatically before a certificate expires, as long as a healthy certificate exists."))
					}

					NBSection(.localized("Maintenance")) {
						Button {
							_renewAll()
						} label: {
							Label(.localized("Renew All Apps with Best Certificate"), systemImage: "checkmark.seal.fill")
						}
						.disabled(_bestCertificate == nil || _signedApps.isEmpty)

						Button {
							_checkRevocations()
						} label: {
							Label(.localized("Check Revocation Status Now"), systemImage: "shield.lefthalf.filled")
						}
						.disabled(_certificates.isEmpty)

						Button {
							_reinstallEverything = true
						} label: {
							Label(.localized("Reinstall Everything"), systemImage: "arrow.clockwise.circle.fill")
						}
						.disabled(_signedApps.isEmpty)
						.confirmationDialog(
							.localized("Reinstall all apps?"),
							isPresented: $_reinstallEverything,
							titleVisibility: .visible
						) {
							Button(.localized("Reinstall \(_signedApps.count) apps")) {
								for app in _signedApps {
									AutoSignManager.shared.enqueue(app: app, reason: .renewal)
								}
								_renewMessage = .localized("All apps queued for reinstall.")
							}
							Button(.localized("Cancel"), role: .cancel) {}
						} message: {
							Text(.localized("Every installed app will be prepared for install again using its current certificate."))
						}
					}

					Section {
						Toggle(isOn: Binding(
							get: { AutoUpdateManager.shared.isSelfHealEnabled },
							set: { AutoUpdateManager.shared.isSelfHealEnabled = $0 }
						)) {
							Label(.localized("Self-Heal Revoked Apps"), systemImage: "arrow.clockwise.heart")
						}
					} footer: {
						Text(.localized("When a certificate is revoked, affected apps are automatically re-signed with your healthiest certificate and prepared for install."))
					}

					if let message = _revocationMessage ?? _renewMessage {
						Section {
							Text(message)
								.font(.footnote)
								.foregroundStyle(.secondary)
						}
					}
				}
			}
		}
		.navigationTitle(.localized("Certificate Health"))
	}
}

// MARK: - Rows
extension CertHealthView {
	@ViewBuilder
	private func _certRow(_ cert: CertificatePair) -> some View {
		let days = cert.expiration.map {
			Int($0.timeIntervalSinceNow / 86400)
		}

		HStack(spacing: 14) {
			ExpiryRingView(
				fraction: _ringFraction(days: days, revoked: cert.revoked),
				color: _ringColor(days: days, revoked: cert.revoked)
			)

			VStack(alignment: .leading, spacing: 3) {
				Text(cert.nickname ?? "Certificate")
					.font(.body.weight(.semibold))
					.lineLimit(1)

				if cert.revoked {
					Text(.localized("Revoked"))
						.font(.caption.weight(.semibold))
						.foregroundStyle(.red)
				} else if let days {
					Text(verbatim: days < 0
						? .localized("Expired")
						: .localized("Expires in %lld days", arguments: days))
						.font(.caption)
						.foregroundStyle(days <= 3 ? .orange : .secondary)
				} else {
					Text(.localized("No expiry information"))
						.font(.caption)
						.foregroundStyle(.secondary)
				}

				Text(verbatim: _appCount(cert))
					.font(.caption2)
					.foregroundStyle(.tertiary)
			}

			Spacer()
		}
		.padding(.vertical, 2)
	}

	struct ExpiryRingView: View {
		let fraction: Double
		let color: Color

		var body: some View {
			ZStack {
				Circle()
					.stroke(Color(uiColor: .tertiarySystemFill), lineWidth: 4)
				Circle()
					.trim(from: 0, to: max(0.02, min(fraction, 1)))
					.stroke(color, style: StrokeStyle(lineWidth: 4, lineCap: .round))
					.rotationEffect(.degrees(-90))
			}
			.frame(width: 42, height: 42)
		}
	}

	private func _ringFraction(days: Int?, revoked: Bool) -> Double {
		guard let days, days > 0 else { return 0.02 }
		return min(Double(days) / 30.0, 1.0)
	}

	private func _ringColor(days: Int?, revoked: Bool) -> Color {
		if revoked { return .red }
		guard let days else { return .secondary }
		if days <= 0 { return .red }
		if days <= 3 { return .orange }
		return .green
	}

	private func _appCount(_ cert: CertificatePair) -> String {
		let count = _signedApps.filter { $0.certificate == cert }.count
		return count == 1 ? "1 app uses this" : "\(count) apps use this"
	}

	private var _bestCertificate: CertificatePair? {
		_certificates
			.filter { !$0.revoked && ($0.expiration.map { $0.timeIntervalSinceNow > 86400 } ?? true) }
			.max { ($0.expiration ?? .distantPast) < ($1.expiration ?? .distantPast) }
	}

	private func _checkRevocations() {
		UIImpactFeedbackGenerator(style: .medium).impactOccurred()
		let certs = Storage.shared.getAllCertificates()
		for cert in certs {
			Storage.shared.revokagedCertificate(for: cert)
		}
		_revocationMessage = certs.isEmpty
			? .localized("No certificates to check.")
			: .localized("Checked %lld certificates against Apple's revocation status.", arguments: certs.count)
	}

	private func _renewAll() {
		guard let best = _bestCertificate else { return }
		UIImpactFeedbackGenerator(style: .medium).impactOccurred()

		var queued = 0
		for app in _signedApps {
			AutoSignManager.shared.enqueue(app: app, reason: .renewal, certificate: best)
			queued += 1
		}

		_renewMessage = queued == 1
			? .localized("1 app queued for renewal.")
			: .localized("%lld apps queued for renewal.", arguments: queued)
	}
}
