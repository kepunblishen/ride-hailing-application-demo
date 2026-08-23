import SwiftUI

/// Corner-store / convenience delivery sheet — catalog lines into courier booking.
struct ConvenienceProductSheet: View {
    @EnvironmentObject private var tripSession: TripSession
    @Environment(\.dismiss) private var dismiss

    @State private var pickup: Place = MockPlaces.lubumbashiCenter
    @State private var dropoff: Place = MockPlaces.destinations[0]
    @State private var selectedItems: Set<String> = ["snacks"]
    @State private var notes = ""

    private let catalog: [(id: String, title: String)] = [
        ("snacks", "Snacks & drinks"),
        ("essentials", "Daily essentials"),
        ("phone", "Phone credit / airtime"),
        ("household", "Small household"),
    ]

    private var meters: Double {
        TripGeo.distanceMeters(from: pickup.coordinate, to: dropoff.coordinate)
    }

    private var estimate: RideTier {
        ProductCatalogTiers.convenience(distanceMeters: meters)
    }

    private var composedNotes: String {
        let items = catalog
            .filter { selectedItems.contains($0.id) }
            .map(\.title)
        var parts: [String] = []
        if !items.isEmpty {
            parts.append("Items: \(items.joined(separator: ", "))")
        }
        let extra = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !extra.isEmpty { parts.append(extra) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            ProductBookingForm(
                title: L10n.t("services.convenience"),
                subtitle: "Nearby shops deliver snacks and essentials to your door.",
                symbol: "bag.fill",
                confirmTitle: "Continue to book",
                pickup: $pickup,
                dropoff: $dropoff,
                estimate: estimate,
                canConfirm: !selectedItems.isEmpty
            ) {
                Section("Order") {
                    ForEach(catalog, id: \.id) { item in
                        Toggle(item.title, isOn: Binding(
                            get: { selectedItems.contains(item.id) },
                            set: { on in
                                if on { selectedItems.insert(item.id) }
                                else { selectedItems.remove(item.id) }
                            }
                        ))
                    }
                    TextField("Delivery notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            } onConfirm: {
                tripSession.startLocalProductBooking(
                    pickup: pickup,
                    dropoff: dropoff,
                    packageNotes: composedNotes,
                    injectTier: estimate
                )
                dismiss()
            }
            .navigationTitle(L10n.t("services.convenience"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
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
