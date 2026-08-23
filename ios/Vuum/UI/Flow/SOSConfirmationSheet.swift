import CoreLocation
import SwiftUI

/// Confirms SOS before notifying Vuum Safety with trip / GPS / trusted-contact context.
struct SOSConfirmationSheet: View {
    @ObservedObject var location: RiderLocationManager
    var contacts: [TrustedContact]
    var onConfirm: () -> Void

    @EnvironmentObject private var tripSession: TripSession
    @Environment(\.dismiss) private var dismiss

    private var coordinateSummary: String {
        guard let coord = location.latestLocation?.coordinate else {
            return "Current GPS unavailable — last known trip pin will be sent."
        }
        return String(format: "%.5f, %.5f", coord.latitude, coord.longitude)
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Vuum Safety will receive your trip details and try to reach you immediately.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let trip = tripSession.activeTrip {
                    Section("What we will send") {
                        LabeledContent("Trip ID", value: TripShare.tripID(for: trip))
                        LabeledContent("Driver", value: trip.driver.name)
                        LabeledContent("Vehicle", value: "\(trip.driver.vehicle) · \(trip.driver.plate)")
                        LabeledContent("Destination", value: trip.dropoff.name)
                        LabeledContent("Location", value: coordinateSummary)
                        LabeledContent("Status", value: TripShare.phaseLabel(for: tripSession.phase))
                    }
                } else {
                    Section("Location") {
                        LabeledContent("GPS", value: coordinateSummary)
                    }
                }

                if contacts.isEmpty {
                    Section("Emergency contacts") {
                        Text("No trusted contacts saved yet. You can still request help — add contacts under Safety for faster reach-out.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Section("Emergency contacts") {
                        ForEach(contacts) { contact in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(contact.name)
                                    .font(.body.weight(.semibold))
                                Text("\(contact.displayPhone) · \(contact.relationship)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                Section {
                    Button("Request help now", role: .destructive) {
                        onConfirm()
                        dismiss()
                    }
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .navigationTitle("Request emergency help?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
