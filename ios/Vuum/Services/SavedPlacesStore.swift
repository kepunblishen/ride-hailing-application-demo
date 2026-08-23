import Combine
import Foundation

/// Home, Work, Favorites, and recent destinations — persisted in UserDefaults.
@MainActor
final class SavedPlacesStore: ObservableObject {
    private enum Keys {
        static let home = "vuum.saved.home"
        static let work = "vuum.saved.work"
        static let favorites = "vuum.saved.favorites"
        static let recent = "vuum.saved.recent"
    }

    static let maxFavorites = 12
    static let maxRecent = 8

    @Published private(set) var home: Place?
    @Published private(set) var work: Place?
    @Published private(set) var favorites: [Place]
    @Published private(set) var recent: [Place]

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        home = Self.decode(Place.self, key: Keys.home, defaults: defaults, decoder: decoder)
        work = Self.decode(Place.self, key: Keys.work, defaults: defaults, decoder: decoder)
        favorites = Self.decode([Place].self, key: Keys.favorites, defaults: defaults, decoder: decoder) ?? []
        recent = Self.decode([Place].self, key: Keys.recent, defaults: defaults, decoder: decoder) ?? []
    }

    /// Home → Work → favorites → recent (deduped), for Home chips / empty destination query.
    var suggestionPlaces: [Place] {
        var seen = Set<String>()
        var result: [Place] = []
        func append(_ place: Place?) {
            guard let place, !seen.contains(place.id) else { return }
            seen.insert(place.id)
            result.append(place)
        }
        append(home)
        append(work)
        favorites.forEach { append($0) }
        recent.forEach { append($0) }
        return result
    }

    func kind(for place: Place) -> SavedPlaceKind? {
        if home?.id == place.id { return .home }
        if work?.id == place.id { return .work }
        if favorites.contains(where: { $0.id == place.id }) { return .favorite }
        if recent.contains(where: { $0.id == place.id }) { return .recent }
        return nil
    }

    func displayTitle(for place: Place) -> String {
        switch kind(for: place) {
        case .home: return L10n.Settings.home
        case .work: return L10n.Settings.work
        default: return place.name
        }
    }

    func systemImage(for place: Place) -> String {
        kind(for: place)?.systemImage ?? "mappin.circle.fill"
    }

    func setHome(_ place: Place?) {
        home = place
        persist(place, key: Keys.home)
        if let place { recordRecent(place) }
    }

    func setWork(_ place: Place?) {
        work = place
        persist(place, key: Keys.work)
        if let place { recordRecent(place) }
    }

    func isFavorite(_ place: Place) -> Bool {
        favorites.contains { $0.id == place.id }
    }

    func toggleFavorite(_ place: Place) {
        if isFavorite(place) {
            removeFavorite(place)
        } else {
            addFavorite(place)
        }
    }

    func addFavorite(_ place: Place) {
        favorites.removeAll { $0.id == place.id }
        favorites.insert(place, at: 0)
        if favorites.count > Self.maxFavorites {
            favorites = Array(favorites.prefix(Self.maxFavorites))
        }
        persist(favorites, key: Keys.favorites)
        recordRecent(place)
    }

    func removeFavorite(_ place: Place) {
        favorites.removeAll { $0.id == place.id }
        persist(favorites, key: Keys.favorites)
    }

    func recordRecent(_ place: Place) {
        recent.removeAll { $0.id == place.id }
        recent.insert(place, at: 0)
        if recent.count > Self.maxRecent {
            recent = Array(recent.prefix(Self.maxRecent))
        }
        persist(recent, key: Keys.recent)
    }

    func removeRecent(_ place: Place) {
        recent.removeAll { $0.id == place.id }
        persist(recent, key: Keys.recent)
    }

    func clearRecent() {
        recent = []
        defaults.removeObject(forKey: Keys.recent)
    }

    /// Places suitable for product pickup/drop pickers: current center + saved + catalog.
    func bookingPlaces(center: Place, catalog: [Place]) -> [Place] {
        var seen = Set<String>()
        var result: [Place] = []
        func append(_ place: Place?) {
            guard let place, seen.insert(place.id).inserted else { return }
            result.append(place)
        }
        append(center)
        append(home)
        append(work)
        favorites.forEach { append($0) }
        recent.forEach { append($0) }
        catalog.forEach { append($0) }
        return result
    }

    // MARK: - Persistence

    private func persist<T: Encodable>(_ value: T?, key: String) {
        guard let value else {
            defaults.removeObject(forKey: key)
            return
        }
        guard let data = try? encoder.encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func decode<T: Decodable>(
        _ type: T.Type,
        key: String,
        defaults: UserDefaults,
        decoder: JSONDecoder
    ) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(type, from: data)
    }
}
