import Foundation

/// ETA baselines and compressed wall-clock timing for live driver motion.
///
/// Displayed pickup ETAs stay product-real:
/// - standard car ≈ 5 min (`VehiclePickupETA.standardCarMinutes`)
/// - bike / 2-wheels ≈ 2 min
/// - XXL / large ≈ 10 min
///
/// On-map animation uses a shorter wall duration so trips feel live in a presentation build.
enum TripMotionTiming {
    static let carPickupBaselineMinutes = VehiclePickupETA.standardCarMinutes
    static let bikePickupBaselineMinutes = VehiclePickupETA.bikeMinutes
    static let xxlPickupBaselineMinutes = VehiclePickupETA.largeXXLMinutes

    /// Seconds of wall time per displayed ETA minute while the marker moves.
    private static let wallSecondsPerDisplayedMinute = 3.5
    private static let minSimulationSeconds: TimeInterval = 14
    private static let maxSimulationSeconds: TimeInterval = 50

    static func pickupETAMinutes(for vehicleClass: VehicleClass) -> Int {
        VehiclePickupETA.minutes(for: vehicleClass)
    }

    static func pickupETAMinutes(forTierID id: String) -> Int {
        pickupETAMinutes(for: VehicleClass.resolving(tierID: id))
    }

    static func cruiseSpeedKmh(for vehicleClass: VehicleClass) -> Double {
        VehiclePickupETA.approachSpeedKmh(for: vehicleClass)
    }

    static func cruiseSpeedKmh(forTierID id: String) -> Double {
        cruiseSpeedKmh(for: VehicleClass.resolving(tierID: id))
    }

    /// Place the matched driver this far from pickup so distance matches the baseline ETA.
    static func approachDistanceMeters(etaMinutes: Int, vehicleClass: VehicleClass) -> Double {
        let hours = Double(max(etaMinutes, 1)) / 60.0
        return hours * cruiseSpeedKmh(for: vehicleClass) * 1_000.0
    }

    static func approachDistanceMeters(etaMinutes: Int, tierID: String) -> Double {
        approachDistanceMeters(etaMinutes: etaMinutes, vehicleClass: VehicleClass.resolving(tierID: tierID))
    }

    /// Compressed animation duration for Uber-style approach / trip playback.
    static func simulationDurationSeconds(displayedETAMinutes: Int) -> TimeInterval {
        let raw = Double(max(displayedETAMinutes, 1)) * wallSecondsPerDisplayedMinute
        return min(max(raw, minSimulationSeconds), maxSimulationSeconds)
    }

    /// Approach wall-clock duration keyed by fleet class (bike faster match, XL longer).
    static func approachSimulationSeconds(for vehicleClass: VehicleClass) -> TimeInterval {
        simulationDurationSeconds(displayedETAMinutes: pickupETAMinutes(for: vehicleClass))
    }

    /// In-trip wall-clock duration from the displayed trip ETA.
    static func tripSimulationDurationSeconds(displayedETAMinutes: Int) -> TimeInterval {
        let raw = Double(max(displayedETAMinutes, 1)) * 2.8
        return min(max(raw, 18), 55)
    }

    /// Displayed minutes remaining from progress along the path (0…1).
    static func displayedETAMinutes(baseline: Int, fraction: Double) -> Int {
        let f = min(max(fraction, 0), 1)
        if f >= 0.995 { return 0 }
        return max(0, Int(ceil(Double(baseline) * (1 - f))))
    }
}
