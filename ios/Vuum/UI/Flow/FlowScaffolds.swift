import SwiftUI

struct TripMapLayer: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var location: RiderLocationManager

    var body: some View {
        VuumMapView(
            cameraTarget: tripSession.mapCamera,
            zoom: tripSession.phase == .idle
                ? (preferences.lowDataMode ? 13 : 14)
                : (preferences.lowDataMode ? 12.5 : 13.5),
            pins: tripSession.mapPins,
            route: preferences.lowDataMode
                ? simplifiedRoute(tripSession.mapRoute)
                : tripSession.mapRoute,
            fitCoordinates: tripSession.mapFitCoordinates,
            followDriver: tripSession.shouldFollowDriverOnMap,
            cameraFocusNonce: tripSession.mapCameraFocusNonce,
            showsUserLocation: location.isAuthorized,
            showsTraffic: MapTrafficSettings.shouldShowTrafficLayer(lowDataMode: preferences.lowDataMode),
            lowDataMode: preferences.lowDataMode
        )
        .onAppear { location.startUpdatingIfAllowed() }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mapAccessibilityLabel)
        .accessibilityHint("Shows pickup, destination, route, and nearby vehicles")
    }

    /// Downsample polyline points in lite mode to cut draw cost on weak networks.
    private func simplifiedRoute(_ route: [GeoPoint]) -> [GeoPoint] {
        guard route.count > 8 else { return route }
        var out: [GeoPoint] = []
        let step = max(2, route.count / 12)
        for i in stride(from: 0, to: route.count, by: step) {
            out.append(route[i])
        }
        if let last = route.last, out.last != last {
            out.append(last)
        }
        return out
    }

    private var mapAccessibilityLabel: String {
        if MapBootstrap.surface == .unavailable {
            return L10n.Maps.unavailableTitle
        }
        switch tripSession.phase {
        case .idle:
            return L10n.Maps.a11yHome
        case .selectingDestination, .choosingRide:
            return L10n.Maps.a11yPreview
        case .searching:
            return L10n.Maps.a11yMatching
        case .matched, .driverEnRoute, .driverArrived:
            return L10n.Maps.a11yApproach
        case .inTrip:
            return L10n.Maps.a11yActive
        case .completed:
            return L10n.Maps.a11yCompleted
        }
    }
}

