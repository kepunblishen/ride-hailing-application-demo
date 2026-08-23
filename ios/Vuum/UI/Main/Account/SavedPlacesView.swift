import SwiftUI

struct SavedPlacesView: View {
    @EnvironmentObject private var saved: SavedPlacesStore
    @State private var pickTarget: SavedPickTarget?

    var body: some View {
        List {
            Section(L10n.Settings.shortcuts) {
                savedRow(title: L10n.Settings.home, place: saved.home, icon: "house.fill") {
                    pickTarget = .home
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if saved.home != nil {
                        Button(L10n.Common.clear, role: .destructive) { saved.setHome(nil) }
                    }
                }
                savedRow(title: L10n.Settings.work, place: saved.work, icon: "briefcase.fill") {
                    pickTarget = .work
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if saved.work != nil {
                        Button(L10n.Common.clear, role: .destructive) { saved.setWork(nil) }
                    }
                }
            }

            Section(L10n.Settings.favorites) {
                if saved.favorites.isEmpty {
                    VuumInlineEmptyRow(
                        systemImage: "star",
                        title: L10n.t("status.empty_places_title"),
                        message: L10n.t("status.empty_places_detail")
                    )
                } else {
                    ForEach(saved.favorites) { place in
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name)
                                Text(place.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "star.fill")
                                .foregroundStyle(VuumColor.brandInk)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            saved.removeFavorite(saved.favorites[index])
                        }
                    }
                }
                Button {
                    pickTarget = .favorite
                } label: {
                    Label(L10n.Settings.addFavorite, systemImage: "plus.circle")
                }
                .disabled(saved.favorites.count >= SavedPlacesStore.maxFavorites)
            }

            if !saved.recent.isEmpty {
                Section {
                    ForEach(saved.recent) { place in
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(place.name)
                                Text(place.subtitle)
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: "clock")
                                .foregroundStyle(VuumColor.brandInk)
                        }
                        .swipeActions {
                            Button {
                                saved.addFavorite(place)
                            } label: {
                                Label(L10n.Settings.addFavorite, systemImage: "star")
                            }
                            .tint(VuumColor.brandInk)
                        }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            saved.removeRecent(saved.recent[index])
                        }
                    }
                } header: {
                    Text(L10n.Settings.recent)
                } footer: {
                    Button(L10n.t("settings.clear_recent")) {
                        saved.clearRecent()
                    }
                    .font(.footnote)
                }
            }
        }
        .navigationTitle(L10n.Settings.savedPlaces)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $pickTarget) { target in
            PlaceSearchPickerSheet(title: target.pickerTitle) { place in
                apply(place, to: target)
            }
        }
    }

    private func savedRow(
        title: String,
        place: Place?,
        icon: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .foregroundStyle(VuumColor.brandInk)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary)
                    Text(place?.name ?? L10n.Settings.setLocation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .buttonStyle(.plain)
    }

    private func apply(_ place: Place, to target: SavedPickTarget) {
        switch target {
        case .home: saved.setHome(place)
        case .work: saved.setWork(place)
        case .favorite: saved.addFavorite(place)
        }
    }
}

private enum SavedPickTarget: String, Identifiable {
    case home, work, favorite
    var id: String { rawValue }
    var pickerTitle: String {
        switch self {
        case .home: return L10n.Settings.setHome
        case .work: return L10n.Settings.setWork
        case .favorite: return L10n.Settings.addFavorite
        }
    }
}

/// Searchable place picker used by Saved places, Home/Work assignment, and Services booking.
struct PlaceSearchPickerSheet: View {
    @EnvironmentObject private var appLocale: AppLocale
    @EnvironmentObject private var location: RiderLocationManager
    @Environment(\.dismiss) private var dismiss

    let title: String
    var allowClear: Bool = false
    var onClear: (() -> Void)? = nil
    /// Prefer GPS / trip bias when set; otherwise market default center.
    var bias: GeoPoint? = nil
    var excludePlaceIDs: Set<String> = []
    let onSelect: (Place) -> Void

    @StateObject private var placesSearch = PlacesSearchController()
    @State private var query = ""

    private var resolvedBias: GeoPoint {
        if let bias { return bias }
        if let loc = location.latestLocation {
            return GeoPoint(latitude: loc.coordinate.latitude, longitude: loc.coordinate.longitude)
        }
        return appLocale.defaultCenter.coordinate
    }

    private var catalogSuggestions: [Place] {
        appLocale.destinations
            .filter { !excludePlaceIDs.contains($0.id) }
            .prefix(10)
            .map { $0 }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField(L10n.Settings.searchPlaces, text: $query)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                        if placesSearch.isQueryPending || placesSearch.isResolving {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }

                if let status = placesSearch.statusMessage {
                    Section {
                        Text(status)
                            .foregroundStyle(.secondary)
                    }
                }

                if placesSearch.isQueryPending,
                   placesSearch.suggestions.isEmpty,
                   !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        Text(L10n.Destination.searchingPlaces)
                            .foregroundStyle(.secondary)
                    }
                } else if placesSearch.suggestions.isEmpty,
                          !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        Text(L10n.Destination.noMatchingPlaces)
                            .foregroundStyle(.secondary)
                    }
                }

                if !placesSearch.suggestions.isEmpty {
                    Section(L10n.Settings.results) {
                        ForEach(placesSearch.suggestions) { suggestion in
                            Button {
                                select(suggestion)
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: suggestion.systemImage)
                                        .foregroundStyle(VuumColor.brand)
                                        .frame(width: 22)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(suggestion.primaryText)
                                            .foregroundStyle(.primary)
                                        if !suggestion.compactSubtitle.isEmpty {
                                            Text(suggestion.compactSubtitle)
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            .disabled(placesSearch.isResolving)
                        }
                    }
                } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section(L10n.Settings.suggestions) {
                        ForEach(catalogSuggestions) { place in
                            Button {
                                onSelect(place)
                                dismiss()
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    Image(systemName: "mappin.circle.fill")
                                        .foregroundStyle(VuumColor.brand)
                                        .frame(width: 22)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(place.name)
                                            .foregroundStyle(.primary)
                                        Text(place.subtitle)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                        Text(
                                            TripGeo.formatDistance(
                                                TripGeo.distanceMeters(
                                                    from: resolvedBias,
                                                    to: place.coordinate
                                                )
                                            )
                                        )
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.cancel) {
                        placesSearch.abandonSession()
                        dismiss()
                    }
                }
                if allowClear, let onClear {
                    ToolbarItem(placement: .destructiveAction) {
                        Button(L10n.Common.clear) {
                            onClear()
                            dismiss()
                        }
                    }
                }
            }
            .overlay {
                if placesSearch.isResolving {
                    ProgressView()
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .onAppear { placesSearch.beginSession() }
            .onChange(of: query) { _, newValue in
                placesSearch.scheduleSearch(
                    newValue,
                    bias: resolvedBias,
                    market: appLocale.fareMarket,
                    isPlaceAvailable: { !excludePlaceIDs.contains($0.id) }
                )
            }
            .onDisappear { placesSearch.tearDown() }
        }
        .presentationDetents([.medium, .large])
    }

    private func select(_ suggestion: PlacesSearchService.PlaceSuggestion) {
        Task {
            let place = await placesSearch.resolve(suggestion)
            guard let place, !excludePlaceIDs.contains(place.id) else { return }
            onSelect(place)
            dismiss()
        }
    }
}
