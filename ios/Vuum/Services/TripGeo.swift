import CoreLocation
import Foundation

/// Configurable pickup ETAs by fleet class (presentation defaults).
enum VehiclePickupETA {
    /// Bike / 2-wheels.
    static let bikeMinutes = 2
    /// Standard car (Vuum, Comfort, Courier, …).
    static let standardCarMinutes = 5
    /// XXL / large / executive / group.
    static let largeXXLMinutes = 10

    static func minutes(for vehicleClass: VehicleClass) -> Int {
        switch vehicleClass {
        case .bike: return bikeMinutes
        case .standard: return standardCarMinutes
        case .large: return largeXXLMinutes
        }
    }

    /// Urban approach speed used to place the driver and count down ETA.
    static func approachSpeedKmh(for vehicleClass: VehicleClass) -> Double {
        switch vehicleClass {
        case .bike: return 22
        case .standard: return 28
        case .large: return 24
        }
    }

    /// In-trip cruise speed (slightly slower than approach in dense traffic).
    static func tripSpeedKmh(for vehicleClass: VehicleClass) -> Double {
        switch vehicleClass {
        case .bike: return 20
        case .standard: return 26
        case .large: return 22
        }
    }

    /// Straight-line offset so a fresh match starts at ~class ETA away from pickup.
    static func spawnDistanceMeters(for vehicleClass: VehicleClass) -> Double {
        let hours = Double(minutes(for: vehicleClass)) / 60.0
        return hours * approachSpeedKmh(for: vehicleClass) * 1_000.0
    }

    /// Wall-clock seconds for approach animation — single source via `TripMotionTiming`.
    static func approachSimulationSeconds(for vehicleClass: VehicleClass) -> TimeInterval {
        TripMotionTiming.approachSimulationSeconds(for: vehicleClass)
    }
}

enum TripGeo {
    static func distanceMeters(from a: GeoPoint, to b: GeoPoint) -> Double {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    /// Offset a point by approximate north/east meters (local tangent plane).
    static func offset(_ point: GeoPoint, northMeters: Double, eastMeters: Double) -> GeoPoint {
        let metersPerDegLat = 111_320.0
        let metersPerDegLon = max(cos(point.latitude * .pi / 180) * 111_320.0, 1)
        return GeoPoint(
            latitude: point.latitude + northMeters / metersPerDegLat,
            longitude: point.longitude + eastMeters / metersPerDegLon
        )
    }

    /// Circle suitable for Places `locationBias` around a bias point.
    static func biasRadiusMeters(for market: AppLocale.Market) -> Double {
        switch market {
        case .kenya: return 60_000
        case .drc, .both: return 120_000
        }
    }

    static func bearingDegrees(from a: GeoPoint, to b: GeoPoint) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        let bearing = atan2(y, x) * 180 / .pi
        return (bearing + 360).truncatingRemainder(dividingBy: 360)
    }

    static func interpolate(from a: GeoPoint, to b: GeoPoint, fraction t: Double) -> GeoPoint {
        let u = min(max(t, 0), 1)
        return GeoPoint(
            latitude: a.latitude + (b.latitude - a.latitude) * u,
            longitude: a.longitude + (b.longitude - a.longitude) * u
        )
    }

    /// Curved path so the map looks like a road route, not a straight line.
    static func routePolyline(from start: GeoPoint, to end: GeoPoint, samples: Int = 48) -> [GeoPoint] {
        let count = max(samples, 8)
        let mid = interpolate(from: start, to: end, fraction: 0.5)
        let dx = end.longitude - start.longitude
        let dy = end.latitude - start.latitude
        let offsetScale = 0.22
        let control = GeoPoint(
            latitude: mid.latitude - dx * offsetScale,
            longitude: mid.longitude + dy * offsetScale
        )

        var points: [GeoPoint] = []
        points.reserveCapacity(count + 1)
        for i in 0...count {
            let t = Double(i) / Double(count)
            let ab = interpolate(from: start, to: control, fraction: t)
            let bc = interpolate(from: control, to: end, fraction: t)
            points.append(interpolate(from: ab, to: bc, fraction: t))
        }
        return points
    }

    /// Concatenate leg polylines through waypoints (pickup → stops → dropoff).
    static func routePolyline(through waypoints: [GeoPoint], samplesPerLeg: Int = 48) -> [GeoPoint] {
        guard waypoints.count >= 2 else { return waypoints }
        var result: [GeoPoint] = []
        for i in 0..<(waypoints.count - 1) {
            let leg = routePolyline(from: waypoints[i], to: waypoints[i + 1], samples: samplesPerLeg)
            if result.isEmpty {
                result = leg
            } else {
                result.append(contentsOf: leg.dropFirst())
            }
        }
        return result
    }

