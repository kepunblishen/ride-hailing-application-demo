import SwiftUI
import UIKit

@main
struct VuumApp: App {
    @StateObject private var appLocale = AppLocale()
    @StateObject private var tripSession = TripSession()
    @StateObject private var sessionStore = SessionStore()
    @StateObject private var location = RiderLocationManager()
    @StateObject private var permissions = PermissionCenter()
    @StateObject private var savedPlaces = SavedPlacesStore()
    @StateObject private var trustedContacts = TrustedContactsStore()
    @StateObject private var payments = PaymentMethodStore()
    @StateObject private var notifications = NotificationStore()
    @StateObject private var network = NetworkReachability()
    @StateObject private var fieldSales = FieldSalesStore()
    @ObservedObject private var preferences = AppPreferences.shared
    @ObservedObject private var diagnostics = DeveloperDiagnostics.shared

    init() {
        VuumTheme.configureComponentsKit()
        MapBootstrap.configureIfNeeded()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appLocale)
                .environmentObject(tripSession)
                .environmentObject(sessionStore)
                .environmentObject(location)
                .environmentObject(permissions)
                .environmentObject(savedPlaces)
                .environmentObject(trustedContacts)
                .environmentObject(payments)
                .environmentObject(notifications)
                .environmentObject(network)
                .environmentObject(fieldSales)
                .environmentObject(preferences)
                .environmentObject(diagnostics)
                .id(preferences.languageCode)
                .onAppear {
                    permissions.bind(locationManager: location)
                    tripSession.bind(locale: appLocale)
                    tripSession.bind(notifications: notifications)
                    tripSession.bind(payments: payments)
                    tripSession.bind(fieldSales: fieldSales)
                    permissions.applyPreciseLocationPreference()
                    network.setForcedOffline(diagnostics.forceNetworkOffline)
                }
                .onChange(of: location.latestLocation) { _, newValue in
                    appLocale.update(from: newValue)
                }
                .onChange(of: diagnostics.forceNetworkOffline) { _, offline in
                    network.setForcedOffline(offline)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                    Task {
                        await permissions.refreshStatuses()
                        if permissions.isLocationAuthorized {
                            location.refreshCurrentLocation()
                        }
                    }
                }
                .task {
                    await permissions.refreshStatuses()
                    if permissions.isLocationAuthorized {
                        location.startUpdatingIfAllowed()
                    }
                }
        }
    }
}
