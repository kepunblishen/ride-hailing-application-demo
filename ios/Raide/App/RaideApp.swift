import SwiftUI

@main
struct RaideApp: App {
    @StateObject private var tripSession = TripSession()

    init() {
        RaideTheme.configureComponentsKit()
        MapBootstrap.configureIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tripSession)
        }
    }
}
