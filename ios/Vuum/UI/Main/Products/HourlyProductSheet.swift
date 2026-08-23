import SwiftUI

struct HourlyProductSheet: View {
    @EnvironmentObject private var tripSession: TripSession
    @Environment(\.dismiss) private var dismiss

    @State private var pickup: Place = MockPlaces.lubumbashiCenter
    @State private var dropoff: Place = MockPlaces.destinations[0]
    @State private var hours = 2

    private let hourOptions = [1, 2, 3, 4, 5, 6, 8]

    private var meters: Double {
        TripGeo.distanceMeters(from: pickup.coordinate, to: dropoff.coordinate)
    }

    private var estimate: RideTier {
        ProductCatalogTiers.hourly(distanceMeters: meters, hours: hours)
    }

    var body: some View {
        NavigationStack {
            ProductBookingForm(
                title: L10n.Services.hourly,
                subtitle: L10n.Products.hourlySubtitle,
                symbol: "clock.fill",
                confirmTitle: L10n.Products.continueToBook,
                pickup: $pickup,
                dropoff: $dropoff,
                estimate: estimate
            ) {
                Section(L10n.Products.duration) {
                    Picker(L10n.Products.hours, selection: $hours) {
                        ForEach(hourOptions, id: \.self) { value in
                            Text(value == 1 ? L10n.Products.hourSingular : L10n.format("products.hours_plural", value)).tag(value)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(maxHeight: 120)

                    Text(L10n.format("products.hourly_fare_note", hours))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } onConfirm: {
                tripSession.startLocalProductBooking(
                    pickup: pickup,
                    dropoff: dropoff,
                    hourlyHours: hours,
                    injectTier: estimate
                )
                MainTabNavigation.openHome()
                dismiss()
            }
            .navigationTitle(L10n.Services.hourly)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.Common.close) { dismiss() }
                }
            }
            .onAppear { seedPlaces() }
        }
        .presentationDetents([.medium, .large])
    }

    private func seedPlaces() {
        let market: AppLocale.Market = AppLocale.current == .kenya ? .kenya : .drc
        pickup = tripSession.pickup
        dropoff = MockPlaces.destinations(for: market).first ?? dropoff
    }
}