    static func pathLengthMeters(_ points: [GeoPoint]) -> Double {
        guard points.count > 1 else { return 0 }
        var total = 0.0
        for i in 1..<points.count {
            total += distanceMeters(from: points[i - 1], to: points[i])
        }
        return total
    }

    /// Remaining path length for a distance-based fraction (0…1), not a point-index fraction.
    static func remainingDistanceMeters(path: [GeoPoint], fraction: Double) -> Double {
        let total = pathLengthMeters(path)
        let f = min(max(fraction, 0), 1)
        return max(0, total * (1 - f))
    }

    static func pointAlong(path: [GeoPoint], fraction: Double) -> (point: GeoPoint, heading: Double) {
        guard path.count > 1 else {
            return (path.first ?? GeoPoint(latitude: 0, longitude: 0), 0)
        }
        let total = pathLengthMeters(path)
        let target = min(max(fraction, 0), 1) * total
        if target <= 0 {
            return (path[0], bearingDegrees(from: path[0], to: path[1]))
        }
        if target >= total {
            let last = path[path.count - 1]
            let prev = path[path.count - 2]
            return (last, bearingDegrees(from: prev, to: last))
        }
        var walked = 0.0
        for i in 1..<path.count {
            let seg = distanceMeters(from: path[i - 1], to: path[i])
            if walked + seg >= target {
                let local = seg > 0 ? (target - walked) / seg : 1
                let point = interpolate(from: path[i - 1], to: path[i], fraction: local)
                let heading = bearingDegrees(from: path[i - 1], to: path[i])
                return (point, heading)
            }
            walked += seg
        }
        let last = path[path.count - 1]
        let prev = path[path.count - 2]
        return (last, bearingDegrees(from: prev, to: last))
    }

    static func etaMinutes(distanceMeters: Double, speedKmh: Double = 28) -> Int {
        guard distanceMeters > 1 else { return 0 }
        let hours = distanceMeters / 1000.0 / max(speedKmh, 1)
        return max(1, Int(ceil(hours * 60)))
    }

    /// Pickup ETA clamped toward the published vehicle-class target as the driver approaches.
    static func pickupETAMinutes(
        remainingMeters: Double,
        vehicleClass: VehicleClass,
        progressFraction: Double
    ) -> Int {
        let speed = VehiclePickupETA.approachSpeedKmh(for: vehicleClass)
        let fromDistance = etaMinutes(distanceMeters: remainingMeters, speedKmh: speed)
        let classTarget = VehiclePickupETA.minutes(for: vehicleClass)
        let p = min(max(progressFraction, 0), 1)
        if p <= 0.02 {
            return classTarget
        }
        if remainingMeters < 35 {
            return 0
        }
        // Blend so the first frame matches the tier row, then tracks route progress.
        let blended = Int((Double(classTarget) * (1 - p) + Double(fromDistance) * p).rounded())
        return max(1, blended)
    }

    static func formatDistance(_ meters: Double) -> String {
        if meters >= 1000 {
            return String(format: "%.1f km", meters / 1000)
        }
        return "\(Int(meters.rounded())) m"
    }

