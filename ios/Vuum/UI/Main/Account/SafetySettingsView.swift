import SwiftUI
import UIKit

struct SafetySettingsView: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var trustedContacts: TrustedContactsStore
    @EnvironmentObject private var permissions: PermissionCenter
    @EnvironmentObject private var location: RiderLocationManager
    @Environment(\.openURL) private var openURL
    @AppStorage("vuum.safety.shareByDefault") private var shareByDefault = true
    @AppStorage("vuum.safety.requirePIN") private var requirePIN = true
    @AppStorage("vuum.safety.audioRecordingNotice") private var audioRecordingNotice = true
    @AppStorage(SafetyAutoActivation.autoRecordKey) private var autoRecordNightLong = true
    @AppStorage(SafetyAutoActivation.audioQualityKey) private var audioQuality = SafetyAutoActivation.AudioQuality.standard.rawValue
    @State private var showSOSConfirm = false
    @State private var showIncidentReport = false
    @State private var showShareSheet = false
    @State private var sharePayload: String?

    private var isOnActiveTrip: Bool {
        tripSession.phase == .matched
            || tripSession.phase == .driverEnRoute
            || tripSession.phase == .driverArrived
            || tripSession.phase == .inTrip
    }

    private var microphoneStatusLabel: String {
        if permissions.microphoneAuthorized { return "On" }
        if permissions.microphoneDenied { return "Off" }
        return "Not asked yet"
    }

    var body: some View {
        List {
            if isOnActiveTrip, let trip = tripSession.activeTrip {
                Section {
                    if tripSession.sosRequested {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Emergency help requested", systemImage: "checkmark.shield.fill")
                                .foregroundStyle(.red)
                                .font(.body.weight(.semibold))
                            LabeledContent("Trip ID", value: TripShare.tripID(for: trip))
                            LabeledContent(
                                "Safety team",
                                value: tripSession.safetyTeamNotified ? "Notified · reaching out" : "Sending details…"
                            )
                        }
                        .padding(.vertical, 4)
                    } else {
                        Button(role: .destructive) {
                            showSOSConfirm = true
                        } label: {
                            Label("Request emergency help", systemImage: "sos.circle.fill")
                        }
                    }

                    Button {
                        sharePayload = TripShare.message(for: trip, phase: tripSession.phase)
                        showShareSheet = true
                    } label: {
                        Label("Share live trip", systemImage: "square.and.arrow.up")
                    }

                    if let contact = trustedContacts.defaultContact {
                        ShareLink(
                            item: TripShare.message(for: trip, contact: contact, phase: tripSession.phase),
                            subject: Text("My Vuum trip"),
                            message: Text("Live trip with \(contact.name)")
                        ) {
                            Label("Share with \(contact.name)", systemImage: "person.crop.circle.badge.checkmark")
                        }
                    }
                } header: {
                    Text("This trip")
                } footer: {
                    Text("Sharing includes driver, vehicle, plate, trip ID, destination, ETA, and a live tracking link.")
                }
            }

            Section {
                LabeledContent("Microphone", value: microphoneStatusLabel)
                Text("Safety recording is available only during an active trip when you turn it on.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if permissions.microphoneDenied {
                    Text("Recording stays unavailable until microphone access is turned on.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button("Open Settings") {
                        permissions.openSystemSettings()
                    }
                }
            } header: {
                Text("Safety recording")
            }

            Section("Ride safeguards") {
                Toggle("Share trip with trusted contacts by default", isOn: $shareByDefault)
                Toggle("Require trip PIN before boarding", isOn: $requirePIN)
                Toggle("Show in-trip recording notice", isOn: $audioRecordingNotice)
                Toggle(isOn: $autoRecordNightLong) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-start recording on night / long trips")
                        Text("Applies when a trip is matched or underway.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Picker("Recording quality", selection: $audioQuality) {
                    ForEach(SafetyAutoActivation.AudioQuality.allCases) { quality in
                        Text(quality.title).tag(quality.rawValue)
                    }
                }
            }

            Section("Tools") {
                NavigationLink {
                    TrustedContactsView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Trusted contacts")
                            Text(
                                trustedContacts.contacts.isEmpty
                                    ? "Add people for trip sharing and SOS"
                                    : "\(trustedContacts.contacts.count) saved"
                            )
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "person.2.fill")
                    }
                }

                if isOnActiveTrip, let trip = tripSession.activeTrip {
                    Button {
                        DriverCallHelper.placeCall(to: trip.driver.phone)
                    } label: {
                        Label("Call your driver", systemImage: "phone.fill")
                    }
                }

                Button {
                    showIncidentReport = true
                } label: {
                    Label("Report a safety issue", systemImage: "exclamationmark.shield")
                }
            }

            Section("Safety tips") {
                Label("Share your trip before you get in", systemImage: "square.and.arrow.up")
                Label("Confirm the plate and PIN with your driver", systemImage: "lock.fill")
                Label("Sit in the back seat when riding alone", systemImage: "car.fill")
                Label("Use SOS if you feel unsafe at any time", systemImage: "sos.circle")
            }

            Section("Emergency services") {
                Link(destination: URL(string: "tel://112")!) {
                    Label("Call 112", systemImage: "phone.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Safety")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await permissions.refreshStatuses()
        }
        .sheet(isPresented: $showSOSConfirm) {
            SOSConfirmationSheet(
                location: location,
                contacts: trustedContacts.emergencyContacts
            ) {
                tripSession.requestSOS()
                showSOSConfirm = false
            }
        }
        .sheet(isPresented: $showIncidentReport) {
            IncidentReportView()
        }
        .sheet(isPresented: $showShareSheet) {
            if let sharePayload {
                VuumActivityView(activityItems: [sharePayload])
            }
        }
    }
}
