import SwiftUI
import UIKit

// MARK: - Tab IA

/// Primary signed-in shell: Home · Services · Activity · Account.
enum MainTab: Int, Hashable, CaseIterable {
    case home = 0
    case services = 1
    case activity = 2
    case account = 3
}

/// Cross-hub deep links into the main tab shell (and optional booking handoff).
enum MainTabNavigation {
    static let tabUserInfoKey = "tab"
    static let beginBookingUserInfoKey = "beginBooking"
    static let preferredTierIDUserInfoKey = "preferredTierID"

    static func select(_ tab: MainTab, beginBooking: Bool = false, preferredTierID: String? = nil) {
        var info: [AnyHashable: Any] = [tabUserInfoKey: tab.rawValue]
        if beginBooking {
            info[beginBookingUserInfoKey] = true
        }
        if let preferredTierID {
            info[preferredTierIDUserInfoKey] = preferredTierID
        }
        NotificationCenter.default.post(name: .vuumSelectMainTab, object: nil, userInfo: info)
    }

    static func openHome(beginBooking: Bool = false, preferredTierID: String? = nil) {
        select(.home, beginBooking: beginBooking, preferredTierID: preferredTierID)
    }

    static func openServices() {
        select(.services)
    }

    static func openActivity() {
        select(.activity)
    }

    static func openAccount() {
        select(.account)
    }
}

extension Notification.Name {
    /// `userInfo`: `tab` (MainTab.rawValue), optional `beginBooking` (Bool).
    static let vuumSelectMainTab = Notification.Name("vuumSelectMainTab")
    /// Legacy alias — still accepted by `MainTabView`.
    static let vuumSelectServicesTab = Notification.Name("vuumSelectServicesTab")
    /// Posted when the rider taps Retry on the offline banner.
    static let vuumNetworkRetry = Notification.Name("vuumNetworkRetry")
}

// MARK: - Tab bar chrome (dark-mode safe)

/// UIKit appearance for the system tab bar — selected tint must not be near-black in dark mode.
enum MainTabBarChrome {
    static func apply() {
        let appearance = UITabBarAppearance()
        // System material adapts to light/dark (including floating pill bars).
        appearance.configureWithDefaultBackground()

        // Selected: brand accent (readable on light + dark). Avoid brandInk — it vanishes on dark bars.
        let selected = UIColor(VuumColor.accent)
        let normal = UIColor.secondaryLabel

        styleItemAppearance(appearance.stackedLayoutAppearance, selected: selected, normal: normal)
        styleItemAppearance(appearance.inlineLayoutAppearance, selected: selected, normal: normal)
        styleItemAppearance(appearance.compactInlineLayoutAppearance, selected: selected, normal: normal)

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = appearance
        tabBar.scrollEdgeAppearance = appearance
        tabBar.tintColor = selected
        tabBar.unselectedItemTintColor = normal
        tabBar.barTintColor = nil
        tabBar.isTranslucent = true
    }

    private static func styleItemAppearance(
        _ item: UITabBarItemAppearance,
        selected: UIColor,
        normal: UIColor
    ) {
        item.normal.iconColor = normal
        item.normal.titleTextAttributes = [.foregroundColor: normal]
        item.selected.iconColor = selected
        item.selected.titleTextAttributes = [.foregroundColor: selected]
    }
}

// MARK: - Shell

