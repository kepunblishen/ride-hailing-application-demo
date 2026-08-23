import SwiftUI

/// Top-level navigator for the rider demo flow.
/// Screens are filled in next; this only routes by `TripPhase`.
struct RootFlowView: View {
    @EnvironmentObject private var tripSession: TripSession

    var body: some View {
        Group {
            switch tripSession.phase {
            case .idle:
                HomeMapScaffoldView()
            case .selectingDestination:
                DestinationScaffoldView()
            case .choosingRide:
                RideOptionsScaffoldView()
            case .searching:
                SearchingScaffoldView()
            case .assigned, .inTrip:
                ActiveTripScaffoldView()
            case .completed:
                TripCompleteScaffoldView()
            }
        }
        .animation(.easeInOut(duration: 0.25), value: tripSession.phase)
    }
}
