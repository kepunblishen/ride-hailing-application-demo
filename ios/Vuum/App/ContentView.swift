import SwiftUI

/// App gate: branded splash → signed-out auth or signed-in main tabs.
struct ContentView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var permissions: PermissionCenter

    @State private var showSplash = true

    var body: some View {
        ZStack {
            Group {
                if session.isSignedIn {
                    MainTabView()
                } else {
                    AuthFlowView()
                }
            }
            .opacity(showSplash ? 0 : 1)
            .allowsHitTesting(!showSplash)
            .safeAreaInset(edge: .top, spacing: 0) {
                if !showSplash {
                    VuumOfflineBanner {
                        NotificationCenter.default.post(name: .vuumNetworkRetry, object: nil)
                    }
                }
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showSplash)
        .animation(.easeInOut(duration: 0.35), value: session.isSignedIn)
        .task {
            await runSplashGate()
        }
    }

    /// Short premium brand moment while session (Keychain) and permission statuses settle.
    private func runSplashGate() async {
        let clock = ContinuousClock()
        let started = clock.now
        async let permissionRefresh: Void = permissions.refreshStatuses()

        // SessionStore already hydrated synchronously; Maps bootstrap runs in `VuumApp.init`.
        _ = await permissionRefresh

        let minimum: Duration = .milliseconds(1_650)
        let elapsed = clock.now - started
        if elapsed < minimum {
            try? await Task.sleep(for: minimum - elapsed)
        }

        withAnimation(.easeInOut(duration: 0.4)) {
            showSplash = false
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppLocale())
        .environmentObject(TripSession())
        .environmentObject(SessionStore())
        .environmentObject(RiderLocationManager())
        .environmentObject(PermissionCenter())
        .environmentObject(NotificationStore())
        .environmentObject(SavedPlacesStore())
        .environmentObject(TrustedContactsStore())
        .environmentObject(PaymentMethodStore())
        .environmentObject(NetworkReachability())
        .environmentObject(AppPreferences.shared)
}
