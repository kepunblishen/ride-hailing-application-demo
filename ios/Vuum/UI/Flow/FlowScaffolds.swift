import SwiftUI

struct TripMapLayer: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var location: RiderLocationManager
    @ObservedObject private var mapsDiagnostics = GoogleMapsDiagnostics.shared
    @ObservedObject private var developerDiagnostics = DeveloperDiagnostics.shared

    var body: some View {
        ZStack(alignment: .topLeading) {
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
                lowDataMode: preferences.lowDataMode,
                useDefaultBasemapStyle: mapsDiagnostics.useDefaultBasemapStyle
            )
            // Full-bleed behind sheets — UIViewRepresentable otherwise collapses to
            // zero / intrinsic size when ZStack sizes around tall sheet content.
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if developerDiagnostics.isUnlocked {
                mapsCredentialChip
                    .padding(.top, 56)
                    .padding(.leading, 12)
            }
        }
        .onAppear { location.startUpdatingIfAllowed() }
        .ignoresSafeArea()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(mapAccessibilityLabel)
        .accessibilityHint("Shows pickup, destination, route, and nearby vehicles")
    }

    /// Temporary QA chip — key boolean + SDK only; never the key value.
    private var mapsCredentialChip: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Maps QA")
                .font(.caption2.weight(.bold))
            Text("Key \(mapsDiagnostics.keyPresenceLabel) · SDK \(mapsDiagnostics.mapsSDKConfiguredLabel)")
                .font(.caption2)
            if let err = mapsDiagnostics.lastErrorCode {
                Text("Last err \(err)")
                    .font(.caption2)
            }
        }
        .foregroundStyle(.primary)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .accessibilityHidden(true)
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
        case .selectingDestination, .choosingRide, .confirmingRide:
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

/// Shared map host: full-bleed map under chrome. Sheet height stays ~40–55% so the map stays visible.
struct TripMapHost<Chrome: View>: View {
    /// Sheet height as a fraction of the host (clamped to `VuumLayout` map sheet tokens).
    var sheetFraction: CGFloat = VuumLayout.mapSheetPreferredFraction
    @ViewBuilder var chrome: (_ sheetMaxHeight: CGFloat) -> Chrome

