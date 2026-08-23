import CoreLocation
import SwiftUI

/// Uber-like “Plan your ride” entry after Home search — map + roomy bottom sheet.
/// Owns From/To planning only (no fare / payment / for-me chrome).
///
/// Single custom bottom sheet over `TripMapLayer` (not a system `.sheet` stack).
/// Three detents: collapsed (map peek) → mid (~¾ default) → large.
struct PlanYourRideView: View {
    private enum SheetDetent: Int, CaseIterable, Comparable {
        case collapsed
        case mid
        case large

        static func < (lhs: SheetDetent, rhs: SheetDetent) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        func height(in hostHeight: CGFloat) -> CGFloat {
            let fraction: CGFloat
            switch self {
            case .collapsed: fraction = VuumLayout.planRideSheetCollapsedFraction
            case .mid: fraction = VuumLayout.planRideSheetMidFraction
            case .large: fraction = VuumLayout.planRideSheetLargeFraction
            }
            return hostHeight * fraction
        }
    }

    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var savedPlaces: SavedPlacesStore
    @EnvironmentObject private var appLocale: AppLocale
    @EnvironmentObject private var location: RiderLocationManager
    @EnvironmentObject private var permissions: PermissionCenter
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var placesSearch = PlacesSearchController()
    @State private var query = ""
    @State private var assignSlot: SavedPlaceKind?
    @State private var showAdjustPickup = false
    @State private var showDestinationSearch = false
    /// Default mid (~¾); drag handle down to collapsed so the map peeks.
    @State private var sheetDetent: SheetDetent = .mid
    @GestureState private var sheetDragTranslation: CGFloat = 0

    private let recentCap = 6
    /// Pull past collapsed by this fraction of host height (or fast flick) → Home.
    private let dismissPullPastCollapsed: CGFloat = 0.12
    private let dismissVelocity: CGFloat = 900

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isResolving: Bool { placesSearch.isResolving }

    private var sheetTitle: String {
        tripSession.isAddingStop ? L10n.Destination.addStop : L10n.Destination.planYourRide
    }

