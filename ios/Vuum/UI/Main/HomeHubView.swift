import SwiftUI

/// Map-first home: Where to?, pickup, saved/recent places, product shortcuts → trip flow.
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
    @State private var showAdjustPickup = false
    @State private var assignSlot: SavedPlaceKind?
    @State private var serviceDetail: HomeSuggestion?
    @State private var showTwoWheels = false
    @State private var showCourier = false

    private var showLocationDeniedBanner: Bool {
        permissions.isLocationDenied || !location.locationServicesEnabled
    }

    /// Authorized but iOS Precise Location is off — pickup still works, blue-dot is coarse.
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
            guard let place, place.id != tripSession.pickup.id, seen.insert(place.id).inserted else { return }
            places.append(place)
        }
        savedPlaces.recent.forEach { append($0) }
        for receipt in tripSession.tripHistory {
            if let match = appLocale.destinations.first(where: { $0.name == receipt.dropoffName }) {
                append(match)
            }
        }
        for place in appLocale.destinations {
            append(place)
            if places.count >= 5 { break }
        }
        return Array(places.prefix(5))
    }

    private var savedChips: [Place] {
        var chips: [Place] = []
        var seen = Set<String>()
        func append(_ place: Place?) {
            guard let place, place.id != tripSession.pickup.id, seen.insert(place.id).inserted else { return }
            chips.append(place)
        }
        append(savedPlaces.home)
        append(savedPlaces.work)
        savedPlaces.favorites.prefix(3).forEach { append($0) }
        savedPlaces.recent.prefix(4).forEach { append($0) }
        return Array(chips.prefix(6))
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                TripMapLayer()

                VStack(spacing: 0) {
                    hubChrome
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 10)
                        .background(Color.white.opacity(0.94))

                    if showLocationDeniedBanner {
                        PermissionDeniedBanner(
                            icon: "location.slash.fill",
                            title: "Location is off",
                            message: location.locationServicesEnabled
                                ? "Turn on location so Vuum can set your pickup and show nearby drivers."
                                : "Location Services are turned off for this device. Enable them to set your pickup."
                        ) {
                            if let url = permissions.systemSettingsURL {
                                openURL(url)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    } else if let message = location.lastErrorMessage, location.latestLocation == nil {
                        PermissionDeniedBanner(
                            icon: "location.magnifyingglass",
                            title: "Finding your location",
                            message: message,
                            actionTitle: "Try again"
                        ) {
                            location.refreshCurrentLocation()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    } else if showApproximateLocationBanner {
                        PermissionDeniedBanner(
                            icon: "location.circle",
                            title: "Approximate location",
                            message: "Precise location improves pickup accuracy and the map blue-dot. You can allow it for this session.",
                            actionTitle: "Improve accuracy"
                        ) {
                            location.requestPreciseLocationUpgrade()
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    if let cancellation = tripSession.lastCancellation {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: cancellation.wasFree ? "checkmark.circle.fill" : "info.circle.fill")
                                .foregroundStyle(cancellation.wasFree ? Color.green : Color.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(cancellation.summaryLine)
                                    .font(.system(size: 13, weight: .semibold))
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
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.94), in: RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    }

                    Spacer(minLength: 0)

                    HStack {
                        Spacer()
                        recenterButton
                            .padding(.trailing, 16)
                            .padding(.bottom, 10)
                    }

                    homeSheet(maxContentHeight: max(300, geo.size.height * 0.58))
                }
            }
        }
        .preferredColorScheme(.light)
        .onAppear {
            if permissions.shouldShowExplainer {
                showPermissionsExplainer = true
            } else {
                location.requestWhenInUse()
            }
            tripSession.requestMapRecenter()
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
        .sheet(isPresented: $showAdjustPickup) {
            AdjustPickupSheet()
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

    // MARK: - Top chrome

    private var hubChrome: some View {
        HStack(alignment: .center, spacing: 12) {
            HStack(spacing: 0) {
                hubTabButton(.rides, title: L10n.t("home.rides"))
                hubTabButton(.eats, title: L10n.t("home.eats"))
            }

            Spacer(minLength: 8)

            Button {
                showInbox = true
            } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VuumColor.brandInk)
                        .frame(width: 40, height: 40)
                        .background(Color(white: 0.94), in: Circle())

                    if notifications.unreadCount > 0 {
                        Text(notifications.unreadCount > 9 ? "9+" : "\(notifications.unreadCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color(red: 0.85, green: 0.2, blue: 0.25), in: Capsule())
                            .offset(x: 4, y: -2)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Settings.inbox)

            Button {
                showSafety = true
            } label: {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VuumColor.brandInk)
                    .frame(width: 40, height: 40)
                    .background(Color(white: 0.94), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("home.safety"))
        }
    }

    private func hubTabButton(_ tab: HubTopTab, title: String) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { hubTab = tab }
        } label: {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: hubTab == tab ? .bold : .semibold))
                    .foregroundStyle(hubTab == tab ? VuumColor.brandInk : Color(white: 0.55))
                Capsule()
                    .fill(hubTab == tab ? VuumColor.brand : Color.clear)
                    .frame(width: 28, height: 3)
            }
            .padding(.trailing, 18)
        }
        .buttonStyle(.plain)
    }

    private var recenterButton: some View {
        Button {
            location.requestWhenInUse()
            tripSession.updatePickup(from: location.latestLocation)
            tripSession.requestMapRecenter()
        } label: {
            Image(systemName: "location.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VuumColor.brandInk)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.t("home.recenter"))
    }

    // MARK: - Sheet

    private func homeSheet(maxContentHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VuumSheetHandle()
                .padding(.top, 10)
                .padding(.bottom, 14)

            Group {
                switch hubTab {
                case .rides:
                    ScrollView(.vertical, showsIndicators: false) {
                        ridesContent
                    }
                case .eats:
                    ScrollView(.vertical, showsIndicators: false) {
                        eatsContent
                    }
                }
            }
            .frame(maxHeight: maxContentHeight)
            .padding(.horizontal, VuumLayout.pageInset)
            .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.white
                .clipShape(RoundedRectangle(cornerRadius: VuumLayout.radiusSheet, style: .continuous))
                .shadow(color: .black.opacity(0.10), radius: 14, y: -3)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private var ridesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            pickupRow
            whereToRow
            savedPlacesStrip

            if !tripSession.reservedTrips.isEmpty {
                upcomingStrip
            }

            if let zoneNote = tripSession.zoneContext.surchargeMessage {
                zoneAvailabilityBanner(zoneNote)
            }

            if !recentPlaces.isEmpty {
                recentList
            }

            suggestionsSection
            promoBanner
        }
    }

    private func zoneAvailabilityBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: tripSession.zoneContext.isAirportArea ? "airplane.departure" : "bolt.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VuumColor.brandInk)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                if let zone = tripSession.zoneContext.primaryZone {
                    Text(zone.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VuumColor.brandInk)
                }
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(white: 0.4))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color(white: 0.96), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private var eatsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color(white: 0.45))
                Text(L10n.t("home.eats_search"))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(white: 0.35))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(Color(white: 0.93), in: RoundedRectangle(cornerRadius: 28, style: .continuous))

            Text(L10n.t("home.eats_nearby"))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(VuumColor.brandInk)

            VStack(alignment: .leading, spacing: 10) {
                eatsRow(name: "Le Gourmet", meta: "25–40 min · Congolese", badge: L10n.t("home.promo_badge"))
                eatsRow(name: "Pizza House", meta: "20–35 min · Italian", badge: nil)
                eatsRow(name: "Sushi Bar Kin", meta: "30–45 min · Japanese", badge: nil)
            }

            Text(L10n.t("home.eats_expanding"))
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(white: 0.45))
                .padding(.top, 4)
        }
    }

    private func eatsRow(name: String, meta: String, badge: String?) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(VuumColor.brand.opacity(0.18))
                .frame(width: 56, height: 56)
                .overlay(
                    Image(systemName: "fork.knife")
                        .foregroundStyle(VuumColor.brandInk)
                )
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VuumColor.brandInk)
                    if let badge {
                        Text(badge)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(VuumColor.brand, in: Capsule())
                    }
                }
                Text(meta)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(white: 0.45))
            }
            Spacer()
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name), \(meta)")
    }

    // MARK: - Pickup

    private var pickupRow: some View {
        Button {
            showAdjustPickup = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(VuumColor.brand)
                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.t("home.pickup"))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(white: 0.45))
                    Text(tripSession.pickup.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VuumColor.brandInk)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                Text(L10n.t("home.adjust"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VuumColor.brand)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(white: 0.96), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(L10n.t("home.pickup")), \(tripSession.pickup.name)")
        .accessibilityHint(L10n.t("home.adjust"))
    }

    // MARK: - Where to?

    private var whereToRow: some View {
        HStack(spacing: 10) {
            Button {
                tripSession.beginDestinationSelection()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(white: 0.35))
                    Text(L10n.t("home.where_to"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(VuumColor.brandInk)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(white: 0.93), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("home.where_to"))
            .accessibilityHint(L10n.t("home.where_to_hint"))

            Button {
                showSchedule = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "clock")
                        .font(.system(size: 13, weight: .semibold))
                    Text(tripSession.scheduleForLater == nil ? L10n.t("home.now") : L10n.t("home.later"))
                        .font(.system(size: 14, weight: .semibold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .bold))
                }
                .foregroundStyle(VuumColor.brandInk)
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(Color(white: 0.93), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.t("home.schedule_pickup"))
        }
    }

    // MARK: - Saved chips

    private var savedPlacesStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                savedSlotChip(kind: .home, place: savedPlaces.home, emptyTitle: L10n.t("home.add_home"))
                savedSlotChip(kind: .work, place: savedPlaces.work, emptyTitle: L10n.t("home.add_work"))
                ForEach(savedChips.filter {
                    $0.id != savedPlaces.home?.id && $0.id != savedPlaces.work?.id
                }) { place in
                    Button {
                        savedPlaces.recordRecent(place)
                        tripSession.selectDestination(place)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: savedPlaces.systemImage(for: place))
                                .foregroundStyle(VuumColor.brand)
                            Text(savedPlaces.displayTitle(for: place))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(VuumColor.brandInk)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(Color(white: 0.94), in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    @ViewBuilder
    private func savedSlotChip(kind: SavedPlaceKind, place: Place?, emptyTitle: String) -> some View {
        if let place {
            Button {
                savedPlaces.recordRecent(place)
                tripSession.selectDestination(place)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: kind.systemImage)
                        .foregroundStyle(VuumColor.brand)
                    Text(kind.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VuumColor.brandInk)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(white: 0.94), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(kind.title), \(place.name)")
        } else {
            Button {
                assignSlot = kind
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: kind == .home ? "house" : "briefcase")
                        .foregroundStyle(Color(white: 0.45))
                    Text(emptyTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color(white: 0.45))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(white: 0.94), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    private var upcomingStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.t("home.upcoming"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(white: 0.45))
            ForEach(tripSession.reservedTrips.prefix(2)) { trip in
                HStack(spacing: 10) {
                    Image(systemName: "calendar")
                        .foregroundStyle(VuumColor.brand)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(trip.pickupName) → \(trip.dropoffName)")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(VuumColor.brandInk)
                        Text(trip.when.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12))
                            .foregroundStyle(Color(white: 0.45))
                    }
                    Spacer()
                }
                .padding(10)
                .background(Color(white: 0.96), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    // MARK: - Recents

    private var recentList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L10n.t("home.recent"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color(white: 0.45))
                .padding(.bottom, 6)

            ForEach(recentPlaces) { place in
                Button {
                    savedPlaces.recordRecent(place)
                    tripSession.selectDestination(place)
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: savedPlaces.systemImage(for: place))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Color(white: 0.35))
                            .frame(width: 36, height: 36)
                            .background(Color(white: 0.93), in: Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text(savedPlaces.displayTitle(for: place))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(VuumColor.brandInk)
                                .lineLimit(1)
                            Text(place.subtitle)
                                .font(.system(size: 13, weight: .regular))
                                .foregroundStyle(Color(white: 0.45))
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)

                if place.id != recentPlaces.last?.id {
                    Divider()
                        .padding(.leading, 50)
                }
            }
        }
    }

    // MARK: - Suggestions

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.t("home.suggestions"))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(VuumColor.brandInk)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(visibleSuggestions) { item in
                        Button {
                            handleSuggestion(item)
                        } label: {
                            suggestionCard(item)
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
                return tripSession.isServiceAvailable(tierID)
            case .schedule:
                return tripSession.isServiceAvailable(ServiceProductID.reserve)
            case .openServices:
                if suggestion.id == "two-wheels" {
                    return tripSession.isServiceAvailable(ServiceProductID.twoWheels)
                }
                if suggestion.id == "courier" {
                    return tripSession.isServiceAvailable(ServiceProductID.courier)
                }
                return true
            case .infoOnly:
                return true
            }
        }
    }

    private func suggestionCard(_ item: HomeSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(item.tileColor)
                    .frame(width: 88, height: 72)
                    .overlay(
                        Image(systemName: item.systemImage)
                            .font(.system(size: 28, weight: .medium))
                            .foregroundStyle(VuumColor.brandInk)
                    )

                if let badge = item.promoBadge {
                    Text(badge)
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(VuumColor.brand, in: Capsule())
                        .offset(x: 6, y: -6)
                }
            }

            Text(item.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VuumColor.brandInk)
                .frame(width: 88, alignment: .leading)
                .lineLimit(1)
        }
    }

    private func handleSuggestion(_ item: HomeSuggestion) {
        switch item.action {
        case .bookRide(let tierID):
            tripSession.beginDestinationSelection(preferredTierID: tierID)
        case .schedule:
            showSchedule = true
        case .openServices:
            if item.id == "two-wheels" {
                showTwoWheels = true
            } else if item.id == "courier" {
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
            if suggestion.id == "two-wheels" {
                showTwoWheels = true
            } else if suggestion.id == "courier" {
                showCourier = true
            } else {
                MainTabNavigation.openServices()
            }
        case .infoOnly:
            break
        }
    }

    // MARK: - Promo

    private var promoBanner: some View {
        Button {
            tripSession.beginDestinationSelection()
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.t("home.promo_title"))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(VuumColor.brandInk)
                    Text(appLocale.homeTagline)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Color(white: 0.35))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Image(systemName: "car.side.fill")
                    .font(.system(size: 36, weight: .medium))
                    .foregroundStyle(VuumColor.brandInk)
                    .padding(10)
                    .background(VuumColor.brand.opacity(0.35), in: Circle())
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [VuumColor.brand.opacity(0.35), Color(white: 0.96)],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.t("home.promo_title"))
    }
}

