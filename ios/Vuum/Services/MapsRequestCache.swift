import CoreLocation
import Foundation

/// Bounded in-memory caches for Google-derived domain results.
/// Caps size and TTL so we do not retain unlimited Places / route / geocode payloads.
enum MapsRequestCache {
    private static let routeTTL: TimeInterval = 120
    private static let placeTTL: TimeInterval = 600
    private static let geocodeTTL: TimeInterval = 90
    private static let maxEntries = 48
    private static let geocodeCellMeters: Double = 35

    private static let routes = BoundedTTLCache<String, RouteEngine.Route>(capacity: maxEntries, ttl: routeTTL)
    private static let places = BoundedTTLCache<String, Place>(capacity: maxEntries, ttl: placeTTL)
    private static let geocodes = BoundedTTLCache<String, ReverseGeocodingService.AddressLabel>(
        capacity: maxEntries,
        ttl: geocodeTTL
    )

    // MARK: - Routes

    static func routeKey(origin: GeoPoint, destination: GeoPoint, intermediates: [GeoPoint] = []) -> String {
        let parts = ([origin] + intermediates + [destination]).map { point in
            String(format: "%.5f,%.5f", point.latitude, point.longitude)
        }
        return parts.joined(separator: "|")
    }

    static func cachedRoute(for key: String) -> RouteEngine.Route? {
        routes.value(for: key)
    }

    static func storeRoute(_ route: RouteEngine.Route, for key: String) {
        guard route.source != .synthetic else { return }
        routes.set(route, for: key)
    }

    // MARK: - Places

    static func cachedPlace(resourceName: String) -> Place? {
        places.value(for: resourceName)
    }

    static func storePlace(_ place: Place, resourceName: String) {
        places.set(place, for: resourceName)
    }

    // MARK: - Reverse geocode

    static func geocodeKey(for location: CLLocationCoordinate2D) -> String {
        let cell = geocodeCellMeters
        let latCell = (location.latitude * 111_320 / cell).rounded()
        let lonScale = max(cos(location.latitude * .pi / 180) * 111_320, 1)
        let lonCell = (location.longitude * lonScale / cell).rounded()
        return "\(Int(latCell)),\(Int(lonCell))"
    }

    static func cachedGeocode(for location: CLLocationCoordinate2D) -> ReverseGeocodingService.AddressLabel? {
        geocodes.value(for: geocodeKey(for: location))
    }

    static func storeGeocode(_ label: ReverseGeocodingService.AddressLabel, for location: CLLocationCoordinate2D) {
        guard !ReverseGeocodingService.isUnresolvedPickupName(label.name) else { return }
        geocodes.set(label, for: geocodeKey(for: location))
    }

    static func clearAll() {
        routes.removeAll()
        places.removeAll()
        geocodes.removeAll()
    }
}
