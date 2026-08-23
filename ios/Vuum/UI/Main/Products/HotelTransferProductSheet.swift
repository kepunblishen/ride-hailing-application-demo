import SwiftUI

/// Hotel / hospitality transfer booking (RFQ F06) — guest name, room, and lobby pickup.
struct HotelTransferProductSheet: View {
    @EnvironmentObject private var tripSession: TripSession
    @Environment(\.dismiss) private var dismiss

    @State private var pickup: Place = MockPlaces.lubumbashiCenter
    @State private var dropoff: Place = MockPlaces.destinations[0]
    @State private var hotelName = "Hôtel Karavia"
    @State private var guestName = ""
    @State private var roomNumber = ""
    @State private var lobbyPickup = true

    private var meters: Double {
        TripGeo.distanceMeters(from: pickup.coordinate, to: dropoff.coordinate)
    }

    private var estimate: RideTier {
        ProductCatalogTiers.hotelTransfer(distanceMeters: meters)
    }

    private var composedNotes: String {
        var parts = ["Hotel: \(hotelName.trimmingCharacters(in: .whitespacesAndNewlines))"]
        let guest = guestName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !guest.isEmpty { parts.append("Guest: \(guest)") }
        let room = roomNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if !room.isEmpty { parts.append("Room \(room)") }
        if lobbyPickup { parts.append("Lobby pickup") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            ProductBookingForm(
                title: "Hotel transfer",
                subtitle: "Lobby or curb pickup coordinated with hospitality partners.",
                symbol: "building.2.fill",
                confirmTitle: "Continue to book",
                pickup: $pickup,
                dropoff: $dropoff,
                estimate: estimate,
                canConfirm: !guestName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ) {
                Section("Hospitality") {
                    TextField("Hotel name", text: $hotelName)
                        .textContentType(.organizationName)
                    TextField("Guest name", text: $guestName)
                        .textContentType(.name)
                    TextField("Room number (optional)", text: $roomNumber)
                        .keyboardType(.numbersAndPunctuation)
                    Toggle("Meet at lobby desk", isOn: $lobbyPickup)
                }
            } onConfirm: {
                tripSession.passengerName = guestName.trimmingCharacters(in: .whitespacesAndNewlines)
                tripSession.startLocalProductBooking(
                    pickup: pickup,
                    dropoff: dropoff,
                    packageNotes: composedNotes,
                    injectTier: estimate
                )
                dismiss()
            }
            .navigationTitle("Hotel transfer")
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
        let destinations = MockPlaces.destinations(for: market)
        let hotel = destinations.first {
            $0.name.localizedCaseInsensitiveContains("hôtel")
                || $0.name.localizedCaseInsensitiveContains("hotel")
                || $0.name.localizedCaseInsensitiveContains("karavia")
        }
        pickup = hotel ?? MockPlaces.defaultCenter(for: market)
        dropoff = destinations.first { $0.id != pickup.id } ?? destinations.first ?? dropoff
        if let hotel {
            hotelName = hotel.name
        }
    }
}
