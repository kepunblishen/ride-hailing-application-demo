import SwiftUI

/// Top-level navigator for the signed-in Home tab.
/// Routes exclusively by `TripSession.phase` (single source of truth).
struct RootFlowView: View {
    @EnvironmentObject private var tripSession: TripSession

    var body: some View {
        ZStack {
            switch tripSession.phase {
            case .idle:
                HomeHubView()
                    .transition(phaseTransition)
            case .selectingDestination:
                DestinationScaffoldView()
                    .transition(phaseTransition)
            case .choosingRide:
                RideOptionsScaffoldView()
                    .transition(phaseTransition)
            case .searching:
                SearchingScaffoldView()
                    .transition(phaseTransition)
            case .matched, .driverEnRoute, .driverArrived, .inTrip:
                ActiveTripScaffoldView()
                    .transition(phaseTransition)
            case .completed:
                TripCompleteScaffoldView()
                    .transition(phaseTransition)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: tripSession.phase)
    }

    private var phaseTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .trailing)).combined(with: .offset(y: 8)),
            removal: .opacity.combined(with: .move(edge: .leading))
        )
    }
}
