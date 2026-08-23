import XCTest
@testable import Vuum

@MainActor
final class InTripDestinationChangeTests: XCTestCase {
    private var session: TripSession!
    private let pinKey = "vuum.safety.requirePIN"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.set(false, forKey: pinKey)
        session = TripSession()
        session.testingAcceleratedLifecycle = true
        session.testingPreferImmediateDriverMatch()
    }

    override func tearDown() {
        session?.resetToHome()
        session = nil
        UserDefaults.standard.removeObject(forKey: pinKey)
        super.tearDown()
    }

    private var initialDestination: Place {
        Place(
            id: "dest-change-a",
            name: "Destination A",
            subtitle: "Unit test",
            coordinate: GeoPoint(latitude: -11.690, longitude: 27.505)
        )
    }

    private var alternateDestination: Place {
        Place(
            id: "dest-change-b",
            name: "Destination B",
            subtitle: "Unit test alternate",
            // Farther so fare distance / total should move.
            coordinate: GeoPoint(latitude: -11.720, longitude: 27.540)
        )
    }

    func testInTripDestinationChangeRefreshesRoutePolylineAndFare() async {
        session.beginDestinationSelection()
        session.selectDestination(initialDestination)
        session.confirmRequest()

        let arrived = await waitForPhase(among: [.driverArrived], timeout: 10)
        XCTAssertTrue(arrived, "Expected driverArrived; phase=\(session.phase)")
        session.confirmBoarding()
        XCTAssertEqual(session.phase, .inTrip)

        guard let before = session.activeTrip else {
            XCTFail("Missing active trip")
            return
        }
        let previousFare = before.fare.totalCDF
        let previousRouteEnd = before.tripRoute.last

        XCTAssertTrue(session.canChangeInTripDestination)
        session.updateInTripDestination(alternateDestination)

        XCTAssertEqual(session.activeTrip?.dropoff.id, alternateDestination.id)
        XCTAssertEqual(session.dropoff?.id, alternateDestination.id)
        XCTAssertNotNil(session.destinationChangeNotice)

        // Live RouteEngine apply must survive beginMotion’s lifecycleGeneration bump.
        let settled = await waitUntil(
            timeout: 4,
            predicate: { !session.isRecalculatingTripRoute }
        )
        XCTAssertTrue(settled, "Expected route recalc to finish")
        XCTAssertFalse(session.isRecalculatingTripRoute)

        guard let after = session.activeTrip else {
            XCTFail("Missing trip after destination change")
            return
        }
        XCTAssertEqual(after.dropoff.id, alternateDestination.id)
        XCTAssertGreaterThanOrEqual(after.tripRoute.count, 2)

        let routeEnd = after.tripRoute.last!
        let endDistance = TripGeo.distanceMeters(from: routeEnd, to: alternateDestination.coordinate)
        XCTAssertLessThan(endDistance, 80, "tripRoute should end at the new dropoff")

        if let previousRouteEnd {
            let moved = TripGeo.distanceMeters(from: previousRouteEnd, to: routeEnd)
            XCTAssertGreaterThan(moved, 200, "polyline end should move with destination")
        }

        XCTAssertNotEqual(after.fare.totalCDF, previousFare, "fare should recalculate for new path length")
        XCTAssertTrue(session.mapRoute.count >= 2, "map should keep a drawable remaining polyline")
    }

    func testRejectsDestinationMatchingPickupOrCurrentDropoff() async {
        session.beginDestinationSelection()
        session.selectDestination(initialDestination)
        session.confirmRequest()
        let arrived = await waitForPhase(among: [.driverArrived], timeout: 10)
        XCTAssertTrue(arrived)
        session.confirmBoarding()

        guard let trip = session.activeTrip else {
            XCTFail("Missing trip")
            return
        }
        let fareBefore = trip.fare.totalCDF
        session.updateInTripDestination(trip.dropoff)
        XCTAssertEqual(session.activeTrip?.fare.totalCDF, fareBefore)
        XCTAssertNil(session.destinationChangeNotice)

        session.updateInTripDestination(trip.pickup)
        XCTAssertEqual(session.activeTrip?.dropoff.id, trip.dropoff.id)
    }

    private func waitForPhase(among targets: [TripPhase], timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if targets.contains(session.phase) { return true }
            try? await Task.sleep(nanoseconds: 40_000_000)
        }
        return targets.contains(session.phase)
    }

    private func waitUntil(timeout: TimeInterval, predicate: () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if predicate() { return true }
            try? await Task.sleep(nanoseconds: 40_000_000)
        }
        return predicate()
    }
}
