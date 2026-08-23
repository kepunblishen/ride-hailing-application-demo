import SwiftUI

/// Local grocery / marketplace order sheet (RFQ F02) — rider booking shell with catalog lines.
struct GroceryProductSheet: View {
    @EnvironmentObject private var tripSession: TripSession
    @Environment(\.dismiss) private var dismiss

    @State private var pickup: Place = MockPlaces.lubumbashiCenter
    @State private var dropoff: Place = MockPlaces.destinations[0]
    @State private var selectedItems: Set<String> = ["produce"]
    @State private var notes = ""

    private let catalog: [(id: String, title: String)] = [
        ("produce", "Fresh produce"),
        ("staples", "Staples & grains"),
        ("dairy", "Dairy & eggs"),
        ("household", "Household"),
    ]

    private var meters: Double {
        TripGeo.distanceMeters(from: pickup.coordinate, to: dropoff.coordinate)
    }

    private var estimate: RideTier {
        ProductCatalogTiers.grocery(distanceMeters: meters)
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
                title: "Grocery",
                subtitle: "Local market pickup delivered to your door.",
                symbol: "cart.fill",
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
            .navigationTitle("Grocery")
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
        pickup = MockPlaces.defaultCenter(for: market)
        dropoff = MockPlaces.destinations(for: market).first ?? dropoff
    }
}