    private var canOfferAddStop: Bool {
        !tripSession.isAddingStop
            && tripSession.stops.count < TripSession.maxStops
    }

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
        return Array(
            savedPlaces.recent.filter {
                isAvailable($0)
                    && matchesQuery($0)
                    && !homeWork.contains($0.id)
                    && !favoriteIds.contains($0.id)
            }
            .prefix(recentCap)
        )
    }

    private var filteredFavorites: [Place] {
        let homeWork = Set([savedPlaces.home?.id, savedPlaces.work?.id].compactMap { $0 })
        return Array(
            savedPlaces.favorites.filter {
                isAvailable($0) && matchesQuery($0) && !homeWork.contains($0.id)
            }
            .prefix(4)
        )
    }

    private var recentFallbackPlaces: [Place] {
        guard filteredRecent.isEmpty, !isSearching else { return [] }
        return Array(filteredSuggestions.prefix(recentCap))
    }

    var body: some View {
        GeometryReader { geo in
            let hostHeight = geo.size.height
            let collapsedHeight = SheetDetent.collapsed.height(in: hostHeight)
            let largeHeight = SheetDetent.large.height(in: hostHeight)
            let baseHeight = sheetDetent.height(in: hostHeight)
            // Live drag: can shrink to collapsed (map peek), not stuck near mid.
            let draggedHeight = min(
                largeHeight,
                max(collapsedHeight * 0.88, baseHeight - sheetDragTranslation)
            )

            ZStack(alignment: .bottom) {
                TripMapLayer()
                    .zIndex(0)

                planRideSheet(hostHeight: hostHeight)
                    .frame(height: draggedHeight)
                    .frame(maxWidth: .infinity)
                    .zIndex(1)
            }
            .frame(width: geo.size.width, height: hostHeight)
            .overlay(alignment: .top) {
                mapTopChrome
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .fullScreenCover(item: $assignSlot) { kind in
            AssignSavedPlaceSheet(kind: kind)
                .environmentObject(savedPlaces)
                .environmentObject(appLocale)
                .environmentObject(location)
        }
        .sheet(isPresented: $showAdjustPickup) {
            AdjustPickupSheet()
        }
        .fullScreenCover(isPresented: $showDestinationSearch) {
            DestinationSearchView(isModal: true)
                .environmentObject(tripSession)
                .environmentObject(savedPlaces)
                .environmentObject(appLocale)
        }
        .onAppear {
            placesSearch.beginSession()
            location.startUpdatingIfAllowed()
        }
        .onChange(of: location.latestLocation) { _, newValue in
            // Keep GPS pickup fresh while Home is off-screen (plan-ride phase).
            tripSession.updatePickup(from: newValue)
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

    // MARK: - Map chrome

    private var mapTopChrome: some View {
        VuumPlanRideMapChrome(
            backSystemImage: tripSession.isAddingStop ? "chevron.left" : "arrow.left",
            backAccessibilityLabel: tripSession.isAddingStop ? L10n.Common.back : L10n.Common.close,
            locationTitle: L10n.Destination.shareCurrentLocation,
            onBack: dismissPlanning,
            onUseCurrentLocation: useCurrentLocationAsPickup
        )
    }

    // MARK: - Bottom sheet

    private func planRideSheet(hostHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VuumSheetHandle()
                .padding(.top, 12)
                .padding(.bottom, 8)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
                .gesture(sheetResizeGesture(hostHeight: hostHeight))
                .accessibilityLabel("Resize sheet")
                .accessibilityHint("Drag up or down to peek the map or expand the sheet")

            Text(sheetTitle)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(VuumColor.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)
                .accessibilityAddTraits(.isHeader)

            if tripSession.isAddingStop {
                Text(
                    String(
                        format: L10n.Destination.stopProgress,
                        tripSession.stops.count + 1,
                        TripSession.maxStops
                    )
                )
                .font(VuumType.captionSemibold)
                .foregroundStyle(VuumColor.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 12)
            }

            endpointsCard
                .padding(.horizontal, 24)
                .padding(.bottom, 12)

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
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    if !isSearching, !tripSession.isAddingStop {
                        compactSavedSlotsRow
                    }

                    if !filteredFavorites.isEmpty {
                        sectionHeader(L10n.Destination.favorites)
                        placeRows(filteredFavorites, leadingIcon: "star.fill")
                    }

                    if !filteredRecent.isEmpty {
                        sectionHeader(L10n.Destination.recent)
                        placeRows(filteredRecent, leadingIcon: "clock")
                    } else if !recentFallbackPlaces.isEmpty {
                        sectionHeader(L10n.Destination.recent)
                        placeRows(recentFallbackPlaces, leadingIcon: "mappin")
                    }

                    if isSearching {
                        sectionHeader(L10n.Destination.results)
                        if placesSearch.isQueryPending, placesSearch.suggestions.isEmpty {
                            Text(L10n.Destination.searchingPlaces)
                                .font(.system(size: 15))
                                .foregroundStyle(VuumColor.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 18)
                        } else if !placesSearch.suggestions.isEmpty {
                            suggestionRows(placesSearch.suggestions)
                        } else if !placesSearch.isQueryPending {
                            Text(L10n.Destination.noMatchingPlaces)
                                .font(.system(size: 15))
                                .foregroundStyle(VuumColor.secondaryText)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 18)
                        }
                    } else if filteredRecent.isEmpty,
                              recentFallbackPlaces.isEmpty,
                              !filteredSuggestions.isEmpty {
                        sectionHeader(L10n.Destination.suggestions)
                        placeRows(
                            Array(filteredSuggestions.prefix(recentCap)),
                            leadingIcon: tripSession.isAddingStop ? "plus" : "mappin"
                        )
                    }
                }
                .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        // Opaque sheet — translucent `.panel` glass made the nested endpoints card
        // read as a second stacked sheet through the frost.
        .background(
            VuumColor.sheetBackground,
            in: UnevenRoundedRectangle(
                topLeadingRadius: VuumLayout.radiusSheet,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: VuumLayout.radiusSheet,
                style: .continuous
            )
        )
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: VuumLayout.radiusSheet,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: VuumLayout.radiusSheet,
                style: .continuous
            )
        )
        .shadow(color: VuumColor.glassShadow(for: colorScheme), radius: 10, y: -2)
        .padding(.horizontal, 0)
    }

    private func sheetResizeGesture(hostHeight: CGFloat) -> some Gesture {
        let collapsed = SheetDetent.collapsed.height(in: hostHeight)
        let mid = SheetDetent.mid.height(in: hostHeight)
        let large = SheetDetent.large.height(in: hostHeight)
        let dismissThreshold = collapsed - hostHeight * dismissPullPastCollapsed

        return DragGesture(minimumDistance: 8)
            .updating($sheetDragTranslation) { value, state, _ in
                state = value.translation.height
            }
            .onEnded { value in
                let projected = sheetDetent.height(in: hostHeight) - value.translation.height
                let velocity = value.predictedEndTranslation.height - value.translation.height

                // Strong downward flick / pull past collapsed → leave planning.
                if projected < dismissThreshold || (sheetDetent == .collapsed && velocity > dismissVelocity) {
                    dismissPlanning()
                    return
                }

                let nearest: SheetDetent
                if projected < (collapsed + mid) / 2 {
                    nearest = .collapsed
                } else if projected < (mid + large) / 2 {
                    nearest = .mid
                } else {
                    nearest = .large
                }

                withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.86)) {
                    sheetDetent = nearest
                }
            }
    }

    private var endpointsCard: some View {
        // Rail: circle (pickup) → stop dots → square on final field (pending stop, Where to?, or dropoff).
        let intermediateCount: Int = {
            if tripSession.isAddingStop, tripSession.dropoff != nil {
                return tripSession.stops.count + 1
            }
            return tripSession.stops.count
        }()

        return VuumPlanRideEndpointsCard(
            intermediateStops: intermediateCount
        ) {
            Button {
                showAdjustPickup = true
            } label: {
                Text(tripSession.pickup.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(VuumColor.primaryText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(height: VuumLayout.endpointRowHeight)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Home.pickup)
            .accessibilityValue(tripSession.pickup.name)
            .accessibilityHint(L10n.Home.adjust)

            ForEach(Array(tripSession.stops.enumerated()), id: \.element.id) { index, stop in
                VuumPlanRideEndpointsDivider()
                stopFieldRow(stop: stop, index: index)
            }

            if tripSession.isAddingStop {
                VuumPlanRideEndpointsDivider()
                pendingStopFieldRow
                if let dropoff = tripSession.dropoff {
                    VuumPlanRideEndpointsDivider()
                    dropoffSummaryRow(dropoff)
                }
            } else {
                VuumPlanRideEndpointsDivider()
                destinationFieldRow
            }
        }
    }

    private func dropoffSummaryRow(_ place: Place) -> some View {
        Text(place.name)
            .font(.system(size: 16, weight: .medium))
            .foregroundStyle(VuumColor.primaryText)
            .lineLimit(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: VuumLayout.endpointRowHeight)
            .accessibilityLabel(L10n.Home.whereTo)
            .accessibilityValue(place.name)
    }

    private func stopFieldRow(stop: Place, index: Int) -> some View {
        HStack(spacing: 8) {
            Text(stop.name)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(VuumColor.primaryText)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                tripSession.removeStop(stop)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VuumColor.secondaryText)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove stop \(index + 1)")
        }
        .frame(height: VuumLayout.endpointRowHeight)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Stop \(index + 1)")
        .accessibilityValue(stop.name)
    }

    private var pendingStopFieldRow: some View {
        Button {
            showDestinationSearch = true
        } label: {
            Text(L10n.Destination.searchStop)
                .font(.system(size: 16, weight: .regular))
                .foregroundStyle(VuumColor.fieldPlaceholder)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: VuumLayout.endpointRowHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Destination.searchStop)
    }

    private var destinationFieldRow: some View {
        let placeholder = tripSession.isAddingStop
            ? L10n.Destination.searchStop
            : L10n.Home.whereTo
        return HStack(spacing: 4) {
            Button {
                showDestinationSearch = true
            } label: {
                HStack(spacing: 8) {
                    Text(placeholder)
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(VuumColor.fieldPlaceholder)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(VuumColor.secondaryText)
                }
                .frame(height: VuumLayout.endpointRowHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(placeholder)
            .accessibilityHint(L10n.Home.whereToHint)

            if canOfferAddStop, !tripSession.isAddingStop {
                Button {
                    addStopTapped()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VuumColor.primaryText)
                        .frame(width: 36, height: VuumLayout.endpointRowHeight)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Destination.addStop)
            }
        }
        .frame(height: VuumLayout.endpointRowHeight)
    }

    // MARK: - Lists

    /// Single compact Home / Work row so Recent keeps the scroll room.
    private var compactSavedSlotsRow: some View {
        HStack(spacing: 10) {
            compactSavedChip(
                kind: .home,
                place: savedPlaces.home,
                emptyTitle: L10n.Destination.addHome
            )
            compactSavedChip(
                kind: .work,
                place: savedPlaces.work,
                emptyTitle: L10n.Destination.addWork
            )
        }
        .padding(.horizontal, 24)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private func compactSavedChip(
        kind: SavedPlaceKind,
        place: Place?,
        emptyTitle: String
    ) -> some View {
        Button {
            if let place, isAvailable(place) {
                savedPlaces.recordRecent(place)
                tripSession.selectDestination(place)
            } else {
                assignSlot = kind
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: place == nil
                      ? (kind == .home ? "house" : "briefcase")
                      : kind.systemImage)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VuumColor.primaryText)
                Text(place == nil ? emptyTitle : kind.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VuumColor.primaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(
                VuumColor.chipBackground,
                in: Capsule(style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(place == nil ? emptyTitle : kind.title)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(VuumType.captionSemibold)
            .foregroundStyle(VuumColor.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 8)
    }

    private func suggestionRows(_ items: [PlacesSearchService.PlaceSuggestion]) -> some View {
        ForEach(items) { suggestion in
            Button {
                selectSuggestion(suggestion)
            } label: {
                destinationRow(
                    title: suggestion.primaryText,
                    subtitle: suggestion.compactSubtitle,
                    systemImage: Self.rowGlyph(from: suggestion.systemImage)
                )
            }
            .buttonStyle(.plain)
            .disabled(isResolving)
        }
    }

    private func placeRows(_ places: [Place], leadingIcon: String) -> some View {
        ForEach(places) { place in
            HStack(spacing: 0) {
                Button {
                    savedPlaces.recordRecent(place)
                    tripSession.selectDestination(place)
                } label: {
                    destinationRow(
                        title: place.name,
                        subtitle: place.subtitle,
                        systemImage: Self.rowGlyph(from: leadingIcon)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    savedPlaces.toggleFavorite(place)
                } label: {
                    Image(systemName: savedPlaces.isFavorite(place) ? "star.fill" : "star")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(
                            savedPlaces.isFavorite(place) ? VuumColor.brand : VuumColor.secondaryText
                        )
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 12)
                .accessibilityLabel(
                    savedPlaces.isFavorite(place) ? "Remove favorite" : "Save favorite"
                )
            }
        }
    }

    private func destinationRow(title: String, subtitle: String, systemImage: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VuumColor.secondaryText)
                .frame(width: 36, height: 36)
                .background(VuumColor.chipBackground, in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(VuumColor.primaryText)
                    .multilineTextAlignment(.leading)
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(VuumColor.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            VuumHairline()
                .padding(.leading, 76)
        }
    }

    // MARK: - Actions

    private func addStopTapped() {
        tripSession.beginAddingStop()
        showDestinationSearch = true
    }

    private func dismissPlanning() {
        placesSearch.abandonSession()
        if tripSession.isAddingStop {
            tripSession.cancelAddingStop()
        } else {
            tripSession.resetToHome()
        }
    }

    private func useCurrentLocationAsPickup() {
        if location.isDenied {
            _ = permissions.openSystemSettings()
            return
        }
        location.requestWhenInUse()
        location.startUpdatingIfAllowed()
        // Forces GPS pickup (even after an alternate pin) via TripSession + updatePickup.
        tripSession.useCurrentLocationAsPickup(from: location.latestLocation)
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

    private static func rowGlyph(from systemImage: String) -> String {
        if systemImage.contains("mappin") { return "mappin" }
        if systemImage.contains("clock") { return "clock" }
        if systemImage.contains("star") { return "star.fill" }
        if systemImage.contains("house") { return "house.fill" }
        if systemImage.contains("briefcase") { return "briefcase.fill" }
        if systemImage.hasSuffix(".circle.fill") {
            return String(systemImage.dropLast(".circle.fill".count))
        }
        return systemImage
    }
}
