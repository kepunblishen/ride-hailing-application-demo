import Foundation

/// Tracks whether the vehicle stays within a corridor around the expected trip polyline.
///
/// Detection is pure geo math (distance-to-polyline). A rider-facing notice is raised only after
/// the off-route condition **persists**, so brief GPS jitter or a short lane change does not alert.
struct RouteDeviationMonitor {
    static let defaultCorridorMeters: Double = 90
    /// Must stay off-corridor this long before the rider notice appears.
    static let defaultPersistSeconds: TimeInterval = 6
    /// Must stay back inside the recover radius this long before the notice clears.
    static let defaultRecoverSeconds: TimeInterval = 3
    /// Hysteresis: clear when closer than this (meters), raise when farther than corridor.
    static let defaultRecoverMeters: Double = 55

    /// Rider-facing copy (no internal / mock wording).
    static let riderNotice =
        "Your driver appears to be off the planned route. You can share your live trip with a trusted contact."

    var corridorMeters: Double
    var persistSeconds: TimeInterval
    var recoverSeconds: TimeInterval
    var recoverMeters: Double

    private(set) var offRouteSince: Date?
    private(set) var onRouteSince: Date?
    private(set) var isNoticeActive = false
    private(set) var lastDistanceMeters: Double = 0
    /// True once for each new notice activation (UI / inbox can consume).
    private(set) var didActivateNoticeThisTick = false

    init(
        corridorMeters: Double = Self.defaultCorridorMeters,
        persistSeconds: TimeInterval = Self.defaultPersistSeconds,
        recoverSeconds: TimeInterval = Self.defaultRecoverSeconds,
        recoverMeters: Double = Self.defaultRecoverMeters
    ) {
        self.corridorMeters = corridorMeters
        self.persistSeconds = persistSeconds
        self.recoverSeconds = recoverSeconds
        self.recoverMeters = recoverMeters
    }

    mutating func reset() {
        offRouteSince = nil
        onRouteSince = nil
        isNoticeActive = false
        lastDistanceMeters = 0
        didActivateNoticeThisTick = false
    }

    /// Evaluate vehicle position against the expected route corridor.
    @discardableResult
    mutating func evaluate(
        position: GeoPoint,
        expectedRoute: [GeoPoint],
        now: Date = Date()
    ) -> RouteDeviationSnapshot {
        didActivateNoticeThisTick = false
        guard expectedRoute.count >= 2 else {
            reset()
            return snapshot(isOffCorridor: false)
        }

        let distance = TripGeo.distanceToPolylineMeters(position, path: expectedRoute)
        lastDistanceMeters = distance

        let leaveThreshold = corridorMeters
        let returnThreshold = min(recoverMeters, corridorMeters)

        if isNoticeActive {
            if distance <= returnThreshold {
                if onRouteSince == nil { onRouteSince = now }
                offRouteSince = nil
                if let started = onRouteSince, now.timeIntervalSince(started) >= recoverSeconds {
                    isNoticeActive = false
                    onRouteSince = nil
                }
            } else {
                onRouteSince = nil
                if offRouteSince == nil { offRouteSince = now }
            }
        } else {
            if distance > leaveThreshold {
                if offRouteSince == nil { offRouteSince = now }
                onRouteSince = nil
                if let started = offRouteSince, now.timeIntervalSince(started) >= persistSeconds {
                    isNoticeActive = true
                    didActivateNoticeThisTick = true
                    onRouteSince = nil
                }
            } else {
                offRouteSince = nil
                onRouteSince = now
            }
        }

        return snapshot(isOffCorridor: distance > leaveThreshold)
    }

    private func snapshot(isOffCorridor: Bool) -> RouteDeviationSnapshot {
        RouteDeviationSnapshot(
            distanceMeters: lastDistanceMeters,
            isOffCorridor: isOffCorridor,
            isNoticeActive: isNoticeActive,
            didActivateNotice: didActivateNoticeThisTick,
            noticeText: isNoticeActive ? Self.riderNotice : nil
        )
    }
}

struct RouteDeviationSnapshot: Equatable {
    var distanceMeters: Double
    var isOffCorridor: Bool
    var isNoticeActive: Bool
    var didActivateNotice: Bool
    var noticeText: String?
}
