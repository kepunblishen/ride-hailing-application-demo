import Foundation

/// Production-feel route builder: Routes API → Directions → synthetic polyline.
enum RouteEngine {
    enum Source: String, Equatable {
        case routes
        case directions
        case synthetic
    }

    struct Route: Equatable {
        var coordinates: [GeoPoint]
        var distanceMeters: Double
        var durationSeconds: TimeInterval
        var source: Source

        var durationMinutes: Int {
            max(1, Int(ceil(durationSeconds / 60.0)))
        }
    }

    /// Single leg origin → destination.
    static func route(from origin: GeoPoint, to destination: GeoPoint) async -> Route {
        if let routes = await RoutesAPIService.computeRoute(origin: origin, destination: destination) {
            return Route(
                coordinates: routes.points,
                distanceMeters: Double(routes.distanceMeters),
                durationSeconds: TimeInterval(routes.durationSeconds),
                source: .routes
            )
        }
        if let live = await DirectionsRouteService.fetchRoute(origin: origin, destination: destination) {
            return Route(
                coordinates: live.coordinates,
                distanceMeters: live.distanceMeters,
                durationSeconds: live.durationSeconds,
                source: .directions
            )
        }
        return synthetic(from: origin, to: destination)
    }

    /// Multi-stop path: first point is origin, last is destination, middle are waypoints.
    static func route(through waypoints: [GeoPoint]) async -> Route {
        guard waypoints.count >= 2 else {
            return Route(coordinates: waypoints, distanceMeters: 0, durationSeconds: 0, source: .synthetic)
        }
        if waypoints.count == 2 {
            return await route(from: waypoints[0], to: waypoints[1])
        }
        let origin = waypoints[0]
        let destination = waypoints[waypoints.count - 1]
        let via = Array(waypoints.dropFirst().dropLast())
        if let routes = await RoutesAPIService.computeRoute(
            origin: origin,
            destination: destination,
            intermediates: via
        ) {
            return Route(
                coordinates: routes.points,
                distanceMeters: Double(routes.distanceMeters),
                durationSeconds: TimeInterval(routes.durationSeconds),
                source: .routes
            )
        }
        if let live = await DirectionsRouteService.fetchRoute(
            origin: origin,
            destination: destination,
            waypoints: via
        ) {
            return Route(
                coordinates: live.coordinates,
                distanceMeters: live.distanceMeters,
                durationSeconds: live.durationSeconds,
                source: .directions
            )
        }
        return synthetic(through: waypoints)
    }

    static func synthetic(from origin: GeoPoint, to destination: GeoPoint, samples: Int = 48) -> Route {
        let coords = TripGeo.routePolyline(from: origin, to: destination, samples: samples)
        let meters = TripGeo.pathLengthMeters(coords)
        let minutes = TripGeo.etaMinutes(distanceMeters: meters, speedKmh: 28)
        return Route(
            coordinates: coords,
            distanceMeters: meters,
            durationSeconds: TimeInterval(minutes * 60),
            source: .synthetic
        )
    }

    static func synthetic(through waypoints: [GeoPoint], samplesPerLeg: Int = 40) -> Route {
        let coords = TripGeo.routePolyline(through: waypoints, samplesPerLeg: samplesPerLeg)
        let meters = TripGeo.pathLengthMeters(coords)
        let minutes = TripGeo.etaMinutes(distanceMeters: meters, speedKmh: 28)
        return Route(
            coordinates: coords,
            distanceMeters: meters,
            durationSeconds: TimeInterval(max(minutes, 1) * 60),
            source: .synthetic
        )
    }
}
