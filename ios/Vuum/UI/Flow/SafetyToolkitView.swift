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
                            VStack(alignment: .leading, spacing: VuumLayout.chipSpacing) {
                                Label("Emergency help requested", systemImage: "checkmark.shield.fill")
                                    .foregroundStyle(VuumColor.danger)
                                    .font(VuumType.bodySemibold)

                                sosDetailRow(title: "Trip ID", value: TripShare.tripID(for: trip))
                                sosDetailRow(title: "Driver", value: "\(trip.driver.name) · \(trip.driver.plate)")
                                sosDetailRow(
                                    title: "Safety team",
                                    value: tripSession.safetyTeamNotified ? "Notified · reaching out" : "Sending details…"
                                )
                                if let coord = location.latestLocation?.coordinate {
                                    sosDetailRow(
                                        title: "Location",
                                        value: String(format: "%.5f, %.5f", coord.latitude, coord.longitude)
                                    )
                                }
                                if !trustedContacts.emergencyContacts.isEmpty {
                                    sosDetailRow(
                                        title: "Contacts",
                                        value: trustedContacts.emergencyContacts.map(\.name).joined(separator: ", ")
                                    )
                                }
                            }
                            .padding(.vertical, 2)
                        } else {
                            Button(role: .destructive) {
                                showSOSConfirm = true
                            } label: {
                                Label("Request emergency help", systemImage: "sos.circle.fill")
                                    .foregroundStyle(VuumColor.danger)
                            }
                            .accessibilityHint("Contacts Vuum Safety with your live trip details")
                        }

                        ShareLink(
                            item: TripShare.message(for: trip, phase: tripSession.phase, coordinate: location.latestLocation?.coordinate),
                            subject: Text("My Vuum trip"),
                            message: Text("Follow my live trip on Vuum")
                        ) {
                            Label("Share live trip link", systemImage: "square.and.arrow.up")
                                .foregroundStyle(VuumColor.primaryText)
                        }

                        if let contact = trustedContacts.defaultContact {
                            ShareLink(
                                item: TripShare.message(for: trip, contact: contact, phase: tripSession.phase, coordinate: location.latestLocation?.coordinate),
                                subject: Text("My Vuum trip"),
                                message: Text("Live trip with \(contact.name)")
                            ) {
                                Label("Share with \(contact.name)", systemImage: "person.crop.circle.badge.checkmark")
                                    .foregroundStyle(VuumColor.primaryText)
                            }
                        }

                        Text(TripShare.liveShareURLString(for: trip))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(VuumColor.secondaryText)
                            .textSelection(.enabled)
                            .padding(.top, 2)
                    } header: {
                        Text("Emergency")
                            .foregroundStyle(VuumColor.secondaryText)
                    } footer: {
                        Text("Sharing sends driver, vehicle, plate, trip ID, destination, ETA, live GPS when available, and a tracking link.")
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                }

                Section {
                    Button {
                        showIncidentReport = true
                    } label: {
                        Label("Report an incident", systemImage: "exclamationmark.shield")
                            .foregroundStyle(VuumColor.primaryText)
                    }
                } header: {
                    Text("Trust & Safety")
                        .foregroundStyle(VuumColor.secondaryText)
                }

                if permissions.microphoneDenied || tripSession.audioRecorder.permissionDenied {
                    Section {
                        Label("Safety recording unavailable", systemImage: "mic.slash.fill")
                            .foregroundStyle(VuumColor.primaryText)
                        Text("Microphone access is off. Recording only runs during an active trip when you turn it on.")
                            .font(.footnote)
                            .foregroundStyle(VuumColor.secondaryText)
                        Button("Open Settings") {
                            _ = permissions.openSystemSettings()
                        }
                        .foregroundStyle(VuumColor.accent)
                    } header: {
                        Text("Trip audio")
                            .foregroundStyle(VuumColor.secondaryText)
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
                            .foregroundStyle(
                                tripSession.isRecordingTripAudio ? VuumColor.danger : VuumColor.primaryText
                            )
                        }

                        Toggle(isOn: Binding(
                            get: { tripSession.incidentFlagged },
                            set: { tripSession.setIncidentFlagged($0) }
                        )) {
                            Text("Keep audio for an incident report")
                                .foregroundStyle(VuumColor.primaryText)
                        }
                        .tint(VuumColor.accent)

                        if let message = tripSession.audioRecorder.lastErrorMessage {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(VuumColor.danger)
                        }
                    } header: {
                        Text("Trip audio")
                            .foregroundStyle(VuumColor.secondaryText)
                    } footer: {
                        Text("Recording is optional and stored on this device. Your driver is notified while recording is on. Audio stops at trip end and is deleted unless you keep it for an incident report.")
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                }

                Section {
                    NavigationLink {
                        TrustedContactsView()
                    } label: {
                        Label("Share trips with trusted contacts", systemImage: "person.2.fill")
                            .foregroundStyle(VuumColor.primaryText)
                    }
                    if isOnActiveTrip {
                        Label("Use Chat or Call on the trip screen", systemImage: "phone.fill")
                            .foregroundStyle(VuumColor.secondaryText)
                        Label("Confirm boarding with your trip PIN at pickup", systemImage: "lock.fill")
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                } header: {
                    Text("Stay safer on every ride")
                        .foregroundStyle(VuumColor.secondaryText)
                } footer: {
                    Text("Trusted contacts can receive your live trip link. Chat, call, and PIN actions stay on the active trip screen.")
                        .foregroundStyle(VuumColor.secondaryText)
                }

                Section {
                    Link(destination: URL(string: "tel://112")!) {
                        Label("Call 112", systemImage: "phone.fill")
                            .foregroundStyle(VuumColor.danger)
                    }
                } header: {
                    Text("Emergency services")
                        .foregroundStyle(VuumColor.secondaryText)
                }

                Section {
                    let corporate = MockCorporate.miningCo
                    Text(corporate.sosContactName)
                        .font(.footnote)
                        .foregroundStyle(VuumColor.secondaryText)
                    Link(destination: URL(string: "tel://\(corporate.sosContactPhone.filter { $0.isNumber || $0 == "+" })")!) {
                        Label(corporate.sosContactPhone, systemImage: "phone.fill")
                            .foregroundStyle(VuumColor.accent)
                    }
                } header: {
                    Text("Corporate SOS")
                        .foregroundStyle(VuumColor.secondaryText)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(VuumColor.groupedBackground.ignoresSafeArea())
            .navigationTitle("Safety")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(VuumColor.accent)
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
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .task {
            location.startUpdatingIfAllowed()
            await permissions.refreshStatuses()
            tripSession.audioRecorder.refreshPermissionState()
        }
    }

    private func sosDetailRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(VuumType.caption)
                .foregroundStyle(VuumColor.secondaryText)
            Spacer(minLength: 8)
            Text(value)
                .font(VuumType.callout)
                .foregroundStyle(VuumColor.primaryText)
                .multilineTextAlignment(.trailing)
        }
    }
}
