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

/// Searchable place picker used by Saved places and Home/Work assignment.
struct PlaceSearchPickerSheet: View {
    @EnvironmentObject private var appLocale: AppLocale
    @Environment(\.dismiss) private var dismiss

    let title: String
    var allowClear: Bool = false
    var onClear: (() -> Void)? = nil
    let onSelect: (Place) -> Void

    @State private var query = ""
    @State private var suggestions: [PlacesSearchService.PlaceSuggestion] = []
    @State private var isResolving = false
    @State private var searchTask: Task<Void, Never>?

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
                    }
                }

                if suggestions.isEmpty,
                   !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section {
                        Text(L10n.t("settings.no_matching_places"))
                            .foregroundStyle(.secondary)
                    }
                }

                if !suggestions.isEmpty {
                    Section(L10n.Settings.results) {
                        ForEach(suggestions) { suggestion in
                            Button {
                                select(suggestion)
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(suggestion.primaryText)
                                        .foregroundStyle(.primary)
                                    if !suggestion.secondaryText.isEmpty {
                                        Text(suggestion.secondaryText)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .disabled(isResolving)
                        }
                    }
                } else if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Section(L10n.Settings.suggestions) {
                        ForEach(appLocale.destinations.prefix(10)) { place in
                            Button {
                                onSelect(place)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(place.name)
                                        .foregroundStyle(.primary)
                                    Text(place.subtitle)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
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
                        PlacesSearchService.abandonSession()
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
                if isResolving {
                    ProgressView()
                        .padding(20)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .onAppear { PlacesSearchService.beginSession() }
            .onChange(of: query) { _, newValue in
                scheduleSearch(newValue)
            }
            .onDisappear { searchTask?.cancel() }
        }
        .presentationDetents([.medium, .large])
    }

    private func scheduleSearch(_ raw: String) {
        searchTask?.cancel()
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            suggestions = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(280))
            guard !Task.isCancelled else { return }
            let results = await PlacesSearchService.autocomplete(
                query: trimmed,
                bias: appLocale.defaultCenter.coordinate,
                market: appLocale.fareMarket
            )
            guard !Task.isCancelled else { return }
            suggestions = results
        }
    }

    private func select(_ suggestion: PlacesSearchService.PlaceSuggestion) {
        isResolving = true
        Task {
            let place = await PlacesSearchService.resolve(suggestion)
            await MainActor.run {
                isResolving = false
                if let place {
                    onSelect(place)
                    dismiss()
                }
            }
        }
    }
}
