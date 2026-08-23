import Foundation

/// Production route builder facade over `RouteProvider`.
///
/// Default provider: **Routes API** (traffic-aware) → **Directions** fallback → **synthetic**.
/// Always returns a drawable polyline. Live road geometry requires `VUUM_GOOGLE_MAPS_API_KEY`
/// with Routes (preferred) and/or Directions enabled. Directions is kept only as fallback when
/// Routes is unavailable or fails — not as a parallel primary stack.
enum RouteEngine {
    /// Injectable for tests / future `RemoteVuumRouteProvider`. Prefer `GoogleRouteProvider`.
    static var provider: any RouteProvider = GoogleRouteProvider()

    enum Source: String, Equatable {
        case routes
        case directions
        case synthetic
    }

    /// One origin→destination (or via) segment within a multi-stop route.
    struct RouteLeg: Equatable {
        var coordinates: [GeoPoint]
        var distanceMeters: Double
        /// Preferred duration for this leg (traffic when available).
        var durationSeconds: TimeInterval
        /// Duration without live traffic, when the API provided it separately.
        var staticDurationSeconds: TimeInterval?
        /// Traffic-aware duration when distinct from static.
        var trafficDurationSeconds: TimeInterval?

        var durationMinutes: Int {
            max(1, Int(ceil(durationSeconds / 60.0)))
        }
    }

    /// VUUM domain route — never pass raw Google JSON into SwiftUI.
    struct Route: Equatable {
        var coordinates: [GeoPoint]
        var distanceMeters: Double
        /// Preferred duration for ETA (traffic-aware when `isTrafficAware`).
        var durationSeconds: TimeInterval
        /// Traffic-aware duration when the API provided it; mirrors `durationSeconds` for live routes.
        var trafficDurationSeconds: TimeInterval?
        /// Duration without live traffic (Routes `staticDuration` / Directions `duration`).
        var staticDurationSeconds: TimeInterval?
        var source: Source
        /// Waypoint count used for the request (origin + intermediates + destination).
        var waypointCount: Int
        /// Request waypoints (origin … destination) used to build this route.
        var waypoints: [GeoPoint]
        /// Per-leg geometry and durations when the provider returned them.
        var legs: [RouteLeg]
        /// True when duration reflects live/traffic routing rather than fixed-speed synthetic ETA.
        var isTrafficAware: Bool

        var durationMinutes: Int {
            max(1, Int(ceil(durationSeconds / 60.0)))
        }

        var hasRoadGeometry: Bool {
            source != .synthetic && coordinates.count >= 2
        }

        /// ETA minutes for remaining progress along this route (0…1 complete).
        func etaMinutesRemaining(fractionComplete: Double) -> Int {
            TripMotionTiming.displayedETAMinutes(baseline: durationMinutes, fraction: fractionComplete)
        }

        /// Scale full-route duration to a sub-path length (in-trip legs / remaining distance).
        func etaMinutes(forRemainingMeters remaining: Double) -> Int {
            guard durationSeconds > 0, distanceMeters > 1, remaining > 1 else {
                return remaining > 1 ? max(1, Int(ceil(remaining / distanceMeters * Double(durationMinutes)))) : 0
            }
            let fraction = min(1, max(0, remaining / distanceMeters))
            return max(1, Int(ceil(durationSeconds * fraction / 60.0)))
        }
    }

    /// Single leg origin → destination.
    static func route(from origin: GeoPoint, to destination: GeoPoint) async -> Route {
        await provider.route(from: origin, to: destination)
    }

    /// Multi-stop path: first point is origin, last is destination, middle are waypoints.
    static func route(through waypoints: [GeoPoint]) async -> Route {
        await provider.route(through: waypoints)
    }

    static func emptyRoute(waypoints: [GeoPoint]) -> Route {
        Route(
            coordinates: waypoints,
            distanceMeters: 0,
            durationSeconds: 0,
            trafficDurationSeconds: nil,
            staticDurationSeconds: nil,
            source: .synthetic,
            waypointCount: waypoints.count,
            waypoints: waypoints,
            legs: [],
            isTrafficAware: false
        )
    }

    static func synthetic(from origin: GeoPoint, to destination: GeoPoint, samples: Int = 48) -> Route {
        let coords = TripGeo.routePolyline(from: origin, to: destination, samples: samples)
        let meters = TripGeo.pathLengthMeters(coords)
        let minutes = TripGeo.etaMinutes(distanceMeters: meters, speedKmh: 28)
        let duration = TimeInterval(minutes * 60)
        let leg = RouteLeg(
            coordinates: coords,
            distanceMeters: meters,
            durationSeconds: duration,
            staticDurationSeconds: duration,
            trafficDurationSeconds: nil
        )
        return Route(
            coordinates: coords,
            distanceMeters: meters,
            durationSeconds: duration,
            trafficDurationSeconds: nil,
            staticDurationSeconds: duration,
            source: .synthetic,
            waypointCount: 2,
            waypoints: [origin, destination],
            legs: [leg],
            isTrafficAware: false
        )
    }

