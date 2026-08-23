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
                        .foregroundStyle(VuumColor.secondaryText)
                }

                if let trip = tripSession.activeTrip {
                    Section {
                        LabeledContent("Trip ID", value: TripShare.tripID(for: trip))
                        LabeledContent("Driver", value: trip.driver.name)
                        LabeledContent("Vehicle", value: "\(trip.driver.vehicle) · \(trip.driver.plate)")
                        LabeledContent("Destination", value: trip.dropoff.name)
                        LabeledContent("Location", value: coordinateSummary)
                        LabeledContent("Status", value: TripShare.phaseLabel(for: tripSession.phase))
                    } header: {
                        Text("What we will send")
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                } else {
                    Section {
                        LabeledContent("GPS", value: coordinateSummary)
                    } header: {
                        Text("Location")
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                }

                if contacts.isEmpty {
                    Section {
                        Text("No trusted contacts saved yet. You can still request help — add contacts under Safety for faster reach-out.")
                            .font(.footnote)
                            .foregroundStyle(VuumColor.secondaryText)
                    } header: {
                        Text("Emergency contacts")
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                } else {
                    Section {
                        ForEach(contacts) { contact in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(contact.name)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(VuumColor.primaryText)
                                Text("\(contact.displayPhone) · \(contact.relationship)")
                                    .font(.footnote)
                                    .foregroundStyle(VuumColor.secondaryText)
                            }
                            .padding(.vertical, 2)
                        }
                    } header: {
                        Text("Emergency contacts")
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                }

                Section {
                    Button("Request help now", role: .destructive) {
                        onConfirm()
                        dismiss()
                    }
                    .foregroundStyle(VuumColor.danger)
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                    .foregroundStyle(VuumColor.primaryText)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(VuumColor.groupedBackground.ignoresSafeArea())
            .navigationTitle("Request emergency help?")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(VuumColor.accent)
                }
            }
        }
        .task { location.startUpdatingIfAllowed() }
        .presentationDetents([.medium, .large])
        .presentationBackground(VuumColor.sheetBackground)
    }
}
