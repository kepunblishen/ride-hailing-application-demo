import SwiftUI

/// Gated internal tools — unlocked via Version taps on About. Never labeled as a product “demo”.
struct DiagnosticsToolsView: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var appLocale: AppLocale
    @EnvironmentObject private var location: RiderLocationManager
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var network: NetworkReachability
    @EnvironmentObject private var fieldSales: FieldSalesStore
    @ObservedObject private var diagnostics = DeveloperDiagnostics.shared
    @ObservedObject private var mapsDiagnostics = GoogleMapsDiagnostics.shared

    @State private var confirmReset = false

    var body: some View {
        List {
            Section {
                Text("Internal tools for QA and presentation prep. Keep locked for client walkthroughs.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Maps credentials") {
                LabeledContent("API key", value: mapsDiagnostics.keyPresenceLabel)
                LabeledContent("Key usable", value: mapsDiagnostics.hasUsableKeyLabel)
                LabeledContent("Maps SDK", value: mapsDiagnostics.mapsSDKConfiguredLabel)
                LabeledContent("Bundle ID", value: mapsDiagnostics.bundleID)
                LabeledContent("Build", value: mapsDiagnostics.buildConfiguration)
                LabeledContent(
                    "Last error",
                    value: mapsDiagnostics.lastErrorCode ?? "None"
                )
                if let rider = mapsDiagnostics.lastRiderMessage {
                    Text(rider)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                #if DEBUG
                if !mapsDiagnostics.recentRequests.isEmpty {
                    ForEach(mapsDiagnostics.recentRequests.prefix(8)) { entry in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.api)
                                .font(.caption.weight(.semibold))
                            Text(
                                "\(entry.outcome) · \(entry.durationMs)ms · attempts \(entry.attemptCount)"
                                    + (entry.httpStatus.map { " · HTTP \($0)" } ?? "")
                            )
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        }
                    }
                    Button("Clear Maps request log") {
                        mapsDiagnostics.clearRequestLog()
                        MapsRequestCache.clearAll()
                    }
                } else {
                    Text("No Google HTTPS calls logged yet (DEBUG).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                #endif
            }

            Section("Market & language") {
                Picker("Market override", selection: Binding(
                    get: { appLocale.override },
                    set: { appLocale.setOverride($0) }
                )) {
                    ForEach(AppLocale.Override.allCases, id: \.rawValue) { value in
                        Text(value.rawValue.capitalized).tag(value)
                    }
                }
                Picker("Language", selection: $preferences.languageCode) {
                    ForEach(AppLanguage.allCases) { lang in
                        Text(lang.displayName).tag(lang.rawValue)
                    }
                }
                LabeledContent("Active market", value: appLocale.marketDisplayName)
            }

            Section("Trip state") {
                LabeledContent("Phase", value: tripSession.phase.rawValue)
                ForEach(TripPhase.allCasesForDiagnostics, id: \.self) { phase in
                    Button("Jump to \(phase.rawValue)") {
                        tripSession.diagnosticsForcePhase(phase)
                    }
                }
                Button("Reset to home", role: .destructive) {
                    tripSession.resetToHome()
                }
            }

            Section("Location") {
                if let coord = location.latestLocation?.coordinate {
                    LabeledContent("Latitude", value: String(format: "%.5f", coord.latitude))
                    LabeledContent("Longitude", value: String(format: "%.5f", coord.longitude))
                    LabeledContent(
                        "Accuracy",
                        value: String(format: "%.0f m", location.latestLocation?.horizontalAccuracy ?? -1)
                    )
                } else {
                    Text("No fix yet")
                        .foregroundStyle(.secondary)
                }
                Button("Refresh location") {
                    location.refreshCurrentLocation()
                }
            }

            Section("Network") {
                Toggle("Force offline", isOn: $diagnostics.forceNetworkOffline)
                    .onChange(of: diagnostics.forceNetworkOffline) { _, offline in
                        network.setForcedOffline(offline)
                    }
                LabeledContent("Reachability", value: network.statusLabel)
            }

            Section("Payments") {
                Picker("Charge simulation", selection: $diagnostics.paymentSimulation) {
                    ForEach(DeveloperDiagnostics.PaymentSimulation.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            }

            Section("Safety") {
                Button("Trigger SOS") {
                    tripSession.requestSOS(coordinate: location.latestLocation?.coordinate)
                }
                Button(tripSession.audioRecorder.isRecording ? "Stop recording" : "Start recording") {
                    Task {
                        if tripSession.audioRecorder.isRecording {
                            tripSession.audioRecorder.stopRecording()
                        } else {
                            _ = await tripSession.audioRecorder.startRecording()
                        }
                    }
                }
                LabeledContent(
                    "Recording file",
                    value: tripSession.audioRecorder.hasRecordingFile ? "Present" : "None"
                )
            }

            Section("Growth & risk") {
                NavigationLink {
                    FieldSalesChecklistView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Field sales checklist")
                            Text("\(fieldSales.checklistProgress.done)/\(fieldSales.checklistProgress.total) ready")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "checklist")
                    }
                }
                NavigationLink {
                    SuspiciousTripFlagsView()
                } label: {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Suspicious trip flags")
                            Text("\(fieldSales.suspiciousFlags.count) internal")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "exclamationmark.shield")
                    }
                }
                NavigationLink {
                    FieldSalesPipelineView()
                } label: {
                    Label("Recruitment pipeline", systemImage: "person.badge.plus")
                }
            }

            Section {
                Button("Clear trip history", role: .destructive) {
                    tripSession.diagnosticsClearHistory()
                }
                Button("Reset growth data", role: .destructive) {
                    fieldSales.resetGrowthData()
                }
                Button("Reset local session data…", role: .destructive) {
                    confirmReset = true
                }
                Button("Lock diagnostics") {
                    network.setForcedOffline(false)
                    diagnostics.lock()
                }
            }
        }
        .navigationTitle("Diagnostics")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            network.setForcedOffline(diagnostics.forceNetworkOffline)
        }
        .confirmationDialog("Reset local data?", isPresented: $confirmReset, titleVisibility: .visible) {
            Button("Reset trips & growth", role: .destructive) {
                tripSession.diagnosticsClearHistory()
                tripSession.resetToHome()
                fieldSales.resetGrowthData()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Clears trip history and field-sales pipeline on this device. Account sign-in is kept.")
        }
    }
}