struct MainTabView: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var notifications: NotificationStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTab: MainTab = .home
    /// Tab the rider was on before booking forced Home (e.g. Services → Plan your ride).
    /// Restored when they cancel back to `.idle` — not after a live trip completes.
    @State private var tabToRestoreAfterBooking: MainTab?

    /// Immersive map: hide the tab bar on map-hosted booking + live trip phases.
    private var hidesTabBarForActiveTrip: Bool {
        switch tripSession.phase {
        case .selectingDestination, .choosingRide, .confirmingRide,
             .searching, .matched, .driverEnRoute, .driverArrived, .inTrip:
            return true
        default:
            return false
        }
    }

    var body: some View {
        // Offline banner lives on ContentView via safeAreaInset — do not stack another here.
        TabView(selection: $selectedTab) {
            RootFlowView()
                .toolbar(hidesTabBarForActiveTrip ? .hidden : .visible, for: .tabBar)
                .tabItem { Label(L10n.t("tab.home"), systemImage: "house.fill") }
                .tag(MainTab.home)
                .accessibilityLabel(L10n.t("tab.home"))

            ServicesHubView { preferredTierID in
                MainTabNavigation.openHome(beginBooking: true, preferredTierID: preferredTierID)
            }
            .tabItem { Label(L10n.t("tab.services"), systemImage: "square.grid.2x2.fill") }
            .tag(MainTab.services)
            .accessibilityLabel(L10n.t("tab.services"))

            ActivityHubView()
                .tabItem { Label(L10n.t("tab.activity"), systemImage: "list.bullet.rectangle.fill") }
                .tag(MainTab.activity)
                .accessibilityLabel(L10n.t("tab.activity"))

            AccountView()
                .tabItem { Label(L10n.t("tab.account"), systemImage: "person.fill") }
                .badge(notifications.unreadCount)
                .tag(MainTab.account)
                .accessibilityLabel(L10n.t("tab.account"))
        }
        .tint(VuumColor.accent)
        .toolbarBackground(.visible, for: .tabBar)
        .toolbarBackground(VuumColor.pageBackground, for: .tabBar)
        .onAppear { MainTabBarChrome.apply() }
        .onChange(of: colorScheme) { _, _ in
            MainTabBarChrome.apply()
        }
        .onChange(of: tripSession.phase) { _, phase in
            handleTripPhaseChange(phase)
        }
        .onReceive(NotificationCenter.default.publisher(for: .vuumSelectMainTab)) { note in
            applyDeepLink(userInfo: note.userInfo)
        }
        .onReceive(NotificationCenter.default.publisher(for: .vuumSelectServicesTab)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTab = .services
            }
        }
    }

    private func applyDeepLink(userInfo: [AnyHashable: Any]?) {
        let raw = userInfo?[MainTabNavigation.tabUserInfoKey] as? Int
            ?? (userInfo?[MainTabNavigation.tabUserInfoKey] as? NSNumber)?.intValue
        let tab = raw.flatMap(MainTab.init(rawValue:)) ?? .home
        let beginBooking = (userInfo?[MainTabNavigation.beginBookingUserInfoKey] as? Bool) == true
            || (userInfo?[MainTabNavigation.beginBookingUserInfoKey] as? NSNumber)?.boolValue == true
        let preferredTierID = userInfo?[MainTabNavigation.preferredTierIDUserInfoKey] as? String

        if beginBooking, tab == .home {
            rememberTabBeforeBookingIfNeeded()
        }

        withAnimation(.easeInOut(duration: 0.22)) {
            selectedTab = tab
        }
        if beginBooking, tab == .home {
            tripSession.beginDestinationSelection(preferredTierID: preferredTierID)
        }
    }

    private func rememberTabBeforeBookingIfNeeded() {
        if selectedTab != .home, tabToRestoreAfterBooking == nil {
            tabToRestoreAfterBooking = selectedTab
        }
    }

    private func handleTripPhaseChange(_ phase: TripPhase) {
        switch phase {
        case .idle:
            // Cancelled Plan your ride / choose-ride — return to Services (etc.), not stuck on Home.
            if let restore = tabToRestoreAfterBooking {
                tabToRestoreAfterBooking = nil
                withAnimation(.easeInOut(duration: 0.22)) {
                    selectedTab = restore
                }
            }
        case .completed:
            tabToRestoreAfterBooking = nil
            notifications.postTripCompleted()
            if let receipt = tripSession.lastReceipt {
                notifications.postReceiptReady(destination: receipt.dropoffName)
            }
            // Stay on Home for rating / receipt sheet; Activity remains one tap away.
        case .driverEnRoute:
            tabToRestoreAfterBooking = nil
            if let trip = tripSession.activeTrip {
                notifications.postDriverAssigned(
                    driverName: trip.driver.name,
                    vehicle: trip.driver.vehicle,
                    plate: trip.driver.plate,
                    etaMinutes: trip.etaMinutes
                )
            }
            selectedTab = .home
        case .driverArrived:
            tabToRestoreAfterBooking = nil
            notifications.postDriverArrived()
            selectedTab = .home
        case .inTrip:
            tabToRestoreAfterBooking = nil
            notifications.postTripStarted()
            selectedTab = .home
        case .selectingDestination, .choosingRide, .confirmingRide:
            rememberTabBeforeBookingIfNeeded()
            selectedTab = .home
        case .searching, .matched:
            // Matching started — booking originated here; don't bounce back to Services after.
            tabToRestoreAfterBooking = nil
            selectedTab = .home
        }
    }
}

/// Thin wrapper so tab wiring stays on `AccountView` while the hub owns the UI.
struct AccountView: View {
    var body: some View {
        AccountHubView()
    }
}
