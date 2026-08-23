import SwiftUI

/// Content-first home for starting a trip, revisiting places, and discovering Vuum services.
struct HomeHubView: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var location: RiderLocationManager
    @EnvironmentObject private var permissions: PermissionCenter
    @EnvironmentObject private var savedPlaces: SavedPlacesStore
    @EnvironmentObject private var appLocale: AppLocale
    @EnvironmentObject private var notifications: NotificationStore
    @Environment(\.openURL) private var openURL

    @State private var hubTab: HubTopTab = .rides
    @State private var showSchedule = false
    @State private var showSafety = false
    @State private var showInbox = false
    @State private var showPermissionsExplainer = false
    @State private var assignSlot: SavedPlaceKind?
    @State private var serviceDetail: HomeSuggestion?
    @State private var showTwoWheels = false
    @State private var showCourier = false

    private var showLocationDeniedBanner: Bool {
        permissions.isLocationDenied || !location.locationServicesEnabled
    }

    private var showApproximateLocationBanner: Bool {
        !showLocationDeniedBanner
            && location.isAuthorized
            && location.locationServicesEnabled
            && !location.isPreciseLocation
    }

    private var recentPlaces: [Place] {
        var seen = Set<String>()
        var places: [Place] = []

        func append(_ place: Place?) {
            guard let place,
                  place.id != tripSession.pickup.id,
                  seen.insert(place.id).inserted else { return }
            places.append(place)
        }

        savedPlaces.recent.forEach { append($0) }
        for receipt in tripSession.tripHistory {
            append(appLocale.destinations.first(where: { $0.name == receipt.dropoffName }))
        }
        for place in appLocale.destinations {
            append(place)
            if places.count >= 5 { break }
        }
        return Array(places.prefix(5))
    }

    private var additionalRecentPlaces: [Place] {
        Array(recentPlaces.dropFirst().prefix(3))
    }

    private var favoriteChips: [Place] {
        let excluded = Set([savedPlaces.home?.id, savedPlaces.work?.id].compactMap { $0 })
        return Array(savedPlaces.favorites.filter { !excluded.contains($0.id) }.prefix(3))
    }

    var body: some View {
        VStack(spacing: 0) {
            stickyHeader

            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 0) {
                    statusBanners
                        .padding(.top, 4)

                    if let firstRecent = recentPlaces.first {
                        featuredRecentCard(firstRecent)
                            .padding(.top, 14)
                    }

                    servicesSection
                        .padding(.top, 26)

                    savedPlacesSection
                        .padding(.top, 26)

                    if !additionalRecentPlaces.isEmpty {
                        recentRows
                            .padding(.top, 22)
                    }

                    if !tripSession.reservedTrips.isEmpty {
                        upcomingSection
                            .padding(.top, 26)
                    }

                    if hubTab == .courier {
                        courierHero
                            .padding(.top, 26)
                    } else {
                        ridePromo
                            .padding(.top, 26)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
        }
        .background(VuumColor.pageBackground.ignoresSafeArea())
        .onAppear {
            // Content-first home: no map recenter — map only after destination selection.
            if permissions.shouldShowExplainer {
                showPermissionsExplainer = true
            } else {
                location.requestWhenInUse()
            }
        }
        .onChange(of: location.latestLocation) { _, newValue in
            tripSession.updatePickup(from: newValue)
        }
        .sheet(isPresented: $showPermissionsExplainer) {
            PermissionsExplainerSheet {
                permissions.markExplainerShown()
                showPermissionsExplainer = false
                Task {
                    await permissions.requestHomePermissions()
                }
            }
        }
        .sheet(isPresented: $showSchedule) {
            ScheduleRideSheet()
        }
        .sheet(isPresented: $showSafety) {
            SafetyToolkitView()
        }
        .sheet(isPresented: $showInbox) {
            NavigationStack {
                NotificationInboxView()
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showInbox = false }
                        }
                    }
            }
        }
        .sheet(item: $assignSlot) { kind in
            AssignSavedPlaceSheet(kind: kind)
        }
        .sheet(item: $serviceDetail) { suggestion in
            HomeSuggestionSheet(suggestion: suggestion) {
                serviceDetail = nil
                runSuggestionAction(suggestion)
            }
        }
        .sheet(isPresented: $showTwoWheels) {
            TwoWheelsProductSheet()
        }
        .sheet(isPresented: $showCourier) {
            CourierProductSheet()
        }
    }

    /// Brand, category tabs, and Where to? stay fixed; content scrolls beneath.
    private var stickyHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            topBar
            categoryTabs
                .padding(.top, 14)
            searchBar
                .padding(.top, 16)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(VuumColor.pageBackground)
    }

    // MARK: - Header

    private var topBar: some View {
        HStack(spacing: 12) {
            Text("Vuum")
                .font(.system(size: 32, weight: .bold))
                .foregroundStyle(VuumColor.primaryText)

            Spacer()

            Button {
                showInbox = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VuumColor.primaryText)
                        .frame(width: 42, height: 42)
                        .background(VuumColor.chipBackground, in: Circle())

                    if notifications.unreadCount > 0 {
                        Text(notifications.unreadCount > 9 ? "9+" : "\(notifications.unreadCount)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(VuumColor.brand, in: Capsule())
                            .offset(x: 4, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Settings.inbox)

            Button {
                showSafety = true
            } label: {
                Image(systemName: "shield")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VuumColor.primaryText)
                    .frame(width: 42, height: 42)
                    .background(VuumColor.chipBackground, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Home.safety)
        }
    }

    private var categoryTabs: some View {
        HStack(spacing: 24) {
            categoryTab(.rides, title: "Vuum")
            categoryTab(.courier, title: L10n.Services.courier)
            Spacer()
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(VuumColor.secondaryText.opacity(0.18))
                .frame(height: 1)
                .offset(y: 1)
        }
    }

    private func categoryTab(_ tab: HubTopTab, title: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                hubTab = tab
            }
        } label: {
            VStack(spacing: 10) {
                Text(title)
                    .font(.system(size: 15, weight: hubTab == tab ? .bold : .semibold))
                    .foregroundStyle(hubTab == tab ? VuumColor.primaryText : VuumColor.secondaryText)

                Capsule()
                    .fill(hubTab == tab ? VuumColor.primaryText : Color.clear)
                    .frame(height: 3)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Status

    @ViewBuilder
    private var statusBanners: some View {
        VStack(spacing: 10) {
            if showLocationDeniedBanner {
                PermissionDeniedBanner(
                    icon: "location.slash",
                    title: "Location is off",
                    message: location.locationServicesEnabled
                        ? "Turn on location so Vuum can set your pickup."
                        : "Location Services are turned off for this device. Enable them to set your pickup."
                ) {
                    if let url = permissions.systemSettingsURL {
                        openURL(url)
                    }
                }
            } else if let message = location.lastErrorMessage, location.latestLocation == nil {
                PermissionDeniedBanner(
                    icon: "location.magnifyingglass",
                    title: "Finding your location",
                    message: message,
                    actionTitle: "Try again"
                ) {
                    location.refreshCurrentLocation()
                }
            } else if showApproximateLocationBanner {
                PermissionDeniedBanner(
                    icon: "location.circle",
                    title: "Approximate location",
                    message: "Precise location improves pickup accuracy.",
                    actionTitle: "Improve accuracy"
                ) {
                    location.requestPreciseLocationUpgrade()
                }
            }

            if let cancellation = tripSession.lastCancellation {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: cancellation.wasFree ? "checkmark.circle" : "info.circle")
                        .foregroundStyle(VuumColor.brand)
                        .padding(.top, 1)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(cancellation.summaryLine)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VuumColor.primaryText)
                        if !cancellation.wasFree, cancellation.feeLocal > 0 {
                            Text(
                                "Fee \(AppLocale.formatPrimary(local: cancellation.feeLocal, market: appLocale.fareMarket))"
                            )
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(VuumColor.secondaryText)
                        }
                    }

                    Spacer(minLength: 8)

                    Button {
                        tripSession.dismissCancellationBanner()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(VuumColor.secondaryText)
                            .frame(width: 28, height: 28)
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)
                .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    // MARK: - Search and places

    private var searchBar: some View {
        HStack(spacing: 0) {
            Button {
                tripSession.beginDestinationSelection()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 17, weight: .semibold))
                    Text(L10n.Home.whereTo)
                        .font(.system(size: 17, weight: .semibold))
                    Spacer(minLength: 8)
                }
                .foregroundStyle(VuumColor.primaryText)
                .padding(.leading, 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(L10n.Home.whereToHint)

            Rectangle()
                .fill(VuumColor.secondaryText.opacity(0.22))
                .frame(width: 1, height: 26)

            Button {
                showSchedule = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                    Text(L10n.Home.later)
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(VuumColor.primaryText)
                .padding(.horizontal, 14)
                .frame(height: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Home.schedulePickup)
        }
        .frame(height: 54)
        .background(VuumColor.chipBackground, in: Capsule())
    }

    private func featuredRecentCard(_ place: Place) -> some View {
        Button {
            choose(place)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "mappin")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(VuumColor.primaryText)
                    .frame(width: 42, height: 42)
                    .background(VuumColor.chipBackground, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(savedPlaces.displayTitle(for: place))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VuumColor.primaryText)
                        .lineLimit(1)
                    Text(place.subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(VuumColor.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VuumColor.secondaryText)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(VuumColor.pageBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(VuumColor.secondaryText.opacity(0.22), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(savedPlaces.displayTitle(for: place)), \(place.subtitle)")
    }

    private var savedPlacesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Saved places")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(VuumColor.primaryText)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    savedSlotChip(kind: .home, place: savedPlaces.home, emptyTitle: L10n.Home.addHome)
                    savedSlotChip(kind: .work, place: savedPlaces.work, emptyTitle: L10n.Home.addWork)

                    ForEach(favoriteChips) { place in
                        Button {
                            choose(place)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: savedPlaces.systemImage(for: place))
                                Text(savedPlaces.displayTitle(for: place))
                                    .lineLimit(1)
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VuumColor.primaryText)
                            .padding(.horizontal, 13)
                            .frame(height: 40)
                            .background(VuumColor.chipBackground, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func savedSlotChip(kind: SavedPlaceKind, place: Place?, emptyTitle: String) -> some View {
        if let place {
            Button {
                choose(place)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: kind.systemImage)
                    Text(kind.title)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VuumColor.primaryText)
                .padding(.horizontal, 13)
                .frame(height: 40)
                .background(VuumColor.chipBackground, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(kind.title), \(place.name)")
        } else {
            Button {
                assignSlot = kind
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: kind == .home ? "house" : "briefcase")
                    Text(emptyTitle)
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VuumColor.secondaryText)
                .padding(.horizontal, 13)
                .frame(height: 40)
                .background(VuumColor.chipBackground, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var recentRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.Home.recent)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(VuumColor.primaryText)
                .padding(.bottom, 8)

            ForEach(Array(additionalRecentPlaces.enumerated()), id: \.element.id) { index, place in
                Button {
                    choose(place)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(VuumColor.secondaryText)
                            .frame(width: 38, height: 38)
                            .background(VuumColor.chipBackground, in: Circle())

                        VStack(alignment: .leading, spacing: 3) {
                            Text(savedPlaces.displayTitle(for: place))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(VuumColor.primaryText)
                                .lineLimit(1)
                            Text(place.subtitle)
                                .font(.system(size: 13))
                                .foregroundStyle(VuumColor.secondaryText)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if index < additionalRecentPlaces.count - 1 {
                    Divider()
                        .padding(.leading, 52)
                }
            }
        }
    }

    private func choose(_ place: Place) {
        savedPlaces.recordRecent(place)
        tripSession.selectDestination(place)
    }

    // MARK: - Services

    private var servicesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button {
                MainTabNavigation.openServices()
            } label: {
                HStack {
                    Text("For you")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(VuumColor.primaryText)
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VuumColor.primaryText)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open all services")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 18) {
                    ForEach(visibleSuggestions) { item in
                        Button {
                            handleSuggestion(item)
                        } label: {
                            serviceIcon(item)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(item.title)
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var visibleSuggestions: [HomeSuggestion] {
        HomeSuggestion.all.filter { suggestion in
            switch suggestion.action {
            case .bookRide(let tierID):
                guard let tierID else { return true }
                return tripSession.isServiceAvailable(tierID)
            case .schedule:
                return tripSession.isServiceAvailable(ServiceProductID.reserve)
            case .openServices:
                if suggestion.id == ServiceProductID.twoWheels {
                    return tripSession.isServiceAvailable(ServiceProductID.twoWheels)
                }
                if suggestion.id == ServiceProductID.courier {
                    return tripSession.isServiceAvailable(ServiceProductID.courier)
                }
                return true
            case .infoOnly:
                return true
            }
        }
        .filter { suggestion in
            switch hubTab {
            case .rides:
                return true
            case .courier:
                return suggestion.id == ServiceProductID.courier
                    || suggestion.id == ServiceProductID.reserve
                    || suggestion.id == ServiceProductID.twoWheels
            }
        }
    }

    private func serviceIcon(_ item: HomeSuggestion) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(VuumColor.chipBackground)
                    .frame(width: 64, height: 64)
                    .overlay(
                        Image(systemName: item.systemImage)
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(VuumColor.primaryText)
                    )

                if let badge = item.promoBadge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(VuumColor.brand, in: Capsule())
                        .offset(x: 8, y: -3)
                }
            }

            Text(item.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VuumColor.primaryText)
                .lineLimit(1)
                .frame(width: 72)
        }
    }

    private func handleSuggestion(_ item: HomeSuggestion) {
        switch item.action {
        case .bookRide(let tierID):
            tripSession.beginDestinationSelection(preferredTierID: tierID)
        case .schedule:
            showSchedule = true
        case .openServices:
            if item.id == ServiceProductID.twoWheels {
                showTwoWheels = true
            } else if item.id == ServiceProductID.courier {
                showCourier = true
            } else {
                MainTabNavigation.openServices()
            }
        case .infoOnly:
            serviceDetail = item
        }
    }

    private func runSuggestionAction(_ suggestion: HomeSuggestion) {
        switch suggestion.action {
        case .bookRide(let tierID):
            tripSession.beginDestinationSelection(preferredTierID: tierID)
        case .schedule:
            showSchedule = true
        case .openServices:
            if suggestion.id == ServiceProductID.twoWheels {
                showTwoWheels = true
            } else if suggestion.id == ServiceProductID.courier {
                showCourier = true
            } else {
                MainTabNavigation.openServices()
            }
        case .infoOnly:
            break
        }
    }

    // MARK: - Upcoming and promotions

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(L10n.Home.upcoming)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(VuumColor.primaryText)
                Spacer()
                Button("Manage") {
                    MainTabNavigation.openActivity()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VuumColor.brand)
            }

            ForEach(tripSession.reservedTrips.prefix(2)) { trip in
                Button {
                    MainTabNavigation.openActivity()
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "calendar")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(VuumColor.brand)
                            .frame(width: 42, height: 42)
                            .background(VuumColor.chipBackground, in: Circle())

                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(trip.pickupName) → \(trip.dropoffName)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(VuumColor.primaryText)
                                .lineLimit(1)
                            Text(trip.when.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12))
                                .foregroundStyle(VuumColor.secondaryText)
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                    .padding(14)
                    .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var courierHero: some View {
        Button {
            showCourier = true
        } label: {
            HStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Send it with Vuum")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(VuumColor.primaryText)
                    Text("On-demand pickup and delivery for packages across town.")
                        .font(.system(size: 14))
                        .foregroundStyle(VuumColor.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Start a delivery")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .frame(height: 38)
                        .background(VuumColor.brand, in: Capsule())
                        .padding(.top, 4)
                }

                Spacer(minLength: 4)

                Image(systemName: "shippingbox")
                    .font(.system(size: 34, weight: .medium))
                    .foregroundStyle(VuumColor.primaryText)
                    .frame(width: 78, height: 78)
                    .background(VuumColor.chipBackground, in: Circle())
            }
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(VuumColor.pageBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(VuumColor.secondaryText.opacity(0.2), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private var ridePromo: some View {
        Button {
            tripSession.beginDestinationSelection()
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "car")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(VuumColor.brand)
                    .frame(width: 64, height: 64)
                    .background(VuumColor.chipBackground, in: Circle())

                VStack(alignment: .leading, spacing: 5) {
                    Text("Ride your way")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(VuumColor.primaryText)
                    Text(appLocale.homeTagline)
                        .font(.system(size: 13))
                        .foregroundStyle(VuumColor.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 4)

                Image(systemName: "arrow.right")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VuumColor.brand)
            }
            .padding(18)
            .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Models

private enum HubTopTab {
    case rides
    case courier
}

enum HomeSuggestionAction: Equatable {
    case bookRide(preferredTierID: String?)
    case schedule
    case openServices
    case infoOnly
}

struct HomeSuggestion: Identifiable, Equatable {
    let id: String
    let title: String
    let systemImage: String
    let tileColor: Color
    let promoBadge: String?
    let blurb: String
    let action: HomeSuggestionAction

    static let all: [HomeSuggestion] = [
        HomeSuggestion(
            id: "ride",
            title: "Ride",
            systemImage: "car",
            tileColor: Color(white: 0.94),
            promoBadge: nil,
            blurb: "Go anywhere in the city with a standard ride.",
            action: .bookRide(preferredTierID: ServiceProductID.vuum)
        ),
        HomeSuggestion(
            id: ServiceProductID.twoWheels,
            title: "2-Wheels",
            systemImage: "bicycle",
            tileColor: Color(white: 0.94),
            promoBadge: nil,
            blurb: "Quick boda-style trips on two wheels when traffic is heavy.",
            action: .openServices
        ),
        HomeSuggestion(
            id: ServiceProductID.courier,
            title: "Send",
            systemImage: "shippingbox",
            tileColor: Color(white: 0.94),
            promoBadge: nil,
            blurb: "Send packages across town with on-demand pickup.",
            action: .openServices
        ),
        HomeSuggestion(
            id: ServiceProductID.reserve,
            title: "Reserve",
            systemImage: "calendar",
            tileColor: Color(white: 0.94),
            promoBadge: "Plan",
            blurb: "Schedule a pickup for later today or another day.",
            action: .schedule
        ),
        HomeSuggestion(
            id: "comfort",
            title: "Comfort",
            systemImage: "car.side",
            tileColor: Color(white: 0.94),
            promoBadge: nil,
            blurb: "Newer cars with extra space and top-rated drivers.",
            action: .bookRide(preferredTierID: ServiceProductID.comfort)
        ),
        HomeSuggestion(
            id: "xl",
            title: "XL",
            systemImage: "car.2",
            tileColor: Color(white: 0.94),
            promoBadge: nil,
            blurb: "Room for groups of up to six passengers.",
            action: .bookRide(preferredTierID: ServiceProductID.xl)
        ),
        HomeSuggestion(
            id: "executive",
            title: "Executive",
            systemImage: "car.side",
            tileColor: Color(white: 0.94),
            promoBadge: nil,
            blurb: "Premium cars with highly rated professional drivers.",
            action: .bookRide(preferredTierID: ServiceProductID.executive)
        ),
    ]
}

private struct HomeSuggestionSheet: View {
    let suggestion: HomeSuggestion
    let onPrimary: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 14) {
                    Circle()
                        .fill(VuumColor.chipBackground)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: suggestion.systemImage)
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(VuumColor.primaryText)
                        )

                    VStack(alignment: .leading, spacing: 6) {
                        Text(suggestion.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(VuumColor.primaryText)
                        if let badge = suggestion.promoBadge {
                            Text(badge)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(VuumColor.brand, in: Capsule())
                        }
                    }
                }

                Text(suggestion.blurb)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(VuumColor.secondaryText)

                Spacer()

                VuumPrimaryButton(title: primaryTitle) {
                    onPrimary()
                }
            }
            .padding(20)
            .background(VuumColor.pageBackground)
            .navigationTitle(suggestion.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var primaryTitle: String {
        switch suggestion.action {
        case .bookRide: return L10n.Home.whereTo
        case .schedule: return L10n.Home.schedulePickup
        case .openServices: return L10n.Home.browseServices
        case .infoOnly: return L10n.Common.gotIt
        }
    }
}
