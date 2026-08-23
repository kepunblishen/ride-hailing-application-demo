import SwiftUI

/// App gate: branded splash → signed-out auth or signed-in main tabs.
struct ContentView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var permissions: PermissionCenter

    @State private var showSplash = true

    var body: some View {
        ZStack {
            // Mount interactive destinations only after splash dismisses so
            // auth TextFields cannot auto-focus / open the keyboard under splash.
            if !showSplash {
                Group {
                    if session.isSignedIn {
                        MainTabView()
                    } else {
                        AuthFlowView()
                    }
                }
                .safeAreaInset(edge: .top, spacing: 0) {
                    VuumOfflineBanner {
                        NotificationCenter.default.post(name: .vuumNetworkRetry, object: nil)
                    }
                }
                .transition(.opacity)
            }

            if showSplash {
                SplashView()
                    .transition(.opacity)
                    .zIndex(1)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: showSplash)
        .animation(.easeInOut(duration: 0.35), value: session.isSignedIn)
        // AuthLocale must stay active for the whole signed-out AuthFlow — do not
        // clear it on language-driven view remounts inside AuthFlowView.
        .onAppear { AuthLocale.shared.syncWithSession(isSignedIn: session.isSignedIn) }
        .onChange(of: session.isSignedIn) { _, signedIn in
            AuthLocale.shared.syncWithSession(isSignedIn: signedIn)
        }
        .task {
            await runSplashGate()
        }
    }

    /// Bootstrap/load first, then hold splash for an additional 3 seconds.
    private func runSplashGate() async {
        async let permissionRefresh: Void = permissions.refreshStatuses()

        // SessionStore already hydrated synchronously; Maps bootstrap runs in `VuumApp.init`.
        _ = await permissionRefresh

        try? await Task.sleep(for: .seconds(3))

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
        .environmentObject(PromoCodesStore())
        .environmentObject(NetworkReachability())
        .environmentObject(AppPreferences.shared)
}
