import XCTest
@testable import Vuum

@MainActor
final class TripSessionPhaseTests: XCTestCase {
    private var session: TripSession!

    override func setUp() {
        super.setUp()
        session = TripSession()
    }

    override func tearDown() {
        session?.resetToHome()
        session = nil
        super.tearDown()
    }

    private var sampleDestination: Place {
        Place(
            id: "test-dropoff",
            name: "Test Destination",
            subtitle: "Unit test",
            coordinate: GeoPoint(latitude: -11.687, longitude: 27.502)
        )
    }

    func testIdleToSelectingToChoosingRide() {
        XCTAssertEqual(session.phase, .idle)

        session.beginDestinationSelection()
        XCTAssertEqual(session.phase, .selectingDestination)
        XCTAssertNil(session.dropoff)

        session.selectDestination(sampleDestination)
        XCTAssertEqual(session.phase, .choosingRide)
        XCTAssertEqual(session.dropoff?.id, "test-dropoff")
        XCTAssertNotNil(session.selectedTier)
    }

    func testConfirmRequestEntersSearchingAndCancelReturnsToChoosingRide() {
        session.beginDestinationSelection()
        session.selectDestination(sampleDestination)
        XCTAssertEqual(session.phase, .choosingRide)
        XCTAssertTrue(session.canConfirmRequest)

        session.confirmRequest()
        XCTAssertEqual(session.phase, .searching)
        XCTAssertNotNil(session.searchStartedAt)

        session.cancelSearch()
        XCTAssertEqual(session.phase, .choosingRide)
        XCTAssertNil(session.activeTrip)
        XCTAssertNil(session.searchStartedAt)
    }

    func testCancelActiveTripResetsToIdle() {
        session.beginDestinationSelection()
        session.selectDestination(sampleDestination)
        session.confirmRequest()
        XCTAssertEqual(session.phase, .searching)

        session.cancelActiveTrip()
        XCTAssertEqual(session.phase, .idle)
        XCTAssertNil(session.dropoff)
        XCTAssertNil(session.selectedTier)
        XCTAssertNil(session.activeTrip)
    }

    func testChangeDestinationClearsDropoffAndReturnsToSelecting() {
        session.beginDestinationSelection()
        session.selectDestination(sampleDestination)
        session.changeDestination()
        XCTAssertEqual(session.phase, .selectingDestination)
        XCTAssertNil(session.dropoff)
    }

    func testBookForSomeoneElseRequiresNameAndPhone() {
        session.beginDestinationSelection()
        session.selectDestination(sampleDestination)
        session.bookForSomeoneElse = true
        session.passengerName = ""
        session.passengerPhone = ""
        XCTAssertFalse(session.canConfirmRequest)

        session.passengerName = "Amina"
        session.passengerPhone = "970000111"
        XCTAssertTrue(session.canConfirmRequest)
    }

    func testAddStopCapsAtMaxAndReturnsToChoosingRide() {
        session.beginDestinationSelection()
        session.selectDestination(sampleDestination)
        session.beginAddingStop()
        XCTAssertEqual(session.phase, .selectingDestination)

        let stop = Place(
            id: "stop-1",
            name: "Stop One",
            subtitle: "Unit test",
            coordinate: GeoPoint(latitude: -11.68, longitude: 27.49)
        )
        session.addStop(stop)
        XCTAssertEqual(session.stops.count, 1)
        XCTAssertEqual(session.phase, .choosingRide)
        XCTAssertEqual(TripSession.maxStops, 2)
    }
}
