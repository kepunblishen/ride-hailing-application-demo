import XCTest
@testable import Vuum

final class VehiclePickupETATests: XCTestCase {
    func testPickupETAByVehicleClass() {
        XCTAssertEqual(VehiclePickupETA.minutes(for: .bike), 2)
        XCTAssertEqual(VehiclePickupETA.minutes(for: .standard), 5)
        XCTAssertEqual(VehiclePickupETA.minutes(for: .large), 10)
    }

    func testPickupETAConstantsMatchProductDefaults() {
        XCTAssertEqual(VehiclePickupETA.bikeMinutes, 2)
        XCTAssertEqual(VehiclePickupETA.standardCarMinutes, 5)
        XCTAssertEqual(VehiclePickupETA.largeXXLMinutes, 10)
    }

    func testTripMotionTimingMirrorsVehicleClassETA() {
        XCTAssertEqual(TripMotionTiming.pickupETAMinutes(for: .bike), 2)
        XCTAssertEqual(TripMotionTiming.pickupETAMinutes(for: .standard), 5)
        XCTAssertEqual(TripMotionTiming.pickupETAMinutes(for: .large), 10)
        XCTAssertEqual(TripMotionTiming.pickupETAMinutes(forTierID: "two-wheels"), 2)
        XCTAssertEqual(TripMotionTiming.pickupETAMinutes(forTierID: "vuum"), 5)
        XCTAssertEqual(TripMotionTiming.pickupETAMinutes(forTierID: "xxl"), 10)
        XCTAssertEqual(TripMotionTiming.pickupETAMinutes(forTierID: "executive"), 10)
    }

    func testVehicleClassResolvingFromTierIDs() {
        XCTAssertEqual(VehicleClass.resolving(tierID: "bike"), .bike)
        XCTAssertEqual(VehicleClass.resolving(tierID: "two-wheels"), .bike)
        XCTAssertEqual(VehicleClass.resolving(tierID: "comfort"), .standard)
        XCTAssertEqual(VehicleClass.resolving(tierID: "xxl"), .large)
        XCTAssertEqual(VehicleClass.resolving(tierID: "airport"), .large)
    }

    func testVehicleClassSystemImagesForMapMarkers() {
        XCTAssertEqual(VehicleClass.bike.systemImage, "bicycle")
        XCTAssertEqual(VehicleClass.standard.systemImage, "car.fill")
        XCTAssertEqual(VehicleClass.large.systemImage, "car.2.fill")
    }

    func testDisplayedETACountsDownWithProgress() {
        XCTAssertEqual(TripMotionTiming.displayedETAMinutes(baseline: 5, fraction: 0), 5)
        XCTAssertEqual(TripMotionTiming.displayedETAMinutes(baseline: 5, fraction: 0.5), 3)
        XCTAssertEqual(TripMotionTiming.displayedETAMinutes(baseline: 5, fraction: 1), 0)
    }

    func testApproachSimulationSecondsScalesWithClassETA() {
        let bike = TripMotionTiming.approachSimulationSeconds(for: .bike)
        let car = TripMotionTiming.approachSimulationSeconds(for: .standard)
        let xxl = TripMotionTiming.approachSimulationSeconds(for: .large)
        XCTAssertLessThan(bike, car)
        XCTAssertLessThan(car, xxl)
        // bike~2 / car~5 / XXL~10 minutes → compressed wall clocks stay distinct.
        XCTAssertEqual(bike, TripMotionTiming.simulationDurationSeconds(displayedETAMinutes: 2), accuracy: 0.01)
        XCTAssertEqual(car, TripMotionTiming.simulationDurationSeconds(displayedETAMinutes: 5), accuracy: 0.01)
        XCTAssertEqual(xxl, TripMotionTiming.simulationDurationSeconds(displayedETAMinutes: 10), accuracy: 0.01)
        XCTAssertEqual(VehiclePickupETA.approachSimulationSeconds(for: .standard), car, accuracy: 0.01)
    }

    func testHeadingLerpUsesShortestArc() {
        let mid = TripGeo.lerpHeading(from: 350, to: 10, fraction: 0.5)
        XCTAssertEqual(mid, 0, accuracy: 0.01)
        let smoothed = TripGeo.smoothHeading(current: 10, target: 100, maxStepDegrees: 20)
        XCTAssertEqual(smoothed, 30, accuracy: 0.01)
    }
}
