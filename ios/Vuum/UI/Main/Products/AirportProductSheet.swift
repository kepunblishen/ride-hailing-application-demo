import SwiftUI

struct AirportProductSheet: View {
    @EnvironmentObject private var tripSession: TripSession
    @Environment(\.dismiss) private var dismiss

    @State private var pickup: Place = MockPlaces.lubumbashiCenter
    @State private var dropoff: Place = MockPlaces.destinations[0]
    @State private var flightNumber = ""
    @State private var luggageCount = 2
    @State private var meetAndGreet = true
    @State private var flightStatus: FlightStatusSnapshot?

    private enum FlightStatusSnapshot: Equatable {
        case onTime(arrival: String)
        case delayed(minutes: Int, arrival: String)
        case landed(gate: String)
        case notFound

        var title: String {
            switch self {
            case .onTime(let arrival): return "On time · arrives \(arrival)"
            case .delayed(let minutes, let arrival): return "Delayed \(minutes) min · arrives \(arrival)"
            case .landed(let gate): return "Landed · gate \(gate)"
            case .notFound: return "Flight not found — we’ll still meet you"
            }
        }
    }

    private var meters: Double {
        TripGeo.distanceMeters(from: pickup.coordinate, to: dropoff.coordinate)
    }

    private var estimate: RideTier {
        ProductCatalogTiers.airport(distanceMeters: meters)
    }

    private var composedNotes: String {
        var parts: [String] = ["Luggage: \(luggageCount)"]
        if meetAndGreet { parts.append("Meet & greet") }
        let flight = flightNumber.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if !flight.isEmpty {
            parts.append("Flight \(flight)")
            if let flightStatus {
                parts.append(flightStatus.title)
            }
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        NavigationStack {
            ProductBookingForm(
                title: "Airport",
                subtitle: "Travel-ready rides to and from the terminal with luggage space.",
                symbol: "airplane",
                confirmTitle: "Continue to book",
                pickup: $pickup,
                dropoff: $dropoff,
                estimate: estimate
            ) {
                Section("Travel details") {
                    TextField("Flight number (optional)", text: $flightNumber)
                        .textInputAutocapitalization(.characters)
                        .onChange(of: flightNumber) { _, value in
                            refreshFlightStatus(value)
                        }

                    if let flightStatus {
                        Label(flightStatus.title, systemImage: "airplane.circle.fill")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(VuumColor.brandInk)
                    }

                    Stepper(value: $luggageCount, in: 0...6) {
                        Text(luggageCount == 1 ? "1 bag" : "\(luggageCount) bags")
                    }

                    Toggle("Meet at arrivals", isOn: $meetAndGreet)

                    Text("Larger vehicles · about \(VehiclePickupETA.largeXXLMinutes) min to pickup.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
            .navigationTitle("Airport")
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

    private func refreshFlightStatus(_ raw: String) {
        let flight = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard flight.count >= 3 else {
            flightStatus = nil
            return
        }
        // Local flight board — swaps to a live feed when a tracking API is keyed.
        let hash = flight.unicodeScalars.reduce(0) { ($0 &+ Int($1.value)) % 4 }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let arrival = formatter.string(from: Date().addingTimeInterval(Double(45 + hash * 12) * 60))
        switch hash {
        case 0: flightStatus = .onTime(arrival: arrival)
        case 1: flightStatus = .delayed(minutes: 25 + hash * 5, arrival: arrival)
        case 2: flightStatus = .landed(gate: "B\(hash + 2)")
        default: flightStatus = .notFound
        }
    }

    private func seedPlaces() {
        let market: AppLocale.Market = AppLocale.current == .kenya ? .kenya : .drc
        let destinations = MockPlaces.destinations(for: market)
        let airport = destinations.first { $0.id.contains("airport") || $0.name.localizedCaseInsensitiveContains("airport") }
        pickup = tripSession.pickup
        dropoff = airport ?? destinations.first ?? dropoff
    }
}
