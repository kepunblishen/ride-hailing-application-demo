import SwiftUI

/// In-trip destination picker — updates dropoff via `TripSession.updateInTripDestination`.
struct ChangeDestinationSheet: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var savedPlaces: SavedPlacesStore
    @EnvironmentObject private var appLocale: AppLocale
    @Environment(\.dismiss) private var dismiss

    @StateObject private var placesSearch = PlacesSearchController()
    @State private var query = ""

    private var currentDropoff: Place? {
        tripSession.activeTrip?.dropoff ?? tripSession.dropoff
    }

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func isAvailable(_ place: Place) -> Bool {
        guard let trip = tripSession.activeTrip else { return false }
        return place.id != trip.pickup.id
            && place.id != trip.dropoff.id
            && !trip.stops.contains(where: { $0.id == place.id })
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

    var body: some View {
        NavigationStack {
            VStack(spacing: VuumLayout.rowSpacing) {
                if let current = currentDropoff {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "mappin")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(VuumColor.brand)
                            .frame(width: 40, height: 40)
                            .background(VuumColor.chipBackground, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current destination")
                                .font(VuumType.micro)
                                .foregroundStyle(VuumColor.secondaryText)
                            Text(current.name)
                                .font(VuumType.rowTitle)
                                .foregroundStyle(VuumColor.primaryText)
                            Text(current.subtitle)
                                .font(VuumType.caption)
                                .foregroundStyle(VuumColor.secondaryText)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 12))
                }

                VuumDestinationSearchField(
                    placeholder: L10n.Destination.searchNewDestination,
                    text: $query,
                    isBusy: placesSearch.isResolving
                        || placesSearch.isQueryPending
                        || tripSession.isRecalculatingTripRoute
                )

                Text("Fare and ETA update when you confirm a new place.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VuumColor.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

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

                ScrollView {
                    VStack(spacing: 0) {
                        if !isSearching {
                            savedQuickRows
                        }

                        if !filteredFavorites.isEmpty {
                            sectionHeader(L10n.Destination.favorites)
                            placeRows(filteredFavorites)
                        }

                        if !filteredRecent.isEmpty {
                            sectionHeader(L10n.Destination.recent)
                            placeRows(filteredRecent)
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
                            placeRows(filteredSuggestions, icon: "mappin", emphasizedGlyph: false)
                        }
                    }
                }
            }
            .padding(VuumLayout.pageInset)
            .navigationTitle(L10n.Trip.changeDestination)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) {
                        placesSearch.abandonSession()
                        dismiss()
                    }
                }
            }
            .onAppear {
                placesSearch.beginSession()
            }
            .onChange(of: query) { _, newValue in
                let bias = tripSession.activeTrip?.driverCoordinate ?? tripSession.pickup.coordinate
                placesSearch.scheduleSearch(
                    newValue,
                    bias: bias,
                    market: appLocale.fareMarket,
                    isPlaceAvailable: isAvailable
                )
            }
            .onDisappear {
                placesSearch.tearDown()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(VuumColor.sheetBackground)
    }

    @ViewBuilder
    private var savedQuickRows: some View {
        sectionHeader(L10n.Destination.savedPlaces)
        if let home = savedPlaces.home, isAvailable(home) {
            placeButton(home)
            VuumHairline()
        }
        if let work = savedPlaces.work, isAvailable(work) {
            placeButton(work)
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(VuumType.captionSemibold)
            .foregroundStyle(VuumColor.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
            .padding(.bottom, 6)
    }

    private func placeRows(_ places: [Place], icon: String? = nil, emphasizedGlyph: Bool? = nil) -> some View {
        ForEach(places) { place in
            placeButton(place, icon: icon, emphasizedGlyph: emphasizedGlyph)
            if place.id != places.last?.id {
                VuumHairline()
            }
        }
    }

    private func placeButton(
        _ place: Place,
        icon: String? = nil,
        emphasizedGlyph: Bool? = nil
    ) -> some View {
        Button {
            confirm(place)
        } label: {
            VuumDestinationPlaceRowContent(
                title: savedPlaces.displayTitle(for: place),
                subtitle: savedPlaces.displaySubtitle(for: place),
                systemImage: icon ?? savedPlaces.systemImage(for: place),
                emphasizedGlyph: emphasizedGlyph ?? savedPlaces.emphasizesRowGlyph(for: place),
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Change destination to \(savedPlaces.displayTitle(for: place))")
    }

    private func suggestionRows(_ items: [PlacesSearchService.PlaceSuggestion]) -> some View {
        ForEach(items) { suggestion in
            Button {
                selectSuggestion(suggestion)
            } label: {
                VuumDestinationPlaceRowContent(
                    title: suggestion.primaryText,
                    subtitle: suggestion.compactSubtitle,
                    systemImage: Self.rowGlyph(from: suggestion.systemImage),
                    emphasizedGlyph: false
                )
            }
            .buttonStyle(.plain)
            .disabled(placesSearch.isResolving)
            VuumHairline()
        }
    }

    private static func rowGlyph(from systemImage: String) -> String {
        if systemImage.contains("mappin") { return "mappin" }
        if systemImage.contains("clock") { return "clock" }
        if systemImage.contains("star") { return "star.fill" }
        if systemImage.hasSuffix(".circle.fill") {
            return String(systemImage.dropLast(".circle.fill".count))
        }
        return systemImage
    }

    private func selectSuggestion(_ suggestion: PlacesSearchService.PlaceSuggestion) {
        Task {
            let place = await placesSearch.resolve(suggestion)
            guard let place, isAvailable(place) else { return }
            confirm(place)
        }
    }

    private func confirm(_ place: Place) {
        savedPlaces.recordRecent(place)
        placesSearch.abandonSession()
        tripSession.updateInTripDestination(place)
        dismiss()
    }
}