    static func formatDuration(minutes: Int) -> String {
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
        }
        return "\(minutes) min"
    }

    /// Path from the closest point on `path` to `coordinate` through the rest of the polyline.
    /// Used by Maps to draw only the remaining approach / trip segment.
    static func remainingPath(along path: [GeoPoint], from coordinate: GeoPoint) -> [GeoPoint] {
        guard path.count > 1 else { return path }
        let total = pathLengthMeters(path)
        guard total > 1 else { return path }

        var bestIndex = 0
        var bestDist = Double.greatestFiniteMagnitude
        var walkedToBest = 0.0
        var walked = 0.0
        for i in 0..<path.count {
            if i > 0 {
                walked += distanceMeters(from: path[i - 1], to: path[i])
            }
            let d = distanceMeters(from: path[i], to: coordinate)
            if d < bestDist {
                bestDist = d
                bestIndex = i
                walkedToBest = walked
            }
        }

        var result: [GeoPoint] = [coordinate]
        if bestIndex + 1 < path.count {
            result.append(contentsOf: path[(bestIndex + 1)...])
        } else if let last = path.last {
            result = [coordinate, last]
        }
        _ = walkedToBest
        return result
    }

    /// Distance-fraction (0…1) of the closest path vertex to `coordinate`.
    static func progressFraction(along path: [GeoPoint], near coordinate: GeoPoint) -> Double {
        guard path.count > 1 else { return 0 }
        let total = pathLengthMeters(path)
        guard total > 1 else { return 0 }
        var bestFrac = 0.0
        var bestDist = Double.greatestFiniteMagnitude
        var walked = 0.0
        for i in 0..<path.count {
            if i > 0 {
                walked += distanceMeters(from: path[i - 1], to: path[i])
            }
            let d = distanceMeters(from: path[i], to: coordinate)
            if d < bestDist {
                bestDist = d
                bestFrac = walked / total
            }
        }
        return min(max(bestFrac, 0), 1)
    }

    // MARK: - Route corridor / deviation

    /// Shortest distance from `point` to any segment of `path` (meters).
    static func distanceToPolylineMeters(_ point: GeoPoint, path: [GeoPoint]) -> Double {
        guard !path.isEmpty else { return .greatestFiniteMagnitude }
        if path.count == 1 {
            return distanceMeters(from: point, to: path[0])
        }
        var best = Double.greatestFiniteMagnitude
        for i in 1..<path.count {
            let d = distanceToSegmentMeters(point, a: path[i - 1], b: path[i])
            if d < best { best = d }
        }
        return best
    }

    /// Closest point on the polyline to `point`, with distance in meters.
    static func closestPointOnPolyline(
        _ point: GeoPoint,
        path: [GeoPoint]
    ) -> (point: GeoPoint, distanceMeters: Double) {
        guard !path.isEmpty else {
            return (point, .greatestFiniteMagnitude)
        }
        if path.count == 1 {
            return (path[0], distanceMeters(from: point, to: path[0]))
        }
        var bestPoint = path[0]
        var bestDist = Double.greatestFiniteMagnitude
        for i in 1..<path.count {
            let projected = closestPointOnSegment(point, a: path[i - 1], b: path[i])
            let d = distanceMeters(from: point, to: projected)
            if d < bestDist {
                bestDist = d
                bestPoint = projected
            }
        }
        return (bestPoint, bestDist)
    }

    /// Perpendicular-ish offset from `point` given a heading (degrees clockwise from north).
    static func offsetPerpendicular(
        _ point: GeoPoint,
        headingDegrees: Double,
        meters: Double
    ) -> GeoPoint {
        let rad = (headingDegrees + 90) * .pi / 180
        let north = cos(rad) * meters
        let east = sin(rad) * meters
        return offset(point, northMeters: north, eastMeters: east)
    }

    /// True when `point` is farther than `corridorMeters` from the expected route.
    static func isOffRoute(
        _ point: GeoPoint,
        expectedRoute: [GeoPoint],
        corridorMeters: Double = RouteDeviationMonitor.defaultCorridorMeters
    ) -> Bool {
        distanceToPolylineMeters(point, path: expectedRoute) > corridorMeters
    }

    /// Distance from `point` to the infinite-line projection clamped to segment `a`→`b`.
    static func distanceToSegmentMeters(_ point: GeoPoint, a: GeoPoint, b: GeoPoint) -> Double {
        distanceMeters(from: point, to: closestPointOnSegment(point, a: a, b: b))
    }

    static func closestPointOnSegment(_ point: GeoPoint, a: GeoPoint, b: GeoPoint) -> GeoPoint {
        let ax = a.longitude
        let ay = a.latitude
        let bx = b.longitude
        let by = b.latitude
        let px = point.longitude
        let py = point.latitude
        let abx = bx - ax
        let aby = by - ay
        let abLen2 = abx * abx + aby * aby
        guard abLen2 > 1e-18 else { return a }
        // Local meters scale so lon/lat projection is roughly isotropic near the segment.
        let midLat = (ay + by) * 0.5
        let metersPerDegLat = 111_320.0
        let metersPerDegLon = max(cos(midLat * .pi / 180) * 111_320.0, 1)
        let abxM = abx * metersPerDegLon
        let abyM = aby * metersPerDegLat
        let apxM = (px - ax) * metersPerDegLon
        let apyM = (py - ay) * metersPerDegLat
        let t = min(max((apxM * abxM + apyM * abyM) / (abxM * abxM + abyM * abyM), 0), 1)
        return interpolate(from: a, to: b, fraction: t)
    }

    // MARK: - Geofencing

    static func contains(_ point: GeoPoint, in geofence: ZoneGeofence) -> Bool {
        switch geofence {
        case .circle(let center, let radiusMeters):
            return distanceMeters(from: point, to: center) <= radiusMeters
        case .polygon(let vertices):
            return pointInPolygon(point, vertices: vertices)
        }
    }

    /// Ray-casting point-in-polygon (lon/lat treated as planar for small city polygons).
    static func pointInPolygon(_ point: GeoPoint, vertices: [GeoPoint]) -> Bool {
        guard vertices.count >= 3 else { return false }
        var inside = false
        var j = vertices.count - 1
        for i in 0..<vertices.count {
            let yi = vertices[i].latitude
            let xi = vertices[i].longitude
            let yj = vertices[j].latitude
            let xj = vertices[j].longitude
            let intersect = ((yi > point.latitude) != (yj > point.latitude))
                && (point.longitude < (xj - xi) * (point.latitude - yi) / max(yj - yi, 1e-12) + xi)
            if intersect { inside.toggle() }
            j = i
        }
        return inside
    }
}
