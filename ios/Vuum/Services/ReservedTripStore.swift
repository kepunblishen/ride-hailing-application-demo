import Foundation

enum ReservedTripStore {
    private static let key = "vuum.reservedTrips"

    static func load() -> [ReservedTrip] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([ReservedTrip].self, from: data)
        else { return [] }
        return decoded.sorted { $0.when < $1.when }
    }

    static func save(_ trips: [ReservedTrip]) {
        let trimmed = Array(trips.prefix(30))
        if let data = try? JSONEncoder().encode(trimmed) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
}