    static func synthetic(through waypoints: [GeoPoint], samplesPerLeg: Int = 40) -> Route {
        guard waypoints.count >= 2 else { return emptyRoute(waypoints: waypoints) }
        var allCoords: [GeoPoint] = []
        var legs: [RouteLeg] = []
        var totalMeters = 0.0
        var totalDuration: TimeInterval = 0
        for i in 0..<(waypoints.count - 1) {
            let a = waypoints[i]
            let b = waypoints[i + 1]
            let coords = TripGeo.routePolyline(from: a, to: b, samples: samplesPerLeg)
            let meters = TripGeo.pathLengthMeters(coords)
            let minutes = TripGeo.etaMinutes(distanceMeters: meters, speedKmh: 28)
            let duration = TimeInterval(max(minutes, 1) * 60)
            if allCoords.isEmpty {
                allCoords.append(contentsOf: coords)
            } else if coords.count > 1 {
                allCoords.append(contentsOf: coords.dropFirst())
            }
            legs.append(
                RouteLeg(
                    coordinates: coords,
                    distanceMeters: meters,
                    durationSeconds: duration,
                    staticDurationSeconds: duration,
                    trafficDurationSeconds: nil
                )
            )
            totalMeters += meters
            totalDuration += duration
        }
        return Route(
            coordinates: allCoords,
            distanceMeters: totalMeters,
            durationSeconds: max(totalDuration, 60),
            trafficDurationSeconds: nil,
            staticDurationSeconds: max(totalDuration, 60),
            source: .synthetic,
            waypointCount: waypoints.count,
            waypoints: waypoints,
            legs: legs,
            isTrafficAware: false
        )
    }

    // MARK: - Provider mapping (domain only)

    static func mapRoutesAPI(_ computed: RoutesAPIService.ComputedRoute, waypoints: [GeoPoint]) -> Route {
        let traffic = TimeInterval(max(computed.durationSeconds, 1))
        let staticDur: TimeInterval? = computed.staticDurationSeconds.map { TimeInterval(max($0, 1)) }
        let legs: [RouteLeg] = computed.legs.isEmpty
            ? [
                RouteLeg(
                    coordinates: computed.points,
                    distanceMeters: Double(computed.distanceMeters),
                    durationSeconds: traffic,
                    staticDurationSeconds: staticDur,
                    trafficDurationSeconds: traffic
                )
            ]
            : computed.legs.map { leg in
                let legTraffic = TimeInterval(max(leg.durationSeconds, 1))
                let legStatic: TimeInterval? = leg.staticDurationSeconds.map { TimeInterval(max($0, 1)) }
                return RouteLeg(
                    coordinates: leg.points,
                    distanceMeters: Double(leg.distanceMeters),
                    durationSeconds: legTraffic,
                    staticDurationSeconds: legStatic,
                    trafficDurationSeconds: legTraffic
                )
            }
        return Route(
            coordinates: computed.points,
            distanceMeters: Double(computed.distanceMeters),
            durationSeconds: traffic,
            trafficDurationSeconds: traffic,
            staticDurationSeconds: staticDur,
            source: .routes,
            waypointCount: waypoints.count,
            waypoints: waypoints,
            legs: legs,
            isTrafficAware: true
        )
    }

    static func mapDirections(_ live: DirectionsRouteService.LegResult, waypoints: [GeoPoint]) -> Route {
        let traffic = max(live.durationSeconds, 1)
        let staticDur = live.staticDurationSeconds.map { max($0, 1) }
        let legs: [RouteLeg] = live.legs.isEmpty
            ? [
                RouteLeg(
                    coordinates: live.coordinates,
                    distanceMeters: live.distanceMeters,
                    durationSeconds: traffic,
                    staticDurationSeconds: staticDur,
                    trafficDurationSeconds: live.trafficDurationSeconds.map { max($0, 1) }
                )
            ]
            : live.legs.map { leg in
                RouteLeg(
                    coordinates: leg.coordinates,
                    distanceMeters: leg.distanceMeters,
                    durationSeconds: max(leg.durationSeconds, 1),
                    staticDurationSeconds: leg.staticDurationSeconds.map { max($0, 1) },
                    trafficDurationSeconds: leg.trafficDurationSeconds.map { max($0, 1) }
                )
            }
        return Route(
            coordinates: live.coordinates,
            distanceMeters: live.distanceMeters,
            durationSeconds: traffic,
            trafficDurationSeconds: live.trafficDurationSeconds.map { max($0, 1) } ?? traffic,
            staticDurationSeconds: staticDur,
            source: .directions,
            waypointCount: waypoints.count,
            waypoints: waypoints,
            legs: legs,
            isTrafficAware: true
        )
    }
}
