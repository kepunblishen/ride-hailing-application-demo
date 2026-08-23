import XCTest
@testable import Vuum

final class RouteDeviationTests: XCTestCase {
    private let route: [GeoPoint] = [
        GeoPoint(latitude: -11.6600, longitude: 27.4800),
        GeoPoint(latitude: -11.6650, longitude: 27.4850),
        GeoPoint(latitude: -11.6700, longitude: 27.4900),
    ]

    func testDistanceToPolylineNearSegmentIsSmall() {
        let onPath = GeoPoint(latitude: -11.6625, longitude: 27.4825)
        let d = TripGeo.distanceToPolylineMeters(onPath, path: route)
        XCTAssertLessThan(d, 40)
    }

    func testDistanceToPolylineFarPointExceedsCorridor() {
        let far = TripGeo.offset(route[1], northMeters: 0, eastMeters: 250)
        let d = TripGeo.distanceToPolylineMeters(far, path: route)
        XCTAssertGreaterThan(d, RouteDeviationMonitor.defaultCorridorMeters)
        XCTAssertTrue(TripGeo.isOffRoute(far, expectedRoute: route))
    }

    func testMonitorRequiresPersistenceBeforeNotice() {
        var monitor = RouteDeviationMonitor(
            corridorMeters: 90,
            persistSeconds: 6,
            recoverSeconds: 3,
            recoverMeters: 55
        )
        let far = TripGeo.offset(route[1], northMeters: 0, eastMeters: 200)
        let t0 = Date(timeIntervalSince1970: 1_700_000_000)

        let early = monitor.evaluate(position: far, expectedRoute: route, now: t0)
        XCTAssertTrue(early.isOffCorridor)
        XCTAssertFalse(early.isNoticeActive)
        XCTAssertNil(early.noticeText)

        let mid = monitor.evaluate(
            position: far,
            expectedRoute: route,
            now: t0.addingTimeInterval(3)
        )
        XCTAssertFalse(mid.isNoticeActive)

        let late = monitor.evaluate(
            position: far,
            expectedRoute: route,
            now: t0.addingTimeInterval(6.1)
        )
        XCTAssertTrue(late.isNoticeActive)
        XCTAssertTrue(late.didActivateNotice)
        XCTAssertEqual(late.noticeText, RouteDeviationMonitor.riderNotice)
        XCTAssertFalse(late.noticeText?.localizedCaseInsensitiveContains("demo") ?? true)
    }

    func testMonitorClearsAfterRecovery() {
        var monitor = RouteDeviationMonitor(
            corridorMeters: 90,
            persistSeconds: 2,
            recoverSeconds: 2,
            recoverMeters: 55
        )
        let far = TripGeo.offset(route[1], northMeters: 0, eastMeters: 200)
        let on = route[1]
        let t0 = Date(timeIntervalSince1970: 1_700_000_100)

        _ = monitor.evaluate(position: far, expectedRoute: route, now: t0)
        let active = monitor.evaluate(
            position: far,
            expectedRoute: route,
            now: t0.addingTimeInterval(2.1)
        )
        XCTAssertTrue(active.isNoticeActive)

        _ = monitor.evaluate(position: on, expectedRoute: route, now: t0.addingTimeInterval(2.2))
        let cleared = monitor.evaluate(
            position: on,
            expectedRoute: route,
            now: t0.addingTimeInterval(4.5)
        )
        XCTAssertFalse(cleared.isNoticeActive)
        XCTAssertNil(cleared.noticeText)
    }

    func testClosestPointOnSegmentClampsEndpoints() {
        let a = GeoPoint(latitude: 0, longitude: 0)
        let b = GeoPoint(latitude: 0, longitude: 0.01)
        let before = GeoPoint(latitude: 0, longitude: -0.01)
        let after = GeoPoint(latitude: 0, longitude: 0.02)
        let nearA = TripGeo.closestPointOnSegment(before, a: a, b: b)
        let nearB = TripGeo.closestPointOnSegment(after, a: a, b: b)
        XCTAssertEqual(nearA.latitude, a.latitude, accuracy: 1e-9)
        XCTAssertEqual(nearA.longitude, a.longitude, accuracy: 1e-9)
        XCTAssertEqual(nearB.latitude, b.latitude, accuracy: 1e-9)
        XCTAssertEqual(nearB.longitude, b.longitude, accuracy: 1e-9)
    }

    /// Live Routes/Directions polylines are dense; corridor math + notice must still work.
    func testDenseLiveLikePolylineCorridorAndNotice() {
        let origin = GeoPoint(latitude: -11.6644, longitude: 27.4794)
        let destination = GeoPoint(latitude: -11.5913, longitude: 27.5308)
        let liveLike = TripGeo.routePolyline(from: origin, to: destination, samples: 96)
        XCTAssertGreaterThan(liveLike.count, 40)

        let onPath = TripGeo.pointAlong(path: liveLike, fraction: 0.4).point
        XCTAssertLessThan(
            TripGeo.distanceToPolylineMeters(onPath, path: liveLike),
            RouteDeviationMonitor.defaultCorridorMeters
        )

        let leg = TripGeo.pathBetween(along: liveLike, from: origin, to: destination)
        XCTAssertGreaterThanOrEqual(leg.count, 2)
        let midLeg = TripGeo.pointAlong(path: leg, fraction: 0.5).point
        XCTAssertLessThan(
            TripGeo.distanceToPolylineMeters(midLeg, path: liveLike),
            25
        )

        var monitor = RouteDeviationMonitor(
            corridorMeters: 90,
            persistSeconds: 6,
            recoverSeconds: 3,
            recoverMeters: 55
        )
        let far = TripGeo.offset(onPath, northMeters: 0, eastMeters: 180)
        let t0 = Date(timeIntervalSince1970: 1_700_000_200)
        _ = monitor.evaluate(position: far, expectedRoute: liveLike, now: t0)
        let late = monitor.evaluate(
            position: far,
            expectedRoute: liveLike,
            now: t0.addingTimeInterval(6.1)
        )
        XCTAssertTrue(late.isNoticeActive)
        XCTAssertEqual(late.noticeText, RouteDeviationMonitor.riderNotice)
    }
}
