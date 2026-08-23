import SwiftUI

/// Account security: app lock preference, this-device session, recent sign-ins.
struct SecuritySettingsView: View {
    @EnvironmentObject private var session: SessionStore
    @AppStorage("vuum.security.appLock") private var appLock = false
    @State private var signedOutOthers = false

    var body: some View {
        List {
            Section(L10n.Settings.appLock) {
                Toggle(L10n.Settings.biometric, isOn: $appLock)
            }

            Section(L10n.Settings.activeSessions) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.Settings.thisDevice)
                        Text(session.maskedMobile)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "iphone")
                        .foregroundStyle(VuumColor.brandInk)
                }
                Button(L10n.Settings.signOutOthers) {
                    signedOutOthers = true
                }
            }

            Section(L10n.Settings.recentSignIns) {
                ForEach(Self.recentSignIns, id: \.id) { entry in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.device)
                            .font(.system(size: 15, weight: .semibold))
                        Text(entry.detail)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(L10n.Settings.security)
        .navigationBarTitleDisplayMode(.inline)
        .alert(L10n.Settings.signOutOthers, isPresented: $signedOutOthers) {
            Button(L10n.Common.gotIt, role: .cancel) {}
        } message: {
            Text(L10n.Settings.signOutOthersDone)
        }
    }

    private struct SignInEntry: Identifiable {
        let id: String
        let device: String
        let detail: String
    }

    private static var recentSignIns: [SignInEntry] {
        [
            SignInEntry(
                id: "1",
                device: L10n.Settings.thisDevice,
                detail: "Lubumbashi · \(L10n.Settings.statusActive)"
            ),
            SignInEntry(
                id: "2",
                device: "iPhone",
                detail: "Kolwezi · 3d"
            ),
        ]
    }
}
