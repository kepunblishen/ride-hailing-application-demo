import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var tripSession: TripSession
    @State private var showSplash = true

    var body: some View {
        ZStack {
            RootFlowView()
                .opacity(showSplash ? 0 : 1)

            if showSplash {
                SplashView()
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.35), value: showSplash)
        .task {
            try? await Task.sleep(for: .milliseconds(1200))
            showSplash = false
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(TripSession())
}
