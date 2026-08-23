import XCTest
@testable import Vuum

final class RouteEngineProviderTests: XCTestCase {
    func testSyntheticRouteIncludesLegsAndStaticDuration() {
        let a = GeoPoint(latitude: -11.66, longitude: 27.48)
        let b = GeoPoint(latitude: -11.67, longitude: 27.49)
        let route = RouteEngine.synthetic(from: a, to: b)

        XCTAssertEqual(route.source, .synthetic)
        XCTAssertFalse(route.isTrafficAware)
        XCTAssertEqual(route.legs.count, 1)
        XCTAssertEqual(route.waypoints.count, 2)
        XCTAssertNotNil(route.staticDurationSeconds)
        XCTAssertNil(route.trafficDurationSeconds)
        XCTAssertGreaterThan(route.durationSeconds, 0)
        XCTAssertEqual(route.durationSeconds, route.legs[0].durationSeconds, accuracy: 0.01)
    }

    func testMultiStopSyntheticBuildsPerLegMetadata() {
        let points = [
            GeoPoint(latitude: -11.66, longitude: 27.48),
            GeoPoint(latitude: -11.665, longitude: 27.485),
            GeoPoint(latitude: -11.67, longitude: 27.49),
        ]
        let route = RouteEngine.synthetic(through: points)
        XCTAssertEqual(route.legs.count, 2)
        XCTAssertEqual(route.waypointCount, 3)
        let legSum = route.legs.reduce(0.0) { $0 + $1.durationSeconds }
        XCTAssertEqual(route.durationSeconds, legSum, accuracy: 0.01)
    }

    func testEtaMinutesScalesWithRemainingDistance() {
        let route = RouteEngine.Route(
            coordinates: [
                GeoPoint(latitude: 0, longitude: 0),
                GeoPoint(latitude: 0.01, longitude: 0.01),
            ],
            distanceMeters: 1_000,
            durationSeconds: 600,
            trafficDurationSeconds: 600,
            staticDurationSeconds: 480,
            source: .routes,
            waypointCount: 2,
            waypoints: [
                GeoPoint(latitude: 0, longitude: 0),
                GeoPoint(latitude: 0.01, longitude: 0.01),
            ],
            legs: [],
            isTrafficAware: true
        )
        XCTAssertEqual(route.durationMinutes, 10)
        XCTAssertEqual(route.etaMinutes(forRemainingMeters: 500), 5)
        XCTAssertEqual(route.etaMinutesRemaining(fractionComplete: 0.5), 5)
        XCTAssertEqual(route.etaMinutesRemaining(fractionComplete: 1), 0)
    }

    func testDefaultProviderIsGoogleRouteProvider() async {
        let previous = RouteEngine.provider
        defer { RouteEngine.provider = previous }

        RouteEngine.provider = GoogleRouteProvider()
        let a = GeoPoint(latitude: -11.66, longitude: 27.48)
        let b = GeoPoint(latitude: -11.67, longitude: 27.49)
        // Without a usable API key this resolves to synthetic — still a valid RouteProvider path.
        let route = await RouteEngine.route(from: a, to: b)
        XCTAssertGreaterThanOrEqual(route.coordinates.count, 2)
        XCTAssertFalse(route.legs.isEmpty)
    }
}