struct FieldSalesChecklistView: View {
    @EnvironmentObject private var fieldSales: FieldSalesStore

    var body: some View {
        List {
            Section {
                Text("Use before a growth / field-sales conversation. Items stay on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("Walkthrough") {
                ForEach(fieldSales.checklist) { item in
                    Toggle(isOn: Binding(
                        get: { item.isComplete },
                        set: { fieldSales.setChecklistItem(id: item.id, complete: $0) }
                    )) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.title)
                                .font(.body.weight(.medium))
                            Text(item.detail)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Section {
                Button("Reset checklist") {
                    fieldSales.resetChecklist()
                }
            }
        }
        .navigationTitle("Field sales checklist")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct SuspiciousTripFlagsView: View {
    @EnvironmentObject private var fieldSales: FieldSalesStore

    var body: some View {
        List {
            Section {
                Text("Internal risk signals only. Not shown on rider trip screens.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if fieldSales.suspiciousFlags.isEmpty {
                Section {
                    Text("No flags yet.")
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("Flags") {
                    ForEach(fieldSales.suspiciousFlags) { flag in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(flag.tripLabel)
                                    .font(.body.weight(.semibold))
                                Spacer()
                                Text(flag.severity.rawValue.uppercased())
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(severityColor(flag.severity))
                            }
                            Text(flag.reasons.map(\.title).joined(separator: " · "))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Text(flag.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                Section {
                    Button("Clear flags", role: .destructive) {
                        fieldSales.clearSuspiciousFlags()
                    }
                }
            }
        }
        .navigationTitle("Suspicious trips")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func severityColor(_ severity: SuspiciousFlagSeverity) -> Color {
        switch severity {
        case .info: return .secondary
        case .watch: return .orange
        case .high: return .red
        }
    }
}

struct FieldSalesPipelineView: View {
    @EnvironmentObject private var fieldSales: FieldSalesStore
    @State private var newName = ""

    var body: some View {
        List {
            if let attr = fieldSales.riderAttribution {
                Section("Your attribution") {
                    attributionBlock(attr)
                    eligibilityStrip(attr.highestMilestone)
                }
            }

            Section("Commissions") {
                LabeledContent("Pending / eligible", value: "\(fieldSales.pendingCommissionCount)")
                LabeledContent("Awarded total", value: "CDF \(fieldSales.awardedCommissionCDF.formatted())")
            }

            Section("Recruitments") {
                ForEach(fieldSales.recruitments) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.displayName)
                                .font(.body.weight(.semibold))
                            Spacer()
                            Text(item.commissionState.title)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(commissionColor(item.commissionState))
                        }
                        Text("\(item.kind.title) · \(item.source.title)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if let exec = fieldSales.executive(for: item.salesExecutiveId) {
                            Text("Sales: \(exec.displayName) (\(exec.salesCode))")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        eligibilityStrip(item.highestMilestone)
                        if let reason = item.blockReason {
                            Text(reason)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }

            Section("Track rider recruit") {
                TextField("Display name", text: $newName)
                Button("Add as field-sales recruit") {
                    fieldSales.addRecruitment(
                        displayName: newName,
                        kind: .rider,
                        source: .fieldSales,
                        salesCode: "FS-LU-042"
                    )
                    newName = ""
                }
                .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .navigationTitle("Recruitment pipeline")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func attributionBlock(_ attr: RecruitmentAttribution) -> some View {
        LabeledContent("Source", value: attr.source.title)
        if let code = attr.referralCode {
            LabeledContent("Code", value: code)
        }
        if let exec = fieldSales.executive(for: attr.salesExecutiveId) {
            LabeledContent("Sales executive", value: "\(exec.displayName) · \(exec.salesCode)")
        }
        LabeledContent("Commission", value: attr.commissionState.title)
    }

    private func eligibilityStrip(_ milestone: EligibilityMilestone) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(EligibilityMilestone.allCases) { step in
                    Text(step.title)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            step <= milestone
                                ? VuumColor.brand.opacity(0.35)
                                : Color.secondary.opacity(0.12),
                            in: Capsule()
                        )
                        .foregroundStyle(step <= milestone ? VuumColor.brandInk : .secondary)
                }
            }
        }
    }

    private func commissionColor(_ state: CommissionState) -> Color {
        switch state {
        case .awarded, .eligible: return .green
        case .blocked, .voided: return .red
        case .pending: return .secondary
        }
    }
}

private extension TripPhase {
    static var allCasesForDiagnostics: [TripPhase] {
        [.idle, .selectingDestination, .choosingRide, .searching, .matched, .driverEnRoute, .driverArrived, .inTrip, .completed]
    }
}

private extension NetworkReachability {
    var statusLabel: String {
        switch status {
        case .online: return "Online"
        case .offline: return "Offline"
        case .constrained: return "Constrained"
        }
    }
}
