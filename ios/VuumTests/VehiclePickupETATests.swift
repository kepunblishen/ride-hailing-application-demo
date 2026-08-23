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

    func testDisplayedETACountsDownWithProgress() {
        XCTAssertEqual(TripMotionTiming.displayedETAMinutes(baseline: 5, fraction: 0), 5)
        XCTAssertEqual(TripMotionTiming.displayedETAMinutes(baseline: 5, fraction: 0.5), 3)
        XCTAssertEqual(TripMotionTiming.displayedETAMinutes(baseline: 5, fraction: 1), 0)
    }
}
