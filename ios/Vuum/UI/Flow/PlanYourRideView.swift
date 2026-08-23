import CoreLocation
import SwiftUI

/// Uber-like “Plan your ride” entry after Home search — map + roomy bottom sheet.
/// Owns From/To planning only (no fare / payment / for-me chrome).
struct PlanYourRideView: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var savedPlaces: SavedPlacesStore
    @EnvironmentObject private var appLocale: AppLocale
    @EnvironmentObject private var location: RiderLocationManager
    @EnvironmentObject private var permissions: PermissionCenter
    @StateObject private var placesSearch = PlacesSearchController()
    @State private var query = ""
    @State private var assignSlot: SavedPlaceKind?
    @State private var showAdjustPickup = false
    @State private var showDestinationSearch = false

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isResolving: Bool { placesSearch.isResolving }

    private var sheetTitle: String {
        tripSession.isAddingStop ? L10n.Destination.addStop : L10n.Destination.planYourRide
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

    private var recentFallbackPlaces: [Place] {
        guard filteredRecent.isEmpty, !isSearching else { return [] }
        return Array(filteredSuggestions.prefix(8))
    }

    var body: some View {
        GeometryReader { geo in
            // Shared map-sheet tokens (~40–55%) so the map stays visibly behind the sheet.
            let sheetHeight = VuumLayout.mapSheetMaxHeight(
                in: geo.size.height,
                fraction: VuumLayout.mapSheetMaxFraction
            )

            ZStack(alignment: .bottom) {
                TripMapLayer()
                    .zIndex(0)

                planRideSheet
                    .frame(height: sheetHeight)
                    .frame(maxWidth: .infinity)
                    .zIndex(1)
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .overlay(alignment: .top) {
                mapTopChrome
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(item: $assignSlot) { kind in
            AssignSavedPlaceSheet(kind: kind)
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

    private var planRideSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            VuumSheetHandle()
                .padding(.top, 12)
                .padding(.bottom, 8)

            Text(sheetTitle)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(VuumColor.primaryText)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
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
                .padding(.bottom, 16)

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

            if !tripSession.stops.isEmpty, !tripSession.isAddingStop {
                stopsPreview
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    if !isSearching, !tripSession.isAddingStop {
                        savedSlotsSection
                    }

                    if !filteredFavorites.isEmpty {
                        sectionHeader(L10n.Destination.favorites)
                        placeRows(filteredFavorites, leadingIcon: "star.fill")
                    }

                    if !filteredRecent.isEmpty {
                        sectionHeader(L10n.Destination.recent)
                        placeRows(filteredRecent, leadingIcon: "mappin")
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
                            filteredSuggestions,
                            leadingIcon: tripSession.isAddingStop ? "plus" : "mappin"
                        )
                    }
                }
                .padding(.bottom, 28)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .VuumGlassSurface(cornerRadius: VuumLayout.radiusSheet, style: .panel)
        .padding(.horizontal, 0)
    }

    private var endpointsCard: some View {
        VuumPlanRideEndpointsCard(
            intermediateStops: 0
        ) {
            Button {
                showAdjustPickup = true
            } label: {
                Text(tripSession.pickup.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(VuumColor.primaryText)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.Home.pickup)
            .accessibilityValue(tripSession.pickup.name)
            .accessibilityHint(L10n.Home.adjust)

            VuumPlanRideEndpointsDivider()

            destinationFieldRow
        }
    }

    private var destinationFieldRow: some View {
        let placeholder = tripSession.isAddingStop
            ? L10n.Destination.searchStop
            : L10n.Home.whereTo
        return Button {
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
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(placeholder)
        .accessibilityHint(L10n.Home.whereToHint)
    }

    // MARK: - Lists

    private var stopsPreview: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.Destination.stops)
                .font(VuumType.captionSemibold)
                .foregroundStyle(VuumColor.secondaryText)
            ForEach(Array(tripSession.stops.enumerated()), id: \.element.id) { index, stop in
                HStack(spacing: VuumLayout.chipSpacing) {
                    Text("\(index + 1). \(stop.name)")
                        .font(VuumType.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(VuumColor.primaryText)
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
                }
            }
        }
        .padding(14)
        .background(
            VuumColor.chipBackground,
            in: RoundedRectangle(cornerRadius: VuumLayout.radiusControl, style: .continuous)
        )
    }

    private var savedSlotsSection: some View {
        VStack(spacing: 0) {
            savedSlotRow(
                kind: .home,
                place: savedPlaces.home,
                emptyTitle: L10n.Destination.addHome,
                emptySubtitle: L10n.Destination.homeSubtitle
            )
            savedSlotRow(
                kind: .work,
                place: savedPlaces.work,
                emptyTitle: L10n.Destination.addWork,
                emptySubtitle: L10n.Destination.workSubtitle
            )
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(VuumType.captionSemibold)
            .foregroundStyle(VuumColor.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 8)
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
            HStack(spacing: 16) {
                Image(systemName: place == nil
                      ? (kind == .home ? "house" : "briefcase")
                      : kind.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VuumColor.primaryText)
                    .frame(width: 36, height: 36)
                    .background(VuumColor.chipBackground, in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(place == nil ? emptyTitle : kind.title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(VuumColor.primaryText)
                    Text(place?.name ?? emptySubtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(VuumColor.secondaryText)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            VuumHairline()
                .padding(.leading, 76)
        }
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
        .padding(.vertical, 16)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            VuumHairline()
                .padding(.leading, 76)
        }
    }

    // MARK: - Actions

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
