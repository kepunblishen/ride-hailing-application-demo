import Combine
import Foundation

/// In-memory trip state machine for the rider demo (no backend).
@MainActor
final class TripSession: ObservableObject {
    @Published private(set) var phase: TripPhase = .idle
    @Published var pickup: Place = MockPlaces.defaultPickup
    @Published var dropoff: Place?
    @Published var selectedTier: RideTier?
    @Published var activeTrip: ActiveTrip?
    @Published var availableTiers: [RideTier] = []

    private var searchTask: Task<Void, Never>?

    func beginDestinationSelection() {
        phase = .selectingDestination
    }

    func selectDestination(_ place: Place) {
        dropoff = place
        availableTiers = MockFares.tiers(from: pickup, to: place)
        selectedTier = availableTiers.first
        phase = .choosingRide
    }

    func chooseTier(_ tier: RideTier) {
        selectedTier = tier
    }

    func confirmRequest() {
        guard let dropoff, let selectedTier else { return }
        phase = .searching
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2.2))
            guard !Task.isCancelled else { return }
            await self?.assignDriver(dropoff: dropoff, tier: selectedTier)
        }
    }

    func startTrip() {
        guard phase == .assigned else { return }
        phase = .inTrip
    }

    func completeTrip() {
        guard phase == .inTrip || phase == .assigned else { return }
        phase = .completed
    }

    func resetToHome() {
        searchTask?.cancel()
        searchTask = nil
        dropoff = nil
        selectedTier = nil
        activeTrip = nil
        availableTiers = []
        phase = .idle
    }

    private func assignDriver(dropoff: Place, tier: RideTier) {
        let driver = MockDrivers.random()
        activeTrip = ActiveTrip(
            pickup: pickup,
            dropoff: dropoff,
            tier: tier,
            driver: driver,
            fare: tier.priceEstimate,
            driverCoordinate: MockPlaces.nearbyDriverSeed(from: pickup)
        )
        phase = .assigned
    }
}
