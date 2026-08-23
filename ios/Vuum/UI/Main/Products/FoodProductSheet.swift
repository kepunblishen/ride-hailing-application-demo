import SwiftUI

/// Local food ordering / courier handoff sheet (RFQ F01) — restaurant stubs + cart lines.
struct FoodProductSheet: View {
    @EnvironmentObject private var tripSession: TripSession
    @Environment(\.dismiss) private var dismiss

    @State private var pickup: Place = MockPlaces.lubumbashiCenter
    @State private var dropoff: Place = MockPlaces.destinations[0]
    @State private var selectedRestaurantID = FoodCatalog.restaurants[0].id
    @State private var cart: [String: Int] = [:]
    @State private var notes = ""

    private var restaurant: FoodCatalog.Restaurant {
        FoodCatalog.restaurants.first { $0.id == selectedRestaurantID }
            ?? FoodCatalog.restaurants[0]
    }

    private var cartLineCount: Int {
        cart.values.reduce(0, +)
    }

    private var meters: Double {
        TripGeo.distanceMeters(from: pickup.coordinate, to: dropoff.coordinate)
    }

    private var estimate: RideTier {
        ProductCatalogTiers.food(distanceMeters: meters)
    }

    private var composedNotes: String {
        var parts: [String] = ["Restaurant: \(restaurant.name)"]
        let lines = restaurant.menu
            .compactMap { item -> String? in
                guard let qty = cart[item.id], qty > 0 else { return nil }
                return qty == 1 ? item.title : "\(item.title) ×\(qty)"
            }
        if !lines.isEmpty {
            parts.append("Order: \(lines.joined(separator: ", "))")
        }
        let extra = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !extra.isEmpty { parts.append(extra) }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            ProductBookingForm(
                title: "Food",
                subtitle: "Order from nearby kitchens; courier delivers to your door.",
                symbol: "fork.knife",
                confirmTitle: "Continue to book",
                pickup: $pickup,
                dropoff: $dropoff,
                estimate: estimate,
                canConfirm: cartLineCount > 0
            ) {
                Section("Restaurant") {
                    Picker("Kitchen", selection: $selectedRestaurantID) {
                        ForEach(FoodCatalog.restaurants) { place in
                            Text("\(place.name) · \(place.category)").tag(place.id)
                        }
                    }
                    .onChange(of: selectedRestaurantID) { _, _ in
                        cart = [:]
                    }

                    Text(restaurant.blurb)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Menu") {
                    ForEach(restaurant.menu) { item in
                        Stepper(value: Binding(
                            get: { cart[item.id, default: 0] },
                            set: { newValue in
                                if newValue <= 0 {
                                    cart.removeValue(forKey: item.id)
                                } else {
                                    cart[item.id] = min(9, newValue)
                                }
                            }
                        ), in: 0...9) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 15, weight: .semibold))
                                Text(item.category)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section("Delivery notes") {
                    TextField("Allergies, gate code, leave at door…", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            } onConfirm: {
                tripSession.startLocalProductBooking(
                    pickup: pickup,
                    dropoff: dropoff,
                    packageNotes: composedNotes,
                    injectTier: estimate
                )
                MainTabNavigation.openHome()
                dismiss()
            }
            .navigationTitle("Food")
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
        if cart.isEmpty, let first = FoodCatalog.restaurants.first?.menu.first {
            cart[first.id] = 1
        }
    }
}

// MARK: - Local catalog

enum FoodCatalog {
    struct Restaurant: Identifiable {
        let id: String
        let name: String
        let category: String
        let blurb: String
        let menu: [MenuItem]
    }

    struct MenuItem: Identifiable {
        let id: String
        let title: String
        let category: String
    }

    static let restaurants: [Restaurant] = [
        Restaurant(
            id: "karibu-grill",
            name: "Karibu Grill",
            category: "Grill",
            blurb: "Charcoal plates and sides · ~25–35 min prep.",
            menu: [
                MenuItem(id: "kg-brochettes", title: "Brochettes plate", category: "Mains"),
                MenuItem(id: "kg-fries", title: "Street fries", category: "Sides"),
                MenuItem(id: "kg-salad", title: "Garden salad", category: "Sides"),
                MenuItem(id: "kg-soda", title: "Cold soda", category: "Drinks"),
            ]
        ),
        Restaurant(
            id: "mama-sambu",
            name: "Mama Sambu Kitchen",
            category: "Home cooking",
            blurb: "Daily specials · poulet mayai, fufu, and greens.",
            menu: [
                MenuItem(id: "ms-poulet", title: "Poulet mayai", category: "Mains"),
                MenuItem(id: "ms-fufu", title: "Fufu bowl", category: "Staples"),
                MenuItem(id: "ms-ndizi", title: "Plantains", category: "Sides"),
                MenuItem(id: "ms-juice", title: "Fresh juice", category: "Drinks"),
            ]
        ),
        Restaurant(
            id: "lake-bites",
            name: "Lake Bites",
            category: "Seafood",
            blurb: "Grilled fish and light bowls · city lunch favourite.",
            menu: [
                MenuItem(id: "lb-tilapia", title: "Grilled tilapia", category: "Mains"),
                MenuItem(id: "lb-rice", title: "Coconut rice", category: "Staples"),
                MenuItem(id: "lb-soup", title: "Fish soup", category: "Starters"),
                MenuItem(id: "lb-tea", title: "Spiced tea", category: "Drinks"),
            ]
        ),
        Restaurant(
            id: "nairobi-wraps",
            name: "City Wraps",
            category: "Fast bites",
            blurb: "Wraps and bowls for quick office runs.",
            menu: [
                MenuItem(id: "cw-chicken", title: "Chicken wrap", category: "Mains"),
                MenuItem(id: "cw-veg", title: "Veggie wrap", category: "Mains"),
                MenuItem(id: "cw-chips", title: "Seasoned chips", category: "Sides"),
                MenuItem(id: "cw-smoothie", title: "Fruit smoothie", category: "Drinks"),
            ]
        ),
    ]
}
