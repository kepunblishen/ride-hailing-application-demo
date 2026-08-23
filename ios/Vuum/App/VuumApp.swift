import SwiftUI

@main
struct VuumApp: App {
    @StateObject private var tripSession = TripSession()

    init() {
        VuumTheme.configureComponentsKit()
        MapBootstrap.configureIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tripSession)
        }
    }
}
