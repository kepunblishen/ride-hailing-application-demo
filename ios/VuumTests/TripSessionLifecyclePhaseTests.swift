import XCTest
@testable import Vuum

@MainActor
final class TripSessionLifecyclePhaseTests: XCTestCase {
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

    private var sampleDestination: Place {
        Place(
            id: "lifecycle-dropoff",
            name: "Lifecycle Destination",
            subtitle: "Unit test",
            coordinate: GeoPoint(latitude: -11.690, longitude: 27.505)
        )
    }

    func testAcceleratedSearchMatchEnRouteArrivedInTrip() async {
        session.beginDestinationSelection()
        session.selectDestination(sampleDestination)
        XCTAssertEqual(session.phase, .choosingRide)
        XCTAssertTrue(session.canConfirmRequest)

        session.confirmRequest()
        XCTAssertEqual(session.phase, .searching)

        let matched = await waitForPhase(
            among: [.matched, .driverEnRoute, .driverArrived],
            timeout: 8
        )
        XCTAssertTrue(matched, "Expected match within timeout; phase=\(session.phase)")

        let arrived = await waitForPhase(among: [.driverArrived], timeout: 8)
        XCTAssertTrue(arrived, "Expected driverArrived; phase=\(session.phase)")
        XCTAssertNotNil(session.activeTrip)
        XCTAssertFalse(session.activeTrip?.tripPIN.isEmpty ?? true)

        session.confirmBoarding()
        XCTAssertEqual(session.phase, .inTrip)
        XCTAssertNotNil(session.activeTrip)
    }

    func testBoardingPINRejectionThenSuccess() async {
        UserDefaults.standard.set(true, forKey: pinKey)

        session.beginDestinationSelection()
        session.selectDestination(sampleDestination)
        session.confirmRequest()

        let arrived = await waitForPhase(among: [.driverArrived], timeout: 10)
        XCTAssertTrue(arrived, "Expected driverArrived; phase=\(session.phase)")
        guard let pin = session.activeTrip?.tripPIN else {
            XCTFail("Missing trip PIN")
            return
        }

        session.boardingPINEntry = "0000"
        session.confirmBoarding()
        XCTAssertEqual(session.phase, .driverArrived)
        XCTAssertTrue(session.boardingPINRejected)

        session.boardingPINEntry = pin
        session.confirmBoarding()
        XCTAssertEqual(session.phase, .inTrip)
        XCTAssertFalse(session.boardingPINRejected)
    }

    func testCancelDuringSearchClearsActiveTrip() async {
        session.beginDestinationSelection()
        session.selectDestination(sampleDestination)
        session.confirmRequest()
        XCTAssertEqual(session.phase, .searching)

        // Allow the accelerated tick to start, then cancel.
        try? await Task.sleep(nanoseconds: 20_000_000)
        session.cancelActiveTrip()
        XCTAssertEqual(session.phase, .idle)
        XCTAssertNil(session.activeTrip)
        XCTAssertNil(session.searchStartedAt)
        XCTAssertFalse(session.testingHasOutstandingGoogleRouteWork)
    }

    func testCancelSearchAbortsInFlightGoogleRouteWork() async {
        session.beginDestinationSelection()
        session.selectDestination(sampleDestination)
        session.confirmRequest()
        XCTAssertEqual(session.phase, .searching)

        try? await Task.sleep(nanoseconds: 30_000_000)
        session.cancelSearch()
        XCTAssertEqual(session.phase, .choosingRide)
        XCTAssertNil(session.activeTrip)
        XCTAssertFalse(session.testingHasOutstandingGoogleRouteWork)
    }

    func testResumeDoesNotClearTripOrRetriggerPreview() async {
        session.beginDestinationSelection()
        session.selectDestination(sampleDestination)
        XCTAssertEqual(session.phase, .choosingRide)
        XCTAssertFalse(session.previewRoute.isEmpty)

        let routeBefore = session.previewRoute
        session.handleAppDidEnterBackground()
        session.handleAppWillEnterForeground()

        XCTAssertEqual(session.phase, .choosingRide)
        XCTAssertEqual(session.previewRoute, routeBefore)
        XCTAssertEqual(session.dropoff?.id, sampleDestination.id)
    }

    /// Polls on the main actor until `phase` is in `targets` or timeout elapses.
    private func waitForPhase(among targets: [TripPhase], timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if targets.contains(session.phase) {
                return true
            }
            try? await Task.sleep(nanoseconds: 40_000_000)
        }
        return targets.contains(session.phase)
    }
}
