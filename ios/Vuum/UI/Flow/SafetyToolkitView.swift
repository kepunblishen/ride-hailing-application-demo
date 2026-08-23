import SwiftUI

struct SafetyToolkitView: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var permissions: PermissionCenter
    @EnvironmentObject private var trustedContacts: TrustedContactsStore
    @EnvironmentObject private var location: RiderLocationManager
    @Environment(\.dismiss) private var dismiss
    @State private var showIncidentReport = false
    @State private var showSOSConfirm = false
    @State private var showMicConsent = false

    private var isOnActiveTrip: Bool {
        tripSession.phase == .matched
            || tripSession.phase == .driverEnRoute
            || tripSession.phase == .driverArrived
            || tripSession.phase == .inTrip
    }

    var body: some View {
        NavigationStack {
            List {
                if isOnActiveTrip, let trip = tripSession.activeTrip {
                    Section {
                        if tripSession.sosRequested {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Emergency help requested", systemImage: "checkmark.shield.fill")
                                    .foregroundStyle(.red)
                                    .font(.body.weight(.semibold))
                                LabeledContent("Trip ID", value: TripShare.tripID(for: trip))
                                LabeledContent("Driver", value: "\(trip.driver.name) · \(trip.driver.plate)")
                                LabeledContent(
                                    "Safety team",
                                    value: tripSession.safetyTeamNotified ? "Notified · reaching out" : "Sending details…"
                                )
                                if let coord = location.latestLocation?.coordinate {
                                    LabeledContent(
                                        "Location",
                                        value: String(format: "%.5f, %.5f", coord.latitude, coord.longitude)
                                    )
                                }
                                if !trustedContacts.emergencyContacts.isEmpty {
                                    LabeledContent(
                                        "Contacts",
                                        value: trustedContacts.emergencyContacts.map(\.name).joined(separator: ", ")
                                    )
                                }
                            }
                            .padding(.vertical, 4)
                        } else {
                            Button(role: .destructive) {
                                showSOSConfirm = true
                            } label: {
                                Label("Request emergency help", systemImage: "sos.circle.fill")
                            }
                            .accessibilityHint("Contacts Vuum Safety with your live trip details")
                        }

                        ShareLink(
                            item: TripShare.message(for: trip, phase: tripSession.phase, coordinate: location.latestLocation?.coordinate),
                            subject: Text("My Vuum trip"),
                            message: Text("Follow my live trip on Vuum")
                        ) {
                            Label("Share live trip link", systemImage: "square.and.arrow.up")
                        }

                        if let contact = trustedContacts.defaultContact {
                            ShareLink(
                                item: TripShare.message(for: trip, contact: contact, phase: tripSession.phase, coordinate: location.latestLocation?.coordinate),
                                subject: Text("My Vuum trip"),
                                message: Text("Live trip with \(contact.name)")
                            ) {
                                Label("Share with \(contact.name)", systemImage: "person.crop.circle.badge.checkmark")
                            }
                        }

                        Text(TripShare.liveShareURLString(for: trip))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    } header: {
                        Text("Emergency")
                    } footer: {
                        Text("Sharing sends driver, vehicle, plate, trip ID, destination, ETA, live GPS when available, and a tracking link.")
                    }
                }

                Section("Trust & Safety") {
                    Button {
                        showIncidentReport = true
                    } label: {
                        Label("Report an incident", systemImage: "exclamationmark.shield")
                    }
                }

                if permissions.microphoneDenied || tripSession.audioRecorder.permissionDenied {
                    Section {
                        Label("Safety recording unavailable", systemImage: "mic.slash.fill")
                        Text("Microphone access is off. Recording only runs during an active trip when you turn it on.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Button("Open Settings") {
                            _ = permissions.openSystemSettings()
                        }
                    } header: {
                        Text("Trip audio")
                    }
                } else if tripSession.canRecordTripAudio || tripSession.isRecordingTripAudio {
                    Section {
                        Button {
                            if tripSession.isRecordingTripAudio {
                                tripSession.toggleTripAudioRecording(using: permissions)
                            } else {
                                tripSession.audioRecorder.refreshPermissionState()
                                if tripSession.audioRecorder.permissionState == .undetermined
                                    && !permissions.microphoneAuthorized {
                                    showMicConsent = true
                                } else {
                                    tripSession.toggleTripAudioRecording(using: permissions)
                                }
                            }
                        } label: {
                            Label(
                                tripSession.isRecordingTripAudio ? "Stop recording" : "Record audio",
                                systemImage: tripSession.isRecordingTripAudio ? "stop.circle.fill" : "mic.circle.fill"
                            )
                        }

                        Toggle(isOn: Binding(
                            get: { tripSession.incidentFlagged },
                            set: { tripSession.setIncidentFlagged($0) }
                        )) {
                            Text("Keep audio for an incident report")
                        }

                        if let message = tripSession.audioRecorder.lastErrorMessage {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.red)
                        }
                    } header: {
                        Text("Trip audio")
                    } footer: {
                        Text("Recording is optional and stored on this device. Your driver is notified while recording is on. Audio stops at trip end and is deleted unless you keep it for an incident report.")
                    }
                }

                Section {
                    NavigationLink {
                        TrustedContactsView()
                    } label: {
                        Label("Share trips with trusted contacts", systemImage: "person.2.fill")
                    }
                    if isOnActiveTrip {
                        Label("Use Chat or Call on the trip screen", systemImage: "phone.fill")
                            .foregroundStyle(.secondary)
                        Label("Confirm boarding with your trip PIN at pickup", systemImage: "lock.fill")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Stay safer on every ride")
                } footer: {
                    Text("Trusted contacts can receive your live trip link. Chat, call, and PIN actions stay on the active trip screen.")
                }

                Section("Emergency services") {
                    Link(destination: URL(string: "tel://112")!) {
                        Label("Call 112", systemImage: "phone.fill")
                            .foregroundStyle(.red)
                    }
                }

                Section("Corporate SOS") {
                    let corporate = MockCorporate.miningCo
                    Text(corporate.sosContactName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Link(destination: URL(string: "tel://\(corporate.sosContactPhone.filter { $0.isNumber || $0 == "+" })")!) {
                        Label(corporate.sosContactPhone, systemImage: "phone.fill")
                    }
                }
            }
            .navigationTitle("Safety")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showIncidentReport) {
                IncidentReportView()
            }
            .sheet(isPresented: $showSOSConfirm) {
                SOSConfirmationSheet(
                    location: location,
                    contacts: trustedContacts.emergencyContacts
                ) {
                    tripSession.requestSOS(coordinate: location.latestLocation?.coordinate)
                    showSOSConfirm = false
                }
            }
        }
        .alert("Safety recording", isPresented: $showMicConsent) {
            Button("Continue") {
                tripSession.toggleTripAudioRecording(using: permissions)
            }
            Button("Not now", role: .cancel) {}
        } message: {
            Text("Safety recording is available only during an active trip. Your driver is notified while recording is on.")
        }
        .presentationDetents([.medium, .large])
        .task {
            location.startUpdatingIfAllowed()
            await permissions.refreshStatuses()
            tripSession.audioRecorder.refreshPermissionState()
        }
    }
}
