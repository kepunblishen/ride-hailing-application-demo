import Foundation

/// Backend-ready routing surface. `TripSession` / booking UI depend on this contract,
/// not on Routes or Directions HTTP details.
///
/// Swap `GoogleRouteProvider` for a future `RemoteVuumRouteProvider` without rewriting trip flow.
protocol RouteProvider: Sendable {
    func route(from origin: GeoPoint, to destination: GeoPoint) async -> RouteEngine.Route
    func route(through waypoints: [GeoPoint]) async -> RouteEngine.Route
}

/// Locked stack: **Routes API primary** → **Directions API fallback** → **synthetic**.
///
/// Identical O/D (+ intermediates) reuse a short-TTL cache (`MapsRequestCache`).
/// See `docs/GOOGLE_MAPS_ARCHITECTURE.md` (§ Directions vs Routes).
struct GoogleRouteProvider: RouteProvider {
    func route(from origin: GeoPoint, to destination: GeoPoint) async -> RouteEngine.Route {
        let key = MapsRequestCache.routeKey(origin: origin, destination: destination)
        if let cached = MapsRequestCache.cachedRoute(for: key) {
            return cached
        }
        let built = await fetchLiveOrSynthetic(from: origin, to: destination, intermediates: [], waypoints: [origin, destination])
        if !Task.isCancelled, built.hasRoadGeometry || built.isTrafficAware {
            MapsRequestCache.storeRoute(built, for: key)
        }
        return built
    }

    func route(through waypoints: [GeoPoint]) async -> RouteEngine.Route {
        guard waypoints.count >= 2 else {
            return RouteEngine.emptyRoute(waypoints: waypoints)
        }
        if waypoints.count == 2 {
            return await route(from: waypoints[0], to: waypoints[1])
        }
        let origin = waypoints[0]
        let destination = waypoints[waypoints.count - 1]
        let via = Array(waypoints.dropFirst().dropLast())
        let key = MapsRequestCache.routeKey(origin: origin, destination: destination, intermediates: via)
        if let cached = MapsRequestCache.cachedRoute(for: key) {
            return cached
        }
        let built = await fetchLiveOrSynthetic(
            from: origin,
            to: destination,
            intermediates: via,
            waypoints: waypoints
        )
        if !Task.isCancelled, built.hasRoadGeometry || built.isTrafficAware {
            MapsRequestCache.storeRoute(built, for: key)
        }
        return built
    }

    private func fetchLiveOrSynthetic(
        from origin: GeoPoint,
        to destination: GeoPoint,
        intermediates: [GeoPoint],
        waypoints: [GeoPoint]
    ) async -> RouteEngine.Route {
        // Cooperative cancel: never chain Routes → Directions after the caller Task is cancelled
        // (trip cancel / superseding fetch must not bill a second Google hop).
        if Task.isCancelled {
            return syntheticFallback(origin: origin, destination: destination, intermediates: intermediates, waypoints: waypoints)
        }
        if let routes = await RoutesAPIService.computeRoute(
            origin: origin,
            destination: destination,
            intermediates: intermediates
        ) {
            return RouteEngine.mapRoutesAPI(routes, waypoints: waypoints)
        }
        if Task.isCancelled {
            return syntheticFallback(origin: origin, destination: destination, intermediates: intermediates, waypoints: waypoints)
        }
        if let live = await DirectionsRouteService.fetchRoute(
            origin: origin,
            destination: destination,
            waypoints: intermediates
        ) {
            return RouteEngine.mapDirections(live, waypoints: waypoints)
        }
        return syntheticFallback(origin: origin, destination: destination, intermediates: intermediates, waypoints: waypoints)
    }

    private func syntheticFallback(
        origin: GeoPoint,
        destination: GeoPoint,
        intermediates: [GeoPoint],
        waypoints: [GeoPoint]
    ) -> RouteEngine.Route {
        if intermediates.isEmpty {
            return RouteEngine.synthetic(from: origin, to: destination)
        }
        return RouteEngine.synthetic(through: waypoints)
    }
}
