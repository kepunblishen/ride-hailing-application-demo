import SwiftUI

/// In-trip destination picker — updates dropoff via `TripSession.updateInTripDestination`.
struct ChangeDestinationSheet: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var savedPlaces: SavedPlacesStore
    @EnvironmentObject private var appLocale: AppLocale
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var remoteSuggestions: [PlacesSearchService.PlaceSuggestion] = []
    @State private var searchTask: Task<Void, Never>?
    @State private var isResolving = false

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
            VStack(spacing: 12) {
                if let current = currentDropoff {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(VuumColor.brand)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Current destination")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(VuumColor.secondaryText)
                            Text(current.name)
                                .font(.system(size: 15, weight: .semibold))
                            Text(current.subtitle)
                                .font(.system(size: 12))
                                .foregroundStyle(VuumColor.secondaryText)
                                .lineLimit(2)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 12))
                }

                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(VuumColor.secondaryText)
                    TextField("Search new destination", text: $query)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                    if isResolving || tripSession.isRecalculatingTripRoute {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
                .padding(12)
                .background(VuumColor.fieldBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                Text("Fare and ETA update when you confirm a new place.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VuumColor.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ScrollView {
                    VStack(spacing: 0) {
                        if !isSearching {
                            savedQuickRows
                        }

                        if !filteredFavorites.isEmpty {
                            sectionHeader("Favorites")
                            placeRows(filteredFavorites, icon: "star.fill")
                        }

                        if !filteredRecent.isEmpty {
                            sectionHeader("Recent")
                            placeRows(filteredRecent, icon: "clock.fill")
                        }

                        if isSearching {
                            sectionHeader("Results")
                            if !remoteSuggestions.isEmpty {
                                suggestionRows(remoteSuggestions)
                            } else {
                                Text("No matching places")
                                    .font(.system(size: 14))
                                    .foregroundStyle(VuumColor.secondaryText)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 12)
                            }
                        } else if !filteredSuggestions.isEmpty {
                            sectionHeader("Suggestions")
                            placeRows(filteredSuggestions, icon: "mappin.circle.fill")
                        }
                    }
                }
            }
            .padding(16)
            .navigationTitle(L10n.Trip.changeDestination)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        PlacesSearchService.abandonSession()
                        dismiss()
                    }
                }
            }
            .onAppear {
                PlacesSearchService.beginSession()
            }
            .onChange(of: query) { _, newValue in
                scheduleRemoteSearch(newValue)
            }
            .onDisappear {
                searchTask?.cancel()
            }
        }
    }

    @ViewBuilder
    private var savedQuickRows: some View {
        sectionHeader("Saved places")
        if let home = savedPlaces.home, isAvailable(home) {
            placeButton(home, icon: "house.fill")
            Divider()
        }
        if let work = savedPlaces.work, isAvailable(work) {
            placeButton(work, icon: "briefcase.fill")
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(VuumColor.secondaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 12)
            .padding(.bottom, 6)
    }

    private func placeRows(_ places: [Place], icon: String) -> some View {
        ForEach(places) { place in
            placeButton(place, icon: icon)
            if place.id != places.last?.id {
                Divider()
            }
        }
    }

    private func placeButton(_ place: Place, icon: String) -> some View {
        Button {
            confirm(place)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(VuumColor.brand)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text(place.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VuumColor.primaryText)
                    Text(place.subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(VuumColor.secondaryText)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(VuumColor.secondaryText)
            }
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Change destination to \(place.name)")
    }

    private func suggestionRows(_ items: [PlacesSearchService.PlaceSuggestion]) -> some View {
        ForEach(Array(items.enumerated()), id: \.offset) { _, suggestion in
            Button {
                selectSuggestion(suggestion)
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(VuumColor.brand)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(suggestion.primaryText)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(VuumColor.primaryText)
                        if !suggestion.secondaryText.isEmpty {
                            Text(suggestion.secondaryText)
                                .font(.system(size: 12))
                                .foregroundStyle(VuumColor.secondaryText)
                                .lineLimit(2)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            Divider()
        }
    }

    private func scheduleRemoteSearch(_ raw: String) {
        searchTask?.cancel()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            remoteSuggestions = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            let bias = tripSession.activeTrip?.driverCoordinate ?? tripSession.pickup.coordinate
            let results = await PlacesSearchService.autocomplete(
                query: trimmed,
                bias: bias,
                market: appLocale.fareMarket
            )
            guard !Task.isCancelled else { return }
            remoteSuggestions = results.filter { suggestion in
                if let place = suggestion.place {
                    return isAvailable(place)
                }
                return true
            }
        }
    }

    private func selectSuggestion(_ suggestion: PlacesSearchService.PlaceSuggestion) {
        isResolving = true
        Task {
            let place = await PlacesSearchService.resolve(suggestion)
            await MainActor.run {
                isResolving = false
                guard let place, isAvailable(place) else { return }
                confirm(place)
            }
        }
    }

    private func confirm(_ place: Place) {
        savedPlaces.recordRecent(place)
        PlacesSearchService.abandonSession()
        tripSession.updateInTripDestination(place)
        dismiss()
    }
}
