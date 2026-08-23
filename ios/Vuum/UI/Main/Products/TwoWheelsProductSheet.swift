import SwiftUI

struct TwoWheelsProductSheet: View {
    @EnvironmentObject private var tripSession: TripSession
    @Environment(\.dismiss) private var dismiss

    @State private var pickup: Place = MockPlaces.lubumbashiCenter
    @State private var dropoff: Place = MockPlaces.destinations[0]
    @State private var needsHelmet = true

    private var meters: Double {
        TripGeo.distanceMeters(from: pickup.coordinate, to: dropoff.coordinate)
    }

    private var estimate: RideTier {
        ProductCatalogTiers.twoWheels(distanceMeters: meters)
    }

    var body: some View {
        NavigationStack {
            ProductBookingForm(
                title: L10n.Services.twoWheels,
                subtitle: L10n.Products.twoWheelsSubtitle,
                symbol: "bicycle",
                confirmTitle: L10n.Products.continueToBook,
                pickup: $pickup,
                dropoff: $dropoff,
                estimate: estimate
            ) {
                Section {
                    Text(L10n.Products.twoWheelsNote)
                        .font(VuumType.caption)
                        .foregroundStyle(VuumColor.secondaryText)
                }
            } onConfirm: {
                tripSession.startLocalProductBooking(
                    pickup: pickup,
                    dropoff: dropoff,
                    packageNotes: needsHelmet ? "Helmet requested" : "",
                    injectTier: estimate
                )
                MainTabNavigation.openHome()
                dismiss()
            }
            .navigationTitle(L10n.Services.twoWheels)
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