    var body: some View {
        GeometryReader { geo in
            let sheetMax = VuumLayout.mapSheetMaxHeight(in: geo.size.height, fraction: sheetFraction)
            ZStack(alignment: .bottom) {
                TripMapLayer()
                    .zIndex(0)

                chrome(sheetMax)
                    .zIndex(1)
            }
            .frame(width: geo.size.width, height: geo.size.height)
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
        GeometryReader { geo in
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
                                .VuumChromeMaterialBackground(in: Circle())
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
                VStack(alignment: .leading, spacing: VuumLayout.stackSpacing) {
                    Text("Vuum")
                        .font(VuumType.hero)
                        .foregroundStyle(VuumColor.primaryText)

                    Text(L10n.t("home.tagline"))
                        .font(VuumType.callout)
                        .foregroundStyle(VuumColor.secondaryText)

                    Button {
                        showAdjustPickup = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(VuumColor.brand)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(L10n.t("home.pickup"))
                                    .font(VuumType.micro)
                                    .foregroundStyle(VuumColor.secondaryText)
                                Text(tripSession.pickup.name)
                                    .font(VuumType.bodySemibold)
                                    .foregroundStyle(VuumColor.primaryText)
                            }
                            Spacer()
                            Text(L10n.t("home.adjust"))
                                .font(VuumType.captionSemibold)
                                .foregroundStyle(VuumColor.brand)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            VuumColor.chipBackground,
                            in: RoundedRectangle(cornerRadius: VuumLayout.radiusControl, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)

                    if !tripSession.reservedTrips.isEmpty {
                        VStack(alignment: .leading, spacing: VuumLayout.chipSpacing) {
                            Text(L10n.t("home.upcoming"))
                                .font(VuumType.captionSemibold)
                                .foregroundStyle(VuumColor.secondaryText)
                            ForEach(tripSession.reservedTrips.prefix(2)) { trip in
                                HStack(spacing: 10) {
                                    Image(systemName: "calendar")
                                        .foregroundStyle(VuumColor.brand)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(trip.pickupName) → \(trip.dropoffName)")
                                            .font(VuumType.callout)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(VuumColor.primaryText)
                                        if !trip.stopNames.isEmpty {
                                            Text("via \(trip.stopNames.joined(separator: ", "))")
                                                .font(VuumType.caption)
                                                .foregroundStyle(VuumColor.secondaryText)
                                        }
                                        Text(trip.when.formatted(date: .abbreviated, time: .shortened))
                                            .font(VuumType.caption)
                                            .foregroundStyle(VuumColor.secondaryText)
                                    }
                                    Spacer(minLength: 8)
                                    Text(
                                        AppLocale.formatFareTotal(
                                            cdf: trip.priceCDF,
                                            usd: trip.priceUSD,
                                            market: AppLocale.market(countryCode: session.countryCode)
                                        )
                                    )
                                    .font(VuumType.captionSemibold)
                                    .foregroundStyle(VuumColor.primaryText)
                                }
                                .padding(10)
                                .background(
                                    VuumColor.chipBackground,
                                    in: RoundedRectangle(cornerRadius: VuumLayout.radiusControl, style: .continuous)
                                )
                            }
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            tripSession.beginDestinationSelection()
                        } label: {
                            HStack(spacing: VuumLayout.rowSpacing) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(VuumColor.secondaryText)
                                Text(L10n.t("home.where_to"))
                                    .font(VuumType.button)
                                    .foregroundStyle(VuumColor.primaryText)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(
                                VuumDestinationSearchField.searchFill,
                                in: RoundedRectangle(cornerRadius: VuumLayout.radiusSearch, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            showSchedule = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "clock.fill")
                                Text(tripSession.scheduleForLater == nil ? L10n.t("home.now") : L10n.t("home.later"))
                            }
                            .font(VuumType.captionSemibold)
                            .foregroundStyle(VuumColor.primaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 14)
                            .background(VuumDestinationSearchField.searchFill, in: Capsule())
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
                                    HStack(spacing: VuumLayout.chipSpacing) {
                                        Image(systemName: savedPlaces.systemImage(for: place))
                                            .foregroundStyle(VuumColor.brand)
                                        Text(savedPlaces.displayTitle(for: place))
                                            .font(VuumType.captionSemibold)
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
            .frame(maxHeight: VuumLayout.mapSheetMaxHeight(in: geo.size.height), alignment: .bottom)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            }
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
        .fullScreenCover(item: $assignSlot) { kind in
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
                HStack(spacing: VuumLayout.chipSpacing) {
                    Image(systemName: kind.systemImage)
                        .foregroundStyle(VuumColor.brand)
                    Text(kind.title)
                        .font(VuumType.captionSemibold)
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
                HStack(spacing: VuumLayout.chipSpacing) {
                    Image(systemName: kind == .home ? "house" : "briefcase")
                        .foregroundStyle(VuumColor.secondaryText)
                    Text(emptyTitle)
                        .font(VuumType.captionSemibold)
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
    /// First-run permissions after auth — follow AuthLocale without forcing main Home copy.
    @ObservedObject private var authLocale = AuthLocale.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(copy("permissions.intro"))
                            .font(VuumType.body)
                            .foregroundStyle(VuumColor.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                            .padding(.bottom, VuumLayout.sectionSpacing)

                        permissionRow(
                            icon: "location",
                            title: copy("permissions.location"),
                            detail: copy("permissions.location_detail")
                        )
                        .padding(.bottom, VuumLayout.sectionSpacing)

                        permissionRow(
                            icon: "bell",
                            title: copy("permissions.notifications"),
                            detail: copy("permissions.notifications_detail")
                        )
                        .padding(.bottom, VuumLayout.sectionSpacing)

                        Text(copy("permissions.change_anytime"))
                            .font(VuumType.caption)
                            .foregroundStyle(VuumColor.secondaryText)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, VuumLayout.stackSpacing)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)

                VuumPrimaryButton(title: L10n.t("common.continue", authLanguage: authLocale.language)) {
                    onContinue()
                }
                .padding(.horizontal, 24)
                .padding(.top, VuumLayout.rowSpacing)
                .padding(.bottom, 20)
            }
            .VuumPageBackground()
            .navigationTitle(copy("permissions.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(VuumColor.pageBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .interactiveDismissDisabled()
        .id(authLocale.language)
    }

    private func copy(_ key: String) -> String {
        L10n.t(key, authLanguage: authLocale.language)
    }

    private func permissionRow(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: VuumLayout.stackSpacing) {
            Image(systemName: icon)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(VuumColor.brand)
                .frame(width: VuumLayout.iconBadgeLarge, alignment: .center)
                .padding(.top, 2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: VuumLayout.chipSpacing) {
                Text(title)
                    .font(VuumType.rowTitle)
                    .foregroundStyle(VuumColor.primaryText)
                Text(detail)
                    .font(VuumType.body)
                    .foregroundStyle(VuumColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Destination phase entry — map + plan-your-ride sheet (`PlanYourRideView`).
/// Focused typing opens `DestinationSearchView` full-screen from that sheet.
struct DestinationScaffoldView: View {
    var body: some View {
        PlanYourRideView()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Pick a place for Home or Work via Places autocomplete (local catalog fallback).
/// Presented full-screen (or large-only sheet) — never a half-height card.
struct AssignSavedPlaceSheet: View {
    @EnvironmentObject private var savedPlaces: SavedPlacesStore
    let kind: SavedPlaceKind

    var body: some View {
        PlaceSearchPickerSheet(
            title: kind == .home ? "Set Home" : "Set Work",
            allowClear: (kind == .home && savedPlaces.home != nil)
                || (kind == .work && savedPlaces.work != nil),
            detents: [.large],
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
                        .foregroundStyle(VuumColor.secondaryText)
                } else {
                    ForEach(savedPlaces.favorites) { place in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(VuumColor.primaryText)
                                Text(place.subtitle)
                                    .font(.system(size: 12))
                                    .foregroundStyle(VuumColor.secondaryText)
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
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .VuumGroupedBackground()
        .navigationTitle("Saved places")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(VuumColor.groupedBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .fullScreenCover(item: $assignSlot) { kind in
            AssignSavedPlaceSheet(kind: kind)
        }
    }

    private func savedManageRow(kind: SavedPlaceKind, place: Place?) -> some View {
        Button {
            assignSlot = kind
        } label: {
            HStack(spacing: 12) {
                Image(systemName: kind.systemImage)
                    .foregroundStyle(VuumColor.brand)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(kind.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VuumColor.primaryText)
                    Text(place?.name ?? "Not set")
                        .font(.system(size: 13))
                        .foregroundStyle(VuumColor.secondaryText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VuumColor.secondaryText)
            }
        }
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
            HStack {
                VuumCircleChromeButton(
                    systemImage: "xmark",
                    accessibilityLabel: L10n.Common.close,
                    size: 40
                ) {
                    dismiss()
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)

            VuumSheetChrome(title: "Adjust pickup") {
                VStack(alignment: .leading, spacing: VuumLayout.rowSpacing) {
                    Text("Current — \(tripSession.pickup.name)")
                        .font(VuumType.captionSemibold)
                        .foregroundStyle(VuumColor.secondaryText)

                    Button {
                        showPlaceSearch = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(VuumColor.brand)
                            Text(L10n.Destination.searchPlaces)
                                .font(VuumType.bodySemibold)
                                .foregroundStyle(VuumColor.primaryText)
                            Spacer(minLength: 0)
                        }
                        .padding(VuumLayout.rowSpacing)
                        .background(
                            VuumDestinationSearchField.searchFill,
                            in: RoundedRectangle(cornerRadius: VuumLayout.radiusControl, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)

                    VStack(spacing: 0) {
                        ForEach(suggestions) { place in
                            Button {
                                tripSession.selectPickup(place)
                                dismiss()
                            } label: {
                                HStack(alignment: .top, spacing: VuumLayout.rowSpacing) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundStyle(VuumColor.brand)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(place.name)
                                            .font(VuumType.rowTitle)
                                            .foregroundStyle(VuumColor.primaryText)
                                        Text(place.subtitle)
                                            .font(VuumType.caption)
                                            .foregroundStyle(VuumColor.secondaryText)
                                        Text(TripGeo.formatDistance(
                                            TripGeo.distanceMeters(
                                                from: tripSession.pickup.coordinate,
                                                to: place.coordinate
                                            )
                                        ))
                                        .font(VuumType.captionSemibold)
                                        .foregroundStyle(VuumColor.secondaryText)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, VuumLayout.rowSpacing)
                            }
                            .buttonStyle(.plain)

                            if place.id != suggestions.last?.id {
                                VuumHairline()
                            }
                        }
                    }

                    Button("Cancel") {
                        dismiss()
                    }
                    .font(VuumType.body)
                    .fontWeight(.medium)
                    .foregroundStyle(VuumColor.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
        .VuumPageBackground()
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .presentationBackground(VuumColor.sheetBackground)
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
                            .foregroundStyle(VuumColor.primaryText)
                    }
                }

                Section {
                    DatePicker(
                        "Date & time",
                        selection: $date,
                        in: Date()...,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .foregroundStyle(VuumColor.primaryText)
                    Toggle("Remind me before pickup", isOn: $tripSession.scheduleReminderEnabled)
                        .foregroundStyle(VuumColor.primaryText)
                        .tint(VuumColor.brand)
                    Button("Use this time") {
                        tripSession.scheduleForLater = date
                        dismiss()
                    }
                    .font(VuumType.button)
                    .foregroundStyle(VuumColor.brand)
                } header: {
                    Text("Schedule a pickup")
                        .foregroundStyle(VuumColor.secondaryText)
                } footer: {
                    Text("You'll pick destination, ride type, and payment next. Reserved rides appear under Activity → Upcoming.")
                        .foregroundStyle(VuumColor.secondaryText)
                }
            }
            .scrollContentBackground(.hidden)
            .VuumGroupedBackground()
            .tint(VuumColor.brand)
            .navigationTitle("Pickup time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(VuumColor.groupedBackground, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    VuumCircleChromeButton(
                        systemImage: "xmark",
                        accessibilityLabel: L10n.Common.close,
                        size: 36
                    ) {
                        dismiss()
                    }
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

