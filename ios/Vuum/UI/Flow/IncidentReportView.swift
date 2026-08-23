import SwiftUI

enum IncidentCategory: String, CaseIterable, Identifiable, Codable {
    case verbalDispute = "Verbal dispute"
    case harassment = "Harassment"
    case threateningBehavior = "Threatening behavior"
    case driverConduct = "Driver conduct complaint"
    case riderConduct = "Rider conduct complaint"
    case paymentDispute = "Payment dispute"
    case tripDispute = "Trip dispute"
    case safetyConcern = "Safety concern"
    case other = "Other"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .verbalDispute: return "bubble.left.and.exclamationmark.bubble.right"
        case .harassment: return "hand.raised.fill"
        case .threateningBehavior: return "exclamationmark.triangle.fill"
        case .driverConduct: return "car.fill"
        case .riderConduct: return "person.fill"
        case .paymentDispute: return "creditcard.fill"
        case .tripDispute: return "map.fill"
        case .safetyConcern: return "shield.lefthalf.filled"
        case .other: return "ellipsis.circle"
        }
    }
}

struct IncidentReport: Identifiable, Codable, Equatable {
    var id: String
    var category: String
    var description: String
    var audioKept: Bool
    var tripId: String?
    var createdAt: Date
    var status: String
}

enum IncidentReportStore {
    private static let key = "vuum.incidentReports"

    static func load() -> [IncidentReport] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([IncidentReport].self, from: data)
        else { return [] }
        return decoded
    }

    static func save(_ reports: [IncidentReport]) {
        let capped = Array(reports.prefix(50))
        if let data = try? JSONEncoder().encode(capped) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func append(_ report: IncidentReport) {
        var all = load()
        all.insert(report, at: 0)
        save(all)
    }
}

struct IncidentReportView: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var notifications: NotificationStore
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var category: IncidentCategory = .safetyConcern
    @State private var descriptionText = ""
    @State private var keepAudio = false
    @State private var didSubmit = false
    @State private var submittedAudioKept = false
    @State private var referenceID = ""

    private var canKeepAudio: Bool {
        tripSession.audioRecorder.hasRecordingFile || tripSession.isRecordingTripAudio
    }

    private var canSubmit: Bool {
        !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var relatedTripID: String? {
        if let trip = tripSession.activeTrip {
            return TripShare.tripID(for: trip)
        }
        return tripSession.lastReceipt?.id
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Tell us what happened. Our Trust & Safety team will review your report and follow up if needed.")
                        .font(.footnote)
                        .foregroundStyle(VuumColor.secondaryText)
                }

                if let tripID = relatedTripID {
                    Section {
                        LabeledContent("Trip ID", value: tripID)
                    } header: {
                        Text("Related trip")
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                }

                if step == 0 {
                    Section {
                        ForEach(IncidentCategory.allCases) { item in
                            Button {
                                category = item
                                step = 1
                            } label: {
                                HStack(spacing: VuumLayout.rowSpacing) {
                                    Image(systemName: item.systemImage)
                                        .foregroundStyle(VuumColor.accent)
                                        .frame(width: 28)
                                    Text(item.rawValue)
                                        .foregroundStyle(VuumColor.primaryText)
                                    Spacer()
                                    if category == item {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(VuumColor.accent)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    } header: {
                        Text("Incident type")
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                } else {
                    Section {
                        Button {
                            step = 0
                        } label: {
                            Label(category.rawValue, systemImage: category.systemImage)
                                .foregroundStyle(VuumColor.primaryText)
                        }
                    } header: {
                        Text("Category")
                            .foregroundStyle(VuumColor.secondaryText)
                    }

                    Section {
                        TextField("What happened?", text: $descriptionText, axis: .vertical)
                            .lineLimit(4...10)
                            .foregroundStyle(VuumColor.primaryText)
                    } header: {
                        Text("Description")
                            .foregroundStyle(VuumColor.secondaryText)
                    }

                    Section {
                        Toggle(isOn: $keepAudio) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Keep trip audio")
                                    .font(.body)
                                    .foregroundStyle(VuumColor.primaryText)
                                Text(
                                    canKeepAudio
                                        ? "Trip audio will be kept on this device for Safety review."
                                        : "No trip audio is available to keep with this report."
                                )
                                .font(.footnote)
                                .foregroundStyle(VuumColor.secondaryText)
                            }
                        }
                        .tint(VuumColor.accent)
                        .disabled(!canKeepAudio)
                    }

                    if submittedAudioKept {
                        Section {
                            Label("Trip audio retained for Safety review", systemImage: "waveform.badge.mic")
                                .font(.footnote)
                                .foregroundStyle(VuumColor.secondaryText)
                        }
                    }

                    Section {
                        Button("Submit report") {
                            submit()
                        }
                        .disabled(!canSubmit)
                        .fontWeight(.semibold)
                        .foregroundStyle(canSubmit ? VuumColor.accent : VuumColor.secondaryText)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(VuumColor.groupedBackground.ignoresSafeArea())
            .navigationTitle("Report an incident")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(VuumColor.primaryText)
                }
                if step == 1 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Types") { step = 0 }
                            .foregroundStyle(VuumColor.accent)
                    }
                }
            }
            .alert("Report submitted", isPresented: $didSubmit) {
                Button("OK") { dismiss() }
            } message: {
                Text(
                    submittedAudioKept
                        ? "Reference \(referenceID). Your report was saved and trip audio was kept for Safety review."
                        : "Reference \(referenceID). Thanks — Trust & Safety will review your report."
                )
            }
            .onAppear {
                if canKeepAudio {
                    keepAudio = true
                }
            }
        }
    }

    private func submit() {
        let trimmed = descriptionText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let shouldKeepAudio = keepAudio && canKeepAudio
        if shouldKeepAudio {
            tripSession.setIncidentFlagged(true)
            tripSession.audioRecorder.retainRecordingFile()
        }

        let reportID = "IR-\(String(UUID().uuidString.prefix(8)).uppercased())"
        let report = IncidentReport(
            id: reportID,
            category: category.rawValue,
            description: trimmed,
            audioKept: shouldKeepAudio,
            tripId: relatedTripID,
            createdAt: Date(),
            status: "Received"
        )
        IncidentReportStore.append(report)
        notifications.postIncidentUpdate(
            title: "Incident report received",
            body: "Reference \(reportID). Trust & Safety will review \(category.rawValue.lowercased())."
        )
        referenceID = reportID
        submittedAudioKept = shouldKeepAudio
        didSubmit = true
    }
}
