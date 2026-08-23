import SwiftUI

/// Rider-facing corporate (B2B) profile — not an admin portal.
struct BusinessProfileView: View {
    @EnvironmentObject private var tripSession: TripSession
    private let account = MockCorporate.miningCo
    @State private var vipTransferOn: Bool
    @State private var meetAndGreetOn: Bool
    @State private var travellerName = ""
    @State private var tripPurpose = ""
    @State private var showExecutiveBooking = false
    @State private var companyWalletBalanceCDF: Int

    init() {
        let account = MockCorporate.miningCo
        _vipTransferOn = State(initialValue: account.vipTransferEnabled)
        _meetAndGreetOn = State(initialValue: account.meetAndGreetDefault)
        _companyWalletBalanceCDF = State(initialValue: account.companyWalletBalanceCDF)
    }

    private var corporateTrips: [CorporateTripRecord] {
        MockCorporate.recentTrips
    }

    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "building.2.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(VuumColor.brand)
                        .frame(width: 52, height: 52)
                        .background(VuumColor.brand.opacity(0.2), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(account.companyName)
                            .font(.system(size: 18, weight: .semibold))
                        Text("\(account.department) · \(account.employeeRole)")
                            .font(.system(size: 14))
                            .foregroundStyle(VuumColor.secondaryText)
                        Text("Employee ID · \(account.employeeId)")
                            .font(.system(size: 12))
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Spend & allowance") {
                LabeledContent("Monthly limit", value: "CDF \(account.monthlySpendLimitCDF.formatted())")
                LabeledContent("Transport allowance", value: "CDF \(account.transportAllowanceCDF.formatted())")
                LabeledContent("Used this month", value: "CDF \(account.spentThisMonthCDF.formatted())")
                LabeledContent("Remaining", value: "CDF \(account.remainingSpendCDF.formatted())")
                ProgressView(
                    value: Double(account.spentThisMonthCDF),
                    total: Double(max(account.monthlySpendLimitCDF, 1))
                )
                .tint(VuumColor.brand)
                Text("Cost centre · \(account.costCentre)")
                    .font(.footnote)
                    .foregroundStyle(VuumColor.secondaryText)
                if account.remainingSpendCDF == 0 {
                    Text("Monthly spend limit reached. Personal payment methods are required until the next cycle.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }

            Section("Company wallet") {
                LabeledContent("Available balance", value: "CDF \(companyWalletBalanceCDF.formatted())")
                Toggle(isOn: Binding(
                    get: { tripSession.bookOnCompanyWallet },
                    set: { tripSession.setBookOnCompanyWallet($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Book on company wallet")
                        Text(
                            account.remainingSpendCDF > 0
                                ? "Work trips bill to \(account.costCentre)"
                                : "Limit reached — company wallet unavailable"
                        )
                        .font(.caption)
                        .foregroundStyle(VuumColor.secondaryText)
                    }
                }
                .tint(VuumColor.brand)
                .disabled(account.remainingSpendCDF <= 0)

                NavigationLink {
                    BankReferenceTopUpView(balanceCDF: $companyWalletBalanceCDF)
                } label: {
                    Label("Top up by bank reference", systemImage: "building.columns.fill")
                }
            }

            Section("Employee onboarding") {
                NavigationLink {
                    CorporateOnboardingView()
                } label: {
                    Label("WhatsApp & QR join", systemImage: "qrcode.viewfinder")
                }
            }

            Section("Executive & VIP") {
                Toggle(isOn: $vipTransferOn) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("VIP / Executive transfer")
                        Text("Vetted drivers · advance-ready")
                            .font(.caption)
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                }
                .tint(VuumColor.brand)
                .onChange(of: vipTransferOn) { _, on in
                    tripSession.setVIPExecutiveTransfer(on)
                    if !on {
                        meetAndGreetOn = false
                    }
                }

                Toggle(isOn: $meetAndGreetOn) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Meet-and-greet")
                        Text("Driver meets traveller at arrivals with name sign")
                            .font(.caption)
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                }
                .tint(VuumColor.brand)
                .disabled(!vipTransferOn)
                .onChange(of: meetAndGreetOn) { _, on in
                    tripSession.setMeetAndGreetEnabled(on)
                    if on, !travellerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        tripSession.meetAndGreetSignName = travellerName.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }

                if vipTransferOn {
                    TextField("Traveller name", text: $travellerName)
                        .textContentType(.name)
                        .onChange(of: travellerName) { _, name in
                            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                            tripSession.passengerName = trimmed
                            if meetAndGreetOn {
                                tripSession.meetAndGreetSignName = trimmed
                            }
                        }
                    TextField("Trip purpose", text: $tripPurpose)
                        .onChange(of: tripPurpose) { _, purpose in
                            tripSession.tripPurpose = purpose.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    Text("Premium messaging: confirmed driver profile, plate, and pickup briefing before departure.")
                        .font(.footnote)
                        .foregroundStyle(VuumColor.secondaryText)

                    Button {
                        showExecutiveBooking = true
                    } label: {
                        Label("Book executive transfer", systemImage: "crown.fill")
                    }
                }
            }

            Section("Corporate rides") {
                if corporateTrips.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("No corporate history yet")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Company-wallet trips for \(account.costCentre) will appear here.")
                            .font(.system(size: 13))
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                    .padding(.vertical, 2)
                } else {
                    ForEach(corporateTrips) { trip in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(trip.pickupName) → \(trip.dropoffName)")
                                .font(.system(size: 15, weight: .semibold))
                            Text("\(trip.tierName) · \(trip.purpose)")
                                .font(.system(size: 12))
                                .foregroundStyle(VuumColor.secondaryText)
                            HStack {
                                Text(trip.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 12))
                                    .foregroundStyle(VuumColor.secondaryText)
                                Spacer()
                                Text("CDF \(trip.totalCDF.formatted())")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            Text(trip.billedToCompany ? "Billed to company · \(trip.costCentre)" : "Personal")
                                .font(.system(size: 11))
                                .foregroundStyle(VuumColor.secondaryText)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section("Safety & support") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Corporate SOS")
                        .font(.system(size: 15, weight: .semibold))
                    Text(account.sosContactName)
                        .font(.system(size: 14))
                    Link(destination: URL(string: "tel://\(account.sosContactPhone.filter { $0.isNumber || $0 == "+" })")!) {
                        Label(account.sosContactPhone, systemImage: "phone.fill")
                    }
                }
                .padding(.vertical, 2)

                NavigationLink {
                    SupportCenterView()
                } label: {
                    Label("Corporate support", systemImage: "headset")
                }

                if let supportURL = URL(string: "tel://\(account.corporateSupportPhone.filter { $0.isNumber || $0 == "+" })") {
                    Link(destination: supportURL) {
                        Label(account.corporateSupportPhone, systemImage: "phone.badge.waveform")
                    }
                }
            }

            Section("Company trips") {
                VuumInlineEmptyRow(
                    systemImage: "briefcase",
                    title: L10n.t("status.empty_corporate_title"),
                    message: L10n.t("status.empty_corporate_detail")
                )
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(VuumColor.groupedBackground.ignoresSafeArea())
        .listRowSeparatorTint(VuumColor.divider)
        .tint(VuumColor.brand)
        .navigationTitle("Business")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showExecutiveBooking) {
            ExecutiveProductSheet()
                .environmentObject(tripSession)
        }
        .onAppear {
            if vipTransferOn {
                tripSession.setVIPExecutiveTransfer(true)
            }
            if meetAndGreetOn {
                tripSession.setMeetAndGreetEnabled(true)
            }
        }
    }
}

/// Compact corporate options shown on the ride-options sheet.
struct CorporateTripOptionsView: View {
    @EnvironmentObject private var tripSession: TripSession
    private let account = MockCorporate.miningCo

    private var selectedFareCDF: Int {
        tripSession.selectedTier?.priceCDF ?? 0
    }

    private var canUseCompanyWallet: Bool {
        account.remainingSpendCDF > 0 && account.canCoverFare(cdf: max(selectedFareCDF, 1))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "briefcase.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(VuumColor.brand)
                Text(account.companyName)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("CDF \(account.remainingSpendCDF.formatted()) left")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VuumColor.secondaryText)
            }

            Toggle(isOn: Binding(
                get: { tripSession.bookOnCompanyWallet },
                set: { tripSession.setBookOnCompanyWallet($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Book on company wallet")
                        .font(.system(size: 14, weight: .medium))
                    Text(
                        canUseCompanyWallet
                            ? "\(account.department) · \(account.costCentre)"
                            : "Exceeds remaining spend or wallet balance"
                    )
                    .font(.system(size: 11))
                    .foregroundStyle(VuumColor.secondaryText)
                }
            }
            .tint(VuumColor.brand)
            .disabled(!canUseCompanyWallet && !tripSession.bookOnCompanyWallet)

            Toggle(isOn: Binding(
                get: { tripSession.vipExecutiveTransfer },
                set: { tripSession.setVIPExecutiveTransfer($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("VIP / Executive transfer")
                        .font(.system(size: 14, weight: .medium))
                    Text("Routes SOS to \(account.sosContactName)")
                        .font(.system(size: 11))
                        .foregroundStyle(VuumColor.secondaryText)
                }
            }
            .tint(VuumColor.brand)

            Toggle(isOn: Binding(
                get: { tripSession.meetAndGreetEnabled },
                set: { tripSession.setMeetAndGreetEnabled($0) }
            )) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Meet-and-greet")
                        .font(.system(size: 14, weight: .medium))
                    Text("Name board · door instructions")
                        .font(.system(size: 11))
                        .foregroundStyle(VuumColor.secondaryText)
                }
            }
            .tint(VuumColor.brand)
            .disabled(!tripSession.vipExecutiveTransfer)
        }
        .padding(12)
        .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