// MARK: - Models

private enum HubTopTab {
    case rides
    case eats
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
            systemImage: "car.fill",
            tileColor: Color(white: 0.93),
            promoBadge: nil,
            blurb: "Go anywhere in the city with a standard ride.",
            action: .bookRide(preferredTierID: "vuum")
        ),
        HomeSuggestion(
            id: "two-wheels",
            title: "2-Wheels",
            systemImage: "bicycle",
            tileColor: Color(red: 0.93, green: 0.96, blue: 0.90),
            promoBadge: "Promo",
            blurb: "Quick trips on two wheels when traffic is heavy.",
            action: .openServices
        ),
        HomeSuggestion(
            id: "reserve",
            title: "Reserve",
            systemImage: "calendar",
            tileColor: Color(red: 0.92, green: 0.94, blue: 0.98),
            promoBadge: nil,
            blurb: "Schedule a pickup for later today or another day.",
            action: .schedule
        ),
        HomeSuggestion(
            id: "comfort",
            title: "Comfort",
            systemImage: "car.side.fill",
            tileColor: Color(white: 0.93),
            promoBadge: nil,
            blurb: "Newer cars with extra space and top-rated drivers.",
            action: .bookRide(preferredTierID: "comfort")
        ),
        HomeSuggestion(
            id: "xl",
            title: "Vuum XL",
            systemImage: "car.2.fill",
            tileColor: Color(red: 0.95, green: 0.93, blue: 0.90),
            promoBadge: nil,
            blurb: "Room for groups of up to six passengers.",
            action: .bookRide(preferredTierID: "xl")
        ),
        HomeSuggestion(
            id: "executive",
            title: "Executive",
            systemImage: "sparkles",
            tileColor: Color(red: 0.94, green: 0.94, blue: 0.96),
            promoBadge: nil,
            blurb: "Premium cars with highly rated professional drivers.",
            action: .bookRide(preferredTierID: "executive")
        ),
        HomeSuggestion(
            id: "courier",
            title: "Courier",
            systemImage: "shippingbox.fill",
            tileColor: Color(red: 0.98, green: 0.94, blue: 0.90),
            promoBadge: nil,
            blurb: "Send packages across town with on-demand pickup.",
            action: .openServices
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
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(suggestion.tileColor)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Image(systemName: suggestion.systemImage)
                                .font(.system(size: 28, weight: .medium))
                                .foregroundStyle(VuumColor.brandInk)
                        )
                    VStack(alignment: .leading, spacing: 6) {
                        Text(suggestion.title)
                            .font(.system(size: 22, weight: .bold))
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
        case .bookRide: return L10n.t("home.where_to")
        case .schedule: return L10n.t("home.schedule_pickup")
        case .openServices: return L10n.t("home.browse_services")
        case .infoOnly: return L10n.t("common.got_it")
        }
    }
}