struct HomeMapScaffoldView: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var location: RiderLocationManager
    @EnvironmentObject private var permissions: PermissionCenter
    @EnvironmentObject private var savedPlaces: SavedPlacesStore
    @EnvironmentObject private var appLocale: AppLocale
    @Environment(\.openURL) private var openURL
    @State private var showSafety = false
    @State private var showSchedule = false
    @State private var showAdjustPickup = false
    @State private var showPermissionsExplainer = false
    @State private var assignSlot: SavedPlaceKind?

    private var homeSuggestionChips: [Place] {
        var chips: [Place] = []
        var seen = Set<String>()
        func append(_ place: Place?) {
            guard let place, place.id != tripSession.pickup.id, !seen.contains(place.id) else { return }
            seen.insert(place.id)
            chips.append(place)
        }
        append(savedPlaces.home)
        append(savedPlaces.work)
        savedPlaces.favorites.prefix(3).forEach { append($0) }
        savedPlaces.recent.prefix(4).forEach { append($0) }
        if chips.count < 4 {
            appLocale.destinations.prefix(6).forEach { append($0) }
        }
        return Array(chips.prefix(6))
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TripMapLayer()

            VStack {
                HStack {
                    Spacer()
                    Button {
                        showSafety = true
                    } label: {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(VuumColor.primaryText)
                            .frame(width: 44, height: 44)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Safety")
                    .accessibilityHint("Opens safety tools and emergency options")
                    .padding(.trailing, 16)
                    .padding(.top, 8)
                }
                Spacer()
            }

            VuumSheetChrome(title: nil) {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Vuum")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(VuumColor.primaryText)

                    Text(L10n.t("home.tagline"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(VuumColor.secondaryText)

                    Button {
                        showAdjustPickup = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(VuumColor.brand)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.t("home.pickup"))
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(VuumColor.secondaryText)
                                Text(tripSession.pickup.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(VuumColor.primaryText)
                            }
                            Spacer()
                            Text(L10n.t("home.adjust"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(VuumColor.brand)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if !tripSession.reservedTrips.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(L10n.t("home.upcoming"))
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(VuumColor.secondaryText)
                            ForEach(tripSession.reservedTrips.prefix(2)) { trip in
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundStyle(VuumColor.brand)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(trip.pickupName) ? \(trip.dropoffName)")
                                            .font(.system(size: 14, weight: .semibold))
                                        if !trip.stopNames.isEmpty {
                                            Text("via \(trip.stopNames.joined(separator: ", "))")
                                                .font(.system(size: 12))
                                                .foregroundStyle(VuumColor.secondaryText)
                                        }
                                        Text(trip.when.formatted(date: .abbreviated, time: .shortened))
                                            .font(.system(size: 12))
                                            .foregroundStyle(VuumColor.secondaryText)
                                    }
                                    Spacer()
                                    Text(
                                        AppLocale.formatFareTotal(
                                            cdf: trip.priceCDF,
                                            usd: trip.priceUSD,
                                            market: AppLocale.market(countryCode: session.countryCode)
                                        )
                                    )
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .padding(10)
                                .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            tripSession.beginDestinationSelection()
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(VuumColor.secondaryText)
                                Text(L10n.t("home.where_to"))
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(VuumColor.primaryText)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(Color(white: 0.93), in: RoundedRectangle(cornerRadius: 28, style: .continuous))
                        }
                        .buttonStyle(.plain)

                        Button {
                            showSchedule = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                Text(tripSession.scheduleForLater == nil ? L10n.t("home.now") : L10n.t("home.later"))
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VuumColor.primaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .background(Color(white: 0.93), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            homeSavedSlotChip(
                                kind: .home,
                                place: savedPlaces.home,
                                emptyTitle: "Add Home"
                            )
                            homeSavedSlotChip(
                                kind: .work,
                                place: savedPlaces.work,
                                emptyTitle: "Add Work"
                            )
                            ForEach(homeSuggestionChips.filter {
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
                                            .foregroundStyle(VuumColor.primaryText)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .background(VuumColor.chipBackground, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .onAppear {
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
        .sheet(isPresented: $showSafety) {
            SafetyToolkitView()
        }
        .sheet(isPresented: $showSchedule) {
            ScheduleRideSheet()
        }
        .sheet(isPresented: $showAdjustPickup) {
            AdjustPickupSheet()
        }
        .sheet(item: $assignSlot) { kind in
            AssignSavedPlaceSheet(kind: kind)
        }
    }

    @ViewBuilder
    private func homeSavedSlotChip(
        kind: SavedPlaceKind,
        place: Place?,
        emptyTitle: String
    ) -> some View {
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
                        .foregroundStyle(VuumColor.primaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(VuumColor.chipBackground, in: Capsule())
            }
            .buttonStyle(.plain)
        } else {
            Button {
                assignSlot = kind
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: kind == .home ? "house" : "briefcase")
                        .foregroundStyle(VuumColor.secondaryText)
                    Text(emptyTitle)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VuumColor.secondaryText)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(VuumColor.chipBackground, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }
}

struct PermissionsExplainerSheet: View {
    var onContinue: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(L10n.Permissions.intro)
                        .font(.system(size: 15))
                        .foregroundStyle(VuumColor.secondaryText)

                    permissionRow(
                        icon: "location.fill",
                        title: L10n.Permissions.location,
                        detail: L10n.Permissions.locationDetail
                    )
                    permissionRow(
                        icon: "bell.fill",
                        title: L10n.Permissions.notifications,
                        detail: L10n.Permissions.notificationsDetail
                    )
                    permissionRow(
                        icon: "mic.fill",
                        title: L10n.Permissions.microphone,
                        detail: L10n.Permissions.microphoneDetail
                    )

                    Text(L10n.Permissions.changeAnytime)
                        .font(.system(size: 13))
                        .foregroundStyle(VuumColor.secondaryText)
                }
                .padding(20)
            }
            .navigationTitle(L10n.Permissions.title)
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                VuumPrimaryButton(title: L10n.Common.continue) {
                    onContinue()
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
            }
        }
        .presentationDetents([.large])
        .interactiveDismissDisabled()
    }

    private func permissionRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(VuumColor.brandInk)
                .frame(width: 40, height: 40)
                .background(VuumColor.brand.opacity(0.25), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VuumColor.primaryText)
                Text(detail)
                    .font(.system(size: 14))
                    .foregroundStyle(VuumColor.secondaryText)
            }
        }
    }
}

struct DestinationScaffoldView: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var savedPlaces: SavedPlacesStore
    @EnvironmentObject private var appLocale: AppLocale
    @StateObject private var placesSearch = PlacesSearchController()
    @State private var query = ""
    @State private var assignSlot: SavedPlaceKind?

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isResolving: Bool { placesSearch.isResolving }

    private func isAvailable(_ place: Place) -> Bool {
        place.id != tripSession.pickup.id
            && place.id != tripSession.dropoff?.id
            && !tripSession.stops.contains(where: { $0.id == place.id })
    }

    private func matchesQuery(_ place: Place) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return true }
        return place.name.localizedCaseInsensitiveContains(q)
            || place.subtitle.localizedCaseInsensitiveContains(q)
    }

    private var filteredSuggestions: [Place] {
        guard !isSearching else { return [] }
        let savedIds: Set<String> = {
            var ids = Set(savedPlaces.favorites.map(\.id))
            ids.formUnion(savedPlaces.recent.map(\.id))
            if let home = savedPlaces.home { ids.insert(home.id) }
            if let work = savedPlaces.work { ids.insert(work.id) }
            return ids
        }()
        return appLocale.destinations.filter {
            isAvailable($0) && !savedIds.contains($0.id)
        }
    }

    private var filteredRecent: [Place] {
        let homeWork = Set([savedPlaces.home?.id, savedPlaces.work?.id].compactMap { $0 })
        let favoriteIds = Set(savedPlaces.favorites.map(\.id))
        return savedPlaces.recent.filter {
            isAvailable($0)
                && matchesQuery($0)
                && !homeWork.contains($0.id)
                && !favoriteIds.contains($0.id)
        }
    }

    private var filteredFavorites: [Place] {
        let homeWork = Set([savedPlaces.home?.id, savedPlaces.work?.id].compactMap { $0 })
        return savedPlaces.favorites.filter {
            isAvailable($0) && matchesQuery($0) && !homeWork.contains($0.id)
        }
    }

    private var sheetTitle: String {
        tripSession.isAddingStop ? L10n.Destination.addStop : L10n.Destination.choose
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TripMapLayer()

            VuumSheetChrome(title: sheetTitle) {
                VStack(spacing: 12) {
                    if tripSession.isAddingStop {
                        Text("Stop \(tripSession.stops.count + 1) of \(TripSession.maxStops)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(VuumColor.secondaryText)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(VuumColor.secondaryText)
                        TextField(
                            tripSession.isAddingStop ? L10n.Destination.searchStop : L10n.Destination.searchPlaces,
                            text: $query
                        )
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        if isResolving || placesSearch.isQueryPending {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                    .padding(12)
                    .background(VuumColor.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                    if let status = placesSearch.statusMessage {
                        HStack(alignment: .top, spacing: 10) {
                            Text(status)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(VuumColor.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            if placesSearch.canRetry {
                                Button(L10n.t("status.retry")) {
                                    placesSearch.retryLastSearch()
                                }
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(VuumColor.brand)
                            }
                        }
                    }

                    if !tripSession.stops.isEmpty, !tripSession.isAddingStop {
                        stopsPreview
                    }

                    ScrollView {
                        VStack(spacing: 0) {
                            if !isSearching {
                                savedSlotsSection
                            }

                            if !filteredFavorites.isEmpty {
                                sectionHeader(L10n.Destination.favorites)
                                placeRows(filteredFavorites, leadingIcon: { _ in "star.fill" })
                            }

                            if !filteredRecent.isEmpty {
                                sectionHeader(L10n.Destination.recent)
                                placeRows(filteredRecent, leadingIcon: { _ in "clock.fill" })
                            }

                            if isSearching {
                                sectionHeader(L10n.Destination.results)
                                if placesSearch.isQueryPending, placesSearch.suggestions.isEmpty {
                                    Text(L10n.Destination.searchingPlaces)
                                        .font(.system(size: 14))
                                        .foregroundStyle(VuumColor.secondaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 12)
                                } else if !placesSearch.suggestions.isEmpty {
                                    suggestionRows(placesSearch.suggestions)
                                } else {
                                    Text(L10n.Destination.noMatchingPlaces)
                                        .font(.system(size: 14))
                                        .foregroundStyle(VuumColor.secondaryText)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.vertical, 12)
                                }
                            } else if !filteredSuggestions.isEmpty {
                                sectionHeader(L10n.Destination.suggestions)
                                placeRows(
                                    filteredSuggestions,
                                    leadingIcon: { _ in
                                        tripSession.isAddingStop ? "plus.circle.fill" : "mappin.circle.fill"
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 320)

                    if tripSession.isAddingStop {
                        Button(L10n.Common.cancel) {
                            placesSearch.abandonSession()
                            tripSession.cancelAddingStop()
                        }
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(VuumColor.secondaryText)
                        .padding(.top, 4)
                    } else {
                        Button(L10n.Common.cancel) {
                            placesSearch.abandonSession()
                            tripSession.resetToHome()
                        }
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(VuumColor.secondaryText)
                        .padding(.top, 4)
                    }
                }
                .sheet(item: $assignSlot) { kind in
                    AssignSavedPlaceSheet(kind: kind)
                }
                .onAppear {
                    placesSearch.beginSession()
                }
                .onChange(of: query) { _, newValue in
                    placesSearch.scheduleSearch(
                        newValue,
                        bias: tripSession.pickup.coordinate,
                        market: appLocale.fareMarket,
                        isPlaceAvailable: isAvailable
                    )
                }
                .onDisappear {
                    placesSearch.tearDown()
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    private func selectSuggestion(_ suggestion: PlacesSearchService.PlaceSuggestion) {
        Task {
            let place = await placesSearch.resolve(suggestion)
            guard let place, isAvailable(place) else { return }
            savedPlaces.recordRecent(place)
            placesSearch.beginSessionAfterSelection()
            query = ""
            tripSession.selectDestination(place)
        }
    }

    private var stopsPreview: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Stops")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VuumColor.secondaryText)
            ForEach(Array(tripSession.stops.enumerated()), id: \.element.id) { index, stop in
                HStack(spacing: 8) {
                    Text("\(index + 1). \(stop.name)")
                        .font(.system(size: 14, weight: .medium))
                    Spacer(minLength: 4)
                    if index > 0 {
                        Button {
                            tripSession.moveStopUp(stop)
                        } label: {
                            Image(systemName: "chevron.up.circle.fill")
                                .foregroundStyle(VuumColor.brand)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Move stop \(index + 1) earlier")
                    }
                    if index < tripSession.stops.count - 1 {
                        Button {
                            tripSession.moveStopDown(stop)
                        } label: {
                            Image(systemName: "chevron.down.circle.fill")
                                .foregroundStyle(VuumColor.brand)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Move stop \(index + 1) later")
                    }
                    Button {
                        tripSession.removeStop(stop)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove stop \(index + 1)")
                    .accessibilityHint("Removes \(stop.name) from this trip")
                }
            }
        }
        .padding(10)
        .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 12))
    }

    private var savedSlotsSection: some View {
        VStack(spacing: 0) {
            sectionHeader("Saved places")
            savedSlotRow(
                kind: .home,
                place: savedPlaces.home,
                emptyTitle: "Add Home",
                emptySubtitle: "Save an address for quick trips home"
            )
            Divider()
            savedSlotRow(
                kind: .work,
                place: savedPlaces.work,
                emptyTitle: "Add Work",
                emptySubtitle: "Save your workplace"
            )
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(VuumColor.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
            .padding(.bottom, 4)
    }

    private func savedSlotRow(
        kind: SavedPlaceKind,
        place: Place?,
        emptyTitle: String,
        emptySubtitle: String
    ) -> some View {
        Button {
            if let place, isAvailable(place) {
                savedPlaces.recordRecent(place)
                tripSession.selectDestination(place)
            } else {
                assignSlot = kind
            }
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: place == nil
                      ? (kind == .home ? "house" : "briefcase")
                      : kind.systemImage)
                    .foregroundStyle(VuumColor.brand)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(place == nil ? emptyTitle : kind.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundStyle(VuumColor.primaryText)
                    Text(place?.name ?? emptySubtitle)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(VuumColor.secondaryText)
                }
                Spacer()
                if place != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(VuumColor.secondaryText)
                }
            }
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    private func suggestionRows(_ items: [PlacesSearchService.PlaceSuggestion]) -> some View {
        VStack(spacing: 0) {
            ForEach(items) { suggestion in
                Button {
                    selectSuggestion(suggestion)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: suggestion.systemImage)
                            .foregroundStyle(VuumColor.brand)
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.primaryText)
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundStyle(VuumColor.primaryText)
                            if !suggestion.compactSubtitle.isEmpty {
                                Text(suggestion.compactSubtitle)
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundStyle(VuumColor.secondaryText)
                                    .lineLimit(2)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .disabled(isResolving)

                if suggestion.id != items.last?.id {
                    Divider()
                }
            }
        }
    }

    private func placeRows(
        _ places: [Place],
        leadingIcon: @escaping (Place) -> String
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(places) { place in
                HStack(alignment: .top, spacing: 4) {
                    Button {
                        savedPlaces.recordRecent(place)
                        tripSession.selectDestination(place)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: leadingIcon(place))
                                .foregroundStyle(VuumColor.brand)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name)
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                                    .foregroundStyle(VuumColor.primaryText)
                                Text(place.subtitle)
                                    .font(.system(size: 13, weight: .regular, design: .rounded))
                                    .foregroundStyle(VuumColor.secondaryText)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)

                    Button {
                        savedPlaces.toggleFavorite(place)
                    } label: {
                        Image(systemName: savedPlaces.isFavorite(place) ? "star.fill" : "star")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(savedPlaces.isFavorite(place) ? VuumColor.brand : VuumColor.secondaryText)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)
                }

                if place.id != places.last?.id {
                    Divider()
                }
            }
        }
    }
}

/// Pick a place for Home or Work via Places autocomplete (local catalog fallback).
struct AssignSavedPlaceSheet: View {
    @EnvironmentObject private var savedPlaces: SavedPlacesStore
    let kind: SavedPlaceKind

    var body: some View {
        PlaceSearchPickerSheet(
            title: kind == .home ? "Set Home" : "Set Work",
            allowClear: (kind == .home && savedPlaces.home != nil)
                || (kind == .work && savedPlaces.work != nil),
            onClear: {
                switch kind {
                case .home: savedPlaces.setHome(nil)
                case .work: savedPlaces.setWork(nil)
                default: break
                }
            },
            onSelect: { place in
                switch kind {
                case .home: savedPlaces.setHome(place)
                case .work: savedPlaces.setWork(place)
                default: break
                }
            }
        )
    }
}

struct SavedPlacesManageView: View {
    @EnvironmentObject private var savedPlaces: SavedPlacesStore
    @State private var assignSlot: SavedPlaceKind?

    var body: some View {
        List {
            Section {
                savedManageRow(kind: .home, place: savedPlaces.home)
                savedManageRow(kind: .work, place: savedPlaces.work)
            }

            Section("Favorites") {
                if savedPlaces.favorites.isEmpty {
                    Text("Star places from the destination list to save them here.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(savedPlaces.favorites) { place in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name).font(.system(size: 15, weight: .semibold))
                                Text(place.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button {
                                savedPlaces.removeFavorite(place)
                            } label: {
                                Image(systemName: "star.slash")
                                    .foregroundStyle(VuumColor.secondaryText)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .navigationTitle("Saved places")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $assignSlot) { kind in
            AssignSavedPlaceSheet(kind: kind)
        }
    }

    private func savedManageRow(kind: SavedPlaceKind, place: Place?) -> some View {
        Button {
            assignSlot = kind
        } label: {
            HStack(spacing: 12) {
                Image(systemName: kind.systemImage)
                    .foregroundStyle(VuumColor.brandInk)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VuumColor.primaryText)
                    Text(place?.name ?? "Not set")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct RideOptionsScaffoldView: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var session: SessionStore
    @State private var showAdjustPickup = false

    private var market: AppLocale.Market {
        AppLocale.market(countryCode: session.countryCode)
    }

    private var paymentChoices: [PaymentMethod] {
        tripSession.bookOnCompanyWallet
            ? [.companyWallet]
            : AppLocale.ridePaymentMethods(for: market)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            TripMapLayer()

            VuumSheetChrome(title: "Choose a ride") {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: 12) {
                            if let cancellation = tripSession.lastCancellation {
                                cancellationBanner(cancellation)
                            }
                            routeHeader
                            if tripSession.surgeState.isActive
                                || tripSession.zoneContext.surchargeMessage != nil {
                                surgeBanner
                            }
                            ForEach(tripSession.availableTiers) { tier in
                                tierRow(tier)
                            }
                            if tripSession.selectedTier != nil, let preview = tripSession.farePreview {
                                farePreviewCard(preview)
                            }
                            fareNegotiationSection
                            promoSection
                            preferencesSection
                            CorporateTripOptionsView()
                        }
                        .padding(.bottom, 4)
                    }
                    .frame(maxHeight: 320)

                    Divider()
                        .padding(.vertical, 10)

                    VStack(spacing: 12) {
                        forMeSwitcher

                        if tripSession.bookForSomeoneElse {
                            passengerFields
                        }

                        PaymentMethodPickerRow()

                        VuumPrimaryButton(
                            title: tripSession.scheduleForLater == nil
                                ? "Confirm \(tripSession.selectedTier?.name ?? "ride")"
                                : "Reserve \(tripSession.selectedTier?.name ?? "ride")",
                            enabled: tripSession.canConfirmRequest
                        ) {
                            tripSession.confirmRequest()
                        }

                        HStack(spacing: 16) {
                            Button("Adjust pickup") {
                                showAdjustPickup = true
                            }
                            Button("Change destination") {
                                tripSession.changeDestination()
                            }
                        }
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(VuumColor.secondaryText)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .sheet(isPresented: $showAdjustPickup) {
            AdjustPickupSheet()
        }
        .alert(
            "Ride reserved",
            isPresented: Binding(
                get: { tripSession.reservationConfirmationMessage != nil },
                set: { if !$0 { tripSession.clearReservationConfirmation() } }
            )
        ) {
            Button("OK", role: .cancel) {
                tripSession.clearReservationConfirmation()
            }
        } message: {
            Text(tripSession.reservationConfirmationMessage ?? "")
        }
    }

    // MARK: - Route header

    @ViewBuilder
    private var routeHeader: some View {
        if let dropoff = tripSession.dropoff {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Button {
                            showAdjustPickup = true
                        } label: {
                            HStack(spacing: 4) {
                                Text(tripSession.pickup.name)
                                    .font(.system(size: 13, weight: .medium))
                                Image(systemName: "pencil")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(VuumColor.secondaryText)
                        }
                        .buttonStyle(.plain)

                        if !tripSession.stops.isEmpty {
                            ForEach(Array(tripSession.stops.enumerated()), id: \.element.id) { index, stop in
                                HStack(spacing: 6) {
                                    Text("Stop \(index + 1)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(VuumColor.brand)
                                    Text(stop.name)
                                        .font(.system(size: 13, weight: .medium))
                                        .lineLimit(1)
                                    Spacer(minLength: 4)
                                    if index > 0 {
                                        Button {
                                            tripSession.moveStopUp(stop)
                                        } label: {
                                            Image(systemName: "chevron.up.circle.fill")
                                                .font(.system(size: 14))
                                                .foregroundStyle(VuumColor.brand)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Move stop earlier")
                                    }
                                    if index < tripSession.stops.count - 1 {
                                        Button {
                                            tripSession.moveStopDown(stop)
                                        } label: {
                                            Image(systemName: "chevron.down.circle.fill")
                                                .font(.system(size: 14))
                                                .foregroundStyle(VuumColor.brand)
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Move stop later")
                                    }
                                    Button {
                                        tripSession.removeStop(stop)
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(VuumColor.secondaryText)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Remove stop")
                                }
                            }
                        }

                        Text("To \(dropoff.name)")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    Spacer(minLength: 8)
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(TripGeo.formatDistance(tripSession.tripRouteDistanceMeters))
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(VuumColor.secondaryText)
                        if !tripSession.stops.isEmpty {
                            Text("+\(tripSession.stops.count * TripSession.waitMinutesPerStop) min wait")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(VuumColor.brand)
                        }
                    }
                }

                if tripSession.stops.count < TripSession.maxStops {
                    Button {
                        tripSession.beginAddingStop()
                    } label: {
                        Label("Add a stop", systemImage: "plus.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(VuumColor.brand)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Tier rows

    private func tierRow(_ tier: RideTier) -> some View {
        let selected = tripSession.selectedTier?.id == tier.id
        let amounts = discountedAmounts(for: tier)
        let hasPromo = tripSession.appliedPromoDiscountCDF > 0

        return Button {
            tripSession.chooseTier(tier)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: tier.systemImage)
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(VuumColor.primaryText)
                    .frame(width: 52, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(tier.name)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                        HStack(spacing: 3) {
                            Image(systemName: "person.fill")
                                .font(.system(size: 10, weight: .semibold))
                            Text("\(tier.capacity)")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(VuumColor.secondaryText)
                    }

                    HStack(spacing: 8) {
                        RideClassETABadge(minutes: tier.classETABadgeMinutes, compact: true)
                        Text(tier.detail)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(VuumColor.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(formatPrice(cdf: amounts.cdf, usd: amounts.usd))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(VuumColor.primaryText)
                        .multilineTextAlignment(.trailing)

                    if hasPromo {
                        Text(formatPrice(cdf: tier.priceCDF, usd: tier.priceUSD))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(VuumColor.secondaryText)
                            .strikethrough(true, color: VuumColor.secondaryText)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? VuumColor.brand.opacity(0.10) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        selected ? VuumColor.brand : VuumColor.divider,
                        lineWidth: selected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Promo

    private var surgeBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: tripSession.zoneContext.isAirportArea ? "airplane.departure" : "bolt.fill")
                .font(.system(size: 14, weight: .bold))
            VStack(alignment: .leading, spacing: 2) {
                Text(surgeBannerTitle)
                    .font(.system(size: 14, weight: .semibold))
                Text(surgeBannerSubtitle)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VuumColor.secondaryText)
            }
            Spacer(minLength: 8)
            if tripSession.surgeState.isActive {
                Text(String(format: "%.2g?", tripSession.surgeState.multiplier))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(VuumColor.brand.opacity(0.18), in: Capsule())
            }
        }
        .foregroundStyle(VuumColor.primaryText)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(VuumColor.brand.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(surgeAccessibilityLabel)
    }

    private var surgeBannerTitle: String {
        // Prefer demand/surge wording over a generic zone place-name so choose-ride
        // stays clear when live map pickup sits inside overlapping geofences.
        if tripSession.surgeState.isActive {
            let label = tripSession.surgeState.label.trimmingCharacters(in: .whitespacesAndNewlines)
            if !label.isEmpty { return label }
        }
        if let zone = tripSession.zoneContext.primaryZone {
            switch zone.kind {
            case .highDemand, .downtown:
                return zone.kind.displayTitle
            case .airport:
                return zone.name
            default:
                return zone.name
            }
        }
        return "High demand"
    }

    private var surgeBannerSubtitle: String {
        if let message = tripSession.zoneContext.surchargeMessage {
            return message
        }
        if tripSession.surgeState.isActive {
            return String(format: "%.2g? fare multiplier applied", tripSession.surgeState.multiplier)
        }
        return "Higher fares may apply in this area"
    }

    private var surgeAccessibilityLabel: String {
        "\(surgeBannerTitle). \(surgeBannerSubtitle)"
    }

    private func farePreviewCard(_ fare: FareBreakdown) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fare breakdown")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VuumColor.secondaryText)
            farePreviewRow("Base fare", fare.baseFareCDF)
            farePreviewRow("Distance", fare.distanceFareCDF)
            farePreviewRow("Time", fare.timeFareCDF)
            if fare.waitingFareCDF > 0 {
                farePreviewRow("Waiting", fare.waitingFareCDF)
            }
            if fare.isSurgeActive {
                farePreviewRow(
                    String(format: "High demand ? %.2g?", fare.surgeMultiplier),
                    fare.surgeFareCDF
                )
            }
            if fare.tollCDF > 0 {
                farePreviewRow("Airport / toll", fare.tollCDF)
            }
            if fare.serviceFeeCDF > 0 {
                farePreviewRow("Service fee", fare.serviceFeeCDF)
            }
            if fare.taxCDF > 0 {
                farePreviewRow(market == .kenya ? "Tax" : "TVA 16%", fare.taxCDF)
            }
            if fare.discountCDF > 0 {
                HStack {
                    Text("Promo")
                        .foregroundStyle(VuumColor.secondaryText)
                    Spacer()
                    Text(formatLocalDiscount(fare.discountCDF))
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }
                .font(.system(size: 13))
            }
            if fare.minimumFareApplied {
                Text("Minimum fare applied")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VuumColor.secondaryText)
            }
            if let tier = tripSession.selectedTier {
                Text(TripEmissions.displayLabel(distanceKm: fare.distanceKm, vehicleClass: tier.vehicleClass))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VuumColor.secondaryText)
            }
            Divider()
            HStack {
                Text("Estimated total")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Text(formatPrice(cdf: fare.totalCDF, usd: fare.totalUSD))
                    .font(.system(size: 14, weight: .bold))
            }
        }
        .padding(14)
        .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var fareNegotiationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: Binding(
                get: { tripSession.negotiateFareEnabled },
                set: { tripSession.setNegotiateFareEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Suggest a fare")
                        .font(.system(size: 14, weight: .medium))
                    Text("Optional ? driver may accept within ?15%")
                        .font(.caption)
                        .foregroundStyle(VuumColor.secondaryText)
                }
            }
            .tint(VuumColor.brand)

            if tripSession.negotiateFareEnabled, let target = tripSession.negotiatedTargetCDF {
                let step = market == .kenya ? 50 : 500
                Stepper {
                    Text(AppLocale.formatPrimary(local: target, market: market))
                        .font(.system(size: 15, weight: .semibold))
                } onIncrement: {
                    tripSession.setNegotiatedTargetCDF(target + step)
                } onDecrement: {
                    tripSession.setNegotiatedTargetCDF(target - step)
                }
            }
        }
        .padding(12)
        .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func farePreviewRow(_ title: String, _ amount: Int) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(VuumColor.secondaryText)
            Spacer()
            Text(AppLocale.formatPrimary(local: amount, market: market))
                .fontWeight(.medium)
        }
        .font(.system(size: 13))
    }

    private var promoSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                TextField("Promo code", text: $tripSession.promoCode)
                    .textInputAutocapitalization(.characters)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(VuumColor.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Button("Apply") {
                    tripSession.applyPromo()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VuumColor.brand)
            }
            promoStatusLine
        }
    }

    @ViewBuilder
    private var promoStatusLine: some View {
        switch tripSession.promoStatus {
        case .applied(_, let discount, let title):
            HStack {
                Text("\(title) ? \(formatLocalDiscount(discount))")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.green)
                Spacer()
                Button("Remove") {
                    tripSession.clearPromo()
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(VuumColor.secondaryText)
            }
        case .invalid:
            Text("This promo code isn?t valid")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.orange)
        case .expired:
            Text("This promo code has expired")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.orange)
        case .notEligible(let reason):
            Text(reason)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.orange)
        case .idle:
            EmptyView()
        }
    }

    // MARK: - Preferences

    private var preferencesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Ride preferences")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(VuumColor.secondaryText)

            Toggle(isOn: $tripSession.preferQuietRide) {
                Label("Quiet ride", systemImage: "speaker.slash.fill")
                    .font(.system(size: 14, weight: .medium))
            }
            .tint(VuumColor.brand)

            TextField("Accessibility notes for your driver", text: $tripSession.accessibilityNotes, axis: .vertical)
                .lineLimit(2...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(VuumColor.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .padding(12)
        .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - For me / For others

    private var forMeSwitcher: some View {
        HStack(spacing: 0) {
            passengerModeChip(
                title: "For me",
                systemImage: "person.fill",
                selected: !tripSession.bookForSomeoneElse
            ) {
                tripSession.bookForSomeoneElse = false
            }
            passengerModeChip(
                title: "For others",
                systemImage: "person.2.fill",
                selected: tripSession.bookForSomeoneElse
            ) {
                tripSession.bookForSomeoneElse = true
            }
        }
        .padding(3)
        .background(VuumColor.chipBackground, in: Capsule())
    }

    private func passengerModeChip(
        title: String,
        systemImage: String,
        selected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundStyle(selected ? VuumColor.brandInk : VuumColor.secondaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(selected ? VuumColor.brand : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private var passengerFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Passenger name", text: $tripSession.passengerName)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(VuumColor.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            TextField("Passenger phone", text: $tripSession.passengerPhone)
                .keyboardType(.phonePad)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(VuumColor.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            if !tripSession.canConfirmRequest {
                Text("Enter the passenger?s name and phone to continue.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VuumColor.secondaryText)
            }
        }
    }

    // MARK: - Payment

    private var paymentRow: some View {
        Menu {
            ForEach(paymentChoices) { method in
                Button {
                    tripSession.paymentMethod = method
                } label: {
                    Label(method.title, systemImage: method.systemImage)
                }
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: tripSession.paymentMethod.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(VuumColor.brandInk)
                    .frame(width: 28)
                Text(tripSession.paymentMethod.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VuumColor.primaryText)
                Spacer()
                Text("Change")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VuumColor.brand)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(VuumColor.secondaryText)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .accessibilityLabel("Payment method \(tripSession.paymentMethod.title)")
        .accessibilityHint("Opens payment options")
    }

    // MARK: - Currency

    private func discountedAmounts(for tier: RideTier) -> (cdf: Int, usd: Double) {
        let discount = tripSession.appliedPromoDiscountCDF
        let minimum = AppLocale.minimumFareLocal
        guard discount > 0 else { return (tier.priceCDF, tier.priceUSD) }
        let cdf = max(tier.priceCDF - discount, minimum)
        let usd = tier.priceCDF > 0
            ? tier.priceUSD * (Double(cdf) / Double(tier.priceCDF))
            : tier.priceUSD
        return (cdf, usd)
    }

    private func formatPrice(cdf: Int, usd: Double) -> String {
        AppLocale.formatTierPrice(cdf: cdf, usd: usd, market: market)
    }

    private func formatLocalDiscount(_ amount: Int) -> String {
        "-\(Money.local(amount, market: market == .kenya ? .kenya : .drc).formatted)"
    }
}

struct AdjustPickupSheet: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var location: RiderLocationManager
    @Environment(\.dismiss) private var dismiss

    @State private var showPlaceSearch = false

    private var suggestions: [Place] {
        tripSession.nearbyPickupSuggestions()
    }

    private var searchBias: GeoPoint {
        if let loc = location.latestLocation {
            return GeoPoint(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
        }
        return tripSession.pickup.coordinate
    }

    var body: some View {
        VStack(spacing: 0) {
            VuumSheetChrome(title: "Adjust pickup") {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Current ? \(tripSession.pickup.name)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(VuumColor.secondaryText)

                    Button {
                        showPlaceSearch = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(VuumColor.brand)
                            Text(L10n.Destination.searchPlaces)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(VuumColor.primaryText)
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(VuumColor.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    VStack(spacing: 0) {
                        ForEach(suggestions) { place in
                            Button {
                                tripSession.selectPickup(place)
                                dismiss()
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundStyle(VuumColor.brand)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(place.name)
                                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                                            .foregroundStyle(VuumColor.primaryText)
                                        Text(place.subtitle)
                                            .font(.system(size: 13, weight: .regular, design: .rounded))
                                            .foregroundStyle(VuumColor.secondaryText)
                                        Text(TripGeo.formatDistance(
                                            TripGeo.distanceMeters(
                                                from: tripSession.pickup.coordinate,
                                                to: place.coordinate
                                            )
                                        ))
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundStyle(VuumColor.secondaryText)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)

                            if place.id != suggestions.last?.id {
                                Divider()
                            }
                        }
                    }

                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(VuumColor.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $showPlaceSearch) {
            PlaceSearchPickerSheet(
                title: L10n.Products.pickup,
                bias: searchBias
            ) { place in
                tripSession.selectPickup(place)
                dismiss()
            }
        }
    }
}

struct ScheduleRideSheet: View {
    @EnvironmentObject private var tripSession: TripSession
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date().addingTimeInterval(3600)

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button {
                        tripSession.scheduleForLater = nil
                        dismiss()
                    } label: {
                        Label("Ride now", systemImage: "bolt.fill")
                    }
                }

                Section("Schedule a pickup") {
                    DatePicker(
                        "Date & time",
                        selection: $date,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    Toggle("Remind me before pickup", isOn: $tripSession.scheduleReminderEnabled)
                    Button("Use this time") {
                        tripSession.scheduleForLater = date
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                } footer: {
                    Text("You?ll pick destination, ride type, and payment next. Reserved rides appear under Activity ? Upcoming.")
                }
            }
            .navigationTitle("Pickup time")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if let existing = tripSession.scheduleForLater, existing > Date() {
                    date = existing
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

