import SwiftUI

/// Focused destination typing UI (Where to? / Airport results) per Destination Search layout.
/// Full-screen: back, dim pickup + focused destination with connector, Home/Work, results, map pick.
struct DestinationSearchView: View {
    /// When presented over Plan your ride, back dismisses instead of leaving the trip phase.
    var isModal: Bool = false

    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var savedPlaces: SavedPlacesStore
    @EnvironmentObject private var appLocale: AppLocale
    @EnvironmentObject private var location: RiderLocationManager
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    @StateObject private var placesSearch = PlacesSearchController()
    @State private var query = ""
    @State private var assignSlot: SavedPlaceKind?
    @State private var showAdjustPickup = false
    @State private var showMapPick = false
    @FocusState private var destinationFocused: Bool

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var isResolving: Bool { placesSearch.isResolving }

    private var pickupLabel: String {
        let name = tripSession.pickup.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? L10n.Destination.currentLocation : name
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

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                LazyVStack(spacing: 0) {
                    if !isSearching {
                        savedSlotsSection
                        thickDivider
                    }

                    if !filteredFavorites.isEmpty {
                        ForEach(filteredFavorites) { place in
                            placeButton(place, icon: "star.fill", emphasized: true)
                        }
                    }

                    if !filteredRecent.isEmpty {
                        ForEach(filteredRecent) { place in
                            placeButton(place, icon: "clock", emphasized: false)
                        }
                    }

                    if isSearching {
                        resultsSection
                    } else if !filteredSuggestions.isEmpty {
                        ForEach(filteredSuggestions) { place in
                            placeButton(
                                place,
                                icon: tripSession.isAddingStop ? "plus" : "mappin",
                                emphasized: false
                            )
                        }
                    }

                    mapPickRow
                }
                .padding(.bottom, 40)
            }
        }
        .background(VuumColor.pageBackground.ignoresSafeArea())
        .fullScreenCover(item: $assignSlot) { kind in
            AssignSavedPlaceSheet(kind: kind)
                .environmentObject(savedPlaces)
                .environmentObject(appLocale)
                .environmentObject(location)
        }
        .sheet(isPresented: $showAdjustPickup) {
            AdjustPickupSheet()
        }
        .sheet(isPresented: $showMapPick) {
            DestinationMapPickSheet { place in
                choose(place)
            }
        }
        .onAppear {
            placesSearch.beginSession()
            destinationFocused = true
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

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Button(action: goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(VuumColor.primaryText)
                        .frame(width: 40, height: 40)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Common.back)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.top, 4)

            VuumTripEndpointsStack(
                style: .search,
                intermediateStops: tripSession.stops.count,
                spacing: 12,
                railVerticalInset: 18
            ) {
                VuumEndpointSummaryField(title: pickupLabel, emphasized: false) {
                    showAdjustPickup = true
                }
                .accessibilityHint(L10n.Trip.adjustPickup)

                ForEach(tripSession.stops) { stop in
                    VuumEndpointSummaryField(title: stop.name, emphasized: false)
                }

                focusedDestinationField
            }
            .padding(.horizontal, VuumLayout.pageInset)
            .padding(.top, 4)
            .padding(.bottom, 18)
        }
        .background(VuumColor.pageBackground)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(VuumColor.divider.opacity(colorScheme == .dark ? 0.5 : 0.75))
                .frame(height: 1)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.05), radius: 6, y: 2)
    }

    private var focusedDestinationField: some View {
        HStack(spacing: 8) {
            TextField(
                "",
                text: $query,
                prompt: Text(
                    tripSession.isAddingStop ? L10n.Destination.searchStop : L10n.Home.whereTo
                )
                .foregroundStyle(VuumColor.fieldPlaceholder)
            )
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(VuumColor.primaryText)
            .tint(VuumColor.brand)
            .textInputAutocapitalization(.words)
            .autocorrectionDisabled()
            .focused($destinationFocused)
            .accessibilityLabel(
                tripSession.isAddingStop ? L10n.Destination.searchStop : L10n.Home.whereTo
            )

            if isResolving || placesSearch.isQueryPending {
                ProgressView()
                    .controlSize(.small)
                    .tint(VuumColor.secondaryText)
            } else if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VuumColor.secondaryText)
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.Auth.clearSearch)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: VuumLayout.endpointRowHeight)
        .background(
            VuumDestinationSearchField.searchFill,
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(VuumColor.primaryText.opacity(0.88), lineWidth: 2)
        )
    }

    // MARK: - Lists

    private var savedSlotsSection: some View {
        VStack(spacing: 0) {
            savedSlotRow(
                kind: .home,
                place: savedPlaces.home,
                emptyTitle: L10n.Destination.addHome,
                emptySubtitle: L10n.Destination.homeSubtitle
            )
            Divider()
                .background(VuumColor.divider)
                .padding(.leading, VuumLayout.pageInset + 40 + 14)
            savedSlotRow(
                kind: .work,
                place: savedPlaces.work,
                emptyTitle: L10n.Destination.addWork,
                emptySubtitle: L10n.Destination.workSubtitle
            )
        }
        .padding(.top, 4)
    }

    private var thickDivider: some View {
        Rectangle()
            .fill(Color(.tertiarySystemFill))
            .frame(height: 8)
            .padding(.vertical, 8)
    }

    @ViewBuilder
    private var resultsSection: some View {
        if let status = placesSearch.statusMessage {
            HStack(alignment: .top, spacing: 10) {
                Text(status)
                    .font(VuumType.callout)
                    .foregroundStyle(VuumColor.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if placesSearch.canRetry {
                    Button(L10n.t("status.retry")) {
                        placesSearch.retryLastSearch()
                    }
                    .font(VuumType.captionSemibold)
                    .foregroundStyle(VuumColor.brand)
                }
            }
            .padding(.horizontal, VuumLayout.pageInset)
            .padding(.vertical, 14)
        }

        if placesSearch.isQueryPending, placesSearch.suggestions.isEmpty {
            Text(L10n.Destination.searchingPlaces)
                .font(VuumType.body)
                .foregroundStyle(VuumColor.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, VuumLayout.pageInset)
                .padding(.vertical, 18)
        } else if !placesSearch.suggestions.isEmpty {
            ForEach(Array(placesSearch.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                Button {
                    selectSuggestion(suggestion)
                } label: {
                    VuumDestinationPlaceRowContent(
                        title: suggestion.primaryText,
                        subtitle: suggestion.compactSubtitle,
                        systemImage: Self.rowGlyph(from: suggestion.systemImage),
                        emphasizedGlyph: false,
                        verticalPadding: 18
                    )
                    .padding(.horizontal, VuumLayout.pageInset)
                }
                .buttonStyle(.plain)
                .disabled(isResolving)

                if index < placesSearch.suggestions.count - 1 {
                    Divider()
                        .background(VuumColor.divider)
                        .padding(.leading, VuumLayout.pageInset + 40 + 14)
                }
            }
        } else {
            Text(L10n.Destination.noMatchingPlaces)
                .font(VuumType.body)
                .foregroundStyle(VuumColor.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, VuumLayout.pageInset)
                .padding(.vertical, 18)
        }
    }

    private var mapPickRow: some View {
        Button {
            showMapPick = true
        } label: {
            VuumDestinationPlaceRowContent(
                title: L10n.Destination.setLocationOnMap,
                subtitle: "",
                systemImage: "map",
                emphasizedGlyph: true,
                verticalPadding: 18
            )
            .padding(.horizontal, VuumLayout.pageInset)
        }
        .buttonStyle(.plain)
        .padding(.top, 4)
        .accessibilityLabel(L10n.Destination.setLocationOnMap)
    }

    private func savedSlotRow(
        kind: SavedPlaceKind,
        place: Place?,
        emptyTitle: String,
        emptySubtitle: String
    ) -> some View {
        Button {
            if let place, isAvailable(place) {
                choose(place)
            } else {
                assignSlot = kind
            }
        } label: {
            VuumDestinationPlaceRowContent(
                title: place == nil ? emptyTitle : kind.title,
                subtitle: place.map { savedPlaces.displaySubtitle(for: $0) } ?? emptySubtitle,
                systemImage: kind == .home ? "house.fill" : "briefcase.fill",
                emphasizedGlyph: true,
                showsChevron: place != nil,
                verticalPadding: 18
            )
            .padding(.horizontal, VuumLayout.pageInset)
        }
        .buttonStyle(.plain)
    }

    private func placeButton(_ place: Place, icon: String, emphasized: Bool) -> some View {
        Button {
            choose(place)
        } label: {
            VuumDestinationPlaceRowContent(
                title: savedPlaces.displayTitle(for: place),
                subtitle: savedPlaces.displaySubtitle(for: place),
                systemImage: icon,
                emphasizedGlyph: emphasized,
                verticalPadding: 18
            )
            .padding(.horizontal, VuumLayout.pageInset)
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            Divider()
                .background(VuumColor.divider)
                .padding(.leading, VuumLayout.pageInset + 40 + 14)
        }
    }

    // MARK: - Actions

    private func goBack() {
        placesSearch.abandonSession()
        if isModal {
            dismiss()
            return
        }
        if tripSession.isAddingStop {
            tripSession.cancelAddingStop()
        } else {
            tripSession.resetToHome()
        }
    }

    private func choose(_ place: Place) {
        guard isAvailable(place) else { return }
        savedPlaces.recordRecent(place)
        placesSearch.beginSessionAfterSelection()
        query = ""
        tripSession.selectDestination(place)
    }

    private func selectSuggestion(_ suggestion: PlacesSearchService.PlaceSuggestion) {
        Task {
            let place = await placesSearch.resolve(suggestion)
            guard let place, isAvailable(place) else { return }
            choose(place)
        }
    }

    private static func rowGlyph(from systemImage: String) -> String {
        if systemImage.contains("airplane") { return "airplane" }
        if systemImage.contains("mappin") { return "mappin" }
        if systemImage.contains("clock") { return "clock" }
        if systemImage.contains("star") { return "star.fill" }
        if systemImage.hasSuffix(".circle.fill") {
            return String(systemImage.dropLast(".circle.fill".count))
        }
        return systemImage
    }
}

// MARK: - Set location on map

struct DestinationMapPickSheet: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var appLocale: AppLocale
    @EnvironmentObject private var savedPlaces: SavedPlacesStore
    @Environment(\.dismiss) private var dismiss

    let onSelect: (Place) -> Void

    private var nearby: [Place] {
        let bias = tripSession.mapCamera
        return appLocale.destinations
            .filter { $0.id != tripSession.pickup.id }
            .sorted {
                TripGeo.distanceMeters(from: bias, to: $0.coordinate)
                    < TripGeo.distanceMeters(from: bias, to: $1.coordinate)
            }
            .prefix(12)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                TripMapLayer()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Capsule()
                        .fill(VuumColor.divider)
                        .frame(width: VuumLayout.sheetHandleWidth, height: VuumLayout.sheetHandleHeight)
                        .padding(.top, 10)
                        .padding(.bottom, 8)

                    Text(L10n.Destination.setLocationOnMap)
                        .font(VuumType.titleSmall)
                        .foregroundStyle(VuumColor.primaryText)
                        .padding(.bottom, 4)

                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(nearby) { place in
                                Button {
                                    onSelect(place)
                                    dismiss()
                                } label: {
                                    VuumDestinationPlaceRowContent(
                                        title: savedPlaces.displayTitle(for: place),
                                        subtitle: savedPlaces.displaySubtitle(for: place),
                                        systemImage: "mappin",
                                        emphasizedGlyph: false,
                                        verticalPadding: 16
                                    )
                                    .padding(.horizontal, VuumLayout.pageInset)
                                }
                                .buttonStyle(.plain)

                                Divider()
                                    .background(VuumColor.divider)
                                    .padding(.leading, VuumLayout.pageInset + 40 + 14)
                            }
                        }
                    }
                    .frame(maxHeight: 320)
                }
                .frame(maxWidth: .infinity)
                .background(
                    VuumColor.sheetBackground,
                    in: RoundedRectangle(cornerRadius: VuumLayout.radiusSheet, style: .continuous)
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) { dismiss() }
                        .foregroundStyle(VuumColor.primaryText)
                }
            }
        }
        .presentationDetents([.large])
        .presentationBackground(VuumColor.pageBackground)
    }
}
