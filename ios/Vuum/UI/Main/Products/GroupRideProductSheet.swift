import SwiftUI

struct GroupRideProductSheet: View {
    @EnvironmentObject private var tripSession: TripSession
    @Environment(\.dismiss) private var dismiss

    @State private var pickup: Place = MockPlaces.lubumbashiCenter
    @State private var dropoff: Place = MockPlaces.destinations[0]
    @State private var seats = 4

    private var meters: Double {
        TripGeo.distanceMeters(from: pickup.coordinate, to: dropoff.coordinate)
    }

    private var estimate: RideTier? {
        MockFares.tiers(for: meters).first(where: { $0.id == "xxl" })
    }

    var body: some View {
        NavigationStack {
            ProductBookingForm(
                title: L10n.Services.groupRide,
                subtitle: L10n.Products.groupSubtitle,
                symbol: "person.3.fill",
                confirmTitle: L10n.Products.continueToBook,
                pickup: $pickup,
                dropoff: $dropoff,
                estimate: estimate
            ) {
                Section(L10n.Products.passengers) {
                    Stepper(value: $seats, in: 3...6) {
                        Text(L10n.format("products.seats", seats))
                    }
                    Text(L10n.Products.groupNote)
                        .font(VuumType.caption)
                        .foregroundStyle(VuumColor.secondaryText)
                }
            } onConfirm: {
                tripSession.startLocalProductBooking(
                    pickup: pickup,
                    dropoff: dropoff,
                    preferredTierID: "xxl"
                )
                MainTabNavigation.openHome()
                dismiss()
            }
            .navigationTitle(L10n.Services.groupRide)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
            .onAppear { seedPlaces() }
        }
        .productSheetPresentation()
    }

    private func seedPlaces() {
        let market: AppLocale.Market = AppLocale.current == .kenya ? .kenya : .drc
        pickup = tripSession.pickup
        dropoff = MockPlaces.destinations(for: market).first ?? dropoff
    }
}
