import SwiftUI

/// Uber/Bolt-depth payments hub: wallet, methods, card, vouchers, business profile, receipts, history.
struct PaymentHubView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var payments: PaymentMethodStore
    @EnvironmentObject private var promos: PromoCodesStore
    @EnvironmentObject private var tripSession: TripSession
    @Environment(\.dismiss) private var dismiss

    /// Hide when pushed from Account navigation; show when presented as a sheet.
    var showsDoneButton: Bool = true

    @State private var showAddCard = false
    @State private var showVouchers = false
    @State private var showBusiness = false
    @State private var showReceipts = false
    @State private var showAddFunds = false
    @State private var showHistory = false
    @State private var linkingMethod: PaymentMethod?

    private var market: AppLocale.Market {
        AppLocale.market(countryCode: session.countryCode)
    }

    private var methods: [PaymentMethod] {
        payments.availableMethods(for: market)
    }

    var body: some View {
        List {
            Section {
                balanceRows
                Button { showAddFunds = true } label: {
                    Label("Add funds", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Wallet · \(AppLocale.currencySubtitle(for: market))")
            } footer: {
                Text(walletFooter).font(.footnote)
            }

            Section {
                ForEach(methods) { method in
                    paymentMethodRow(method)
                }
            } header: {
                Text("Payment methods")
            } footer: {
                Text("Default: \(payments.defaultMethodTitle). Used when you confirm a trip.")
            }

            Section("Cards") {
                Button { showAddCard = true } label: {
                    Label(payments.cardDisplayLabel, systemImage: "creditcard.fill")
                }
                if payments.cardLast4 != nil {
                    Button("Remove card", role: .destructive) {
                        payments.removeCard()
                        syncTripPayment()
                    }
                }
            }

            Section("Activity") {
                Button { showHistory = true } label: {
                    Label(
                        payments.transactions.isEmpty
                            ? "Payment history"
                            : "Payment history · \(payments.transactions.count)",
                        systemImage: "list.bullet.rectangle"
                    )
                }
                Button { showReceipts = true } label: {
                    Label("Trip receipts", systemImage: "doc.text.fill")
                }
            }

            Section("Offers") {
                Button { showVouchers = true } label: {
                    Label(
                        promos.savedCodes.isEmpty
                            ? "Vouchers & promo codes"
                            : "Vouchers · \(promos.savedCodes.count) saved",
                        systemImage: "ticket"
                    )
                }
            }

            Section("Business") {
                Button { showBusiness = true } label: {
                    Label(
                        payments.businessProfileEnabled && !payments.businessName.isEmpty
                            ? payments.businessName
                            : "Business payment profile",
                        systemImage: "briefcase.fill"
                    )
                }
            }
        }
        .navigationTitle("Payments & Wallet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDoneButton {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            payments.ensureValidSelection(for: market)
            syncTripPayment()
        }
        .sheet(isPresented: $showAddCard) {
            AddCardShellView().environmentObject(payments)
        }
        .sheet(isPresented: $showVouchers) {
            VouchersShellView().environmentObject(payments)
        }
        .sheet(isPresented: $showBusiness) {
            BusinessPaymentProfileShellView().environmentObject(payments)
        }
        .sheet(isPresented: $showAddFunds) {
            AddFundsShellView(market: market)
                .environmentObject(payments)
        }
        .sheet(isPresented: $showHistory) {
            NavigationStack {
                PaymentHistoryView()
                    .environmentObject(payments)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") { showHistory = false }
                        }
                    }
            }
        }
        .sheet(isPresented: $showReceipts) {
            NavigationStack {
                TripReceiptsShortcutView()
                    .environmentObject(tripSession)
                    .environmentObject(session)
            }
        }
        .sheet(item: $linkingMethod) { method in
            LinkMobileMoneyShellView(method: method)
                .environmentObject(payments)
                .environmentObject(session)
        }
    }

    @ViewBuilder
    private var balanceRows: some View {
        switch market {
        case .kenya:
            LabeledContent("KSh wallet", value: "KSh \(payments.walletBalanceKSh.formatted())")
        case .drc:
            LabeledContent("CDF wallet", value: "CDF \(payments.walletBalanceCDF.formatted())")
            LabeledContent("USD wallet", value: String(format: "$%.2f", payments.walletBalanceUSD))
        case .both:
            LabeledContent("KSh wallet", value: "KSh \(payments.walletBalanceKSh.formatted())")
            LabeledContent("CDF wallet", value: "CDF \(payments.walletBalanceCDF.formatted())")
            LabeledContent("USD wallet", value: String(format: "$%.2f", payments.walletBalanceUSD))
        }
    }

    private var walletFooter: String {
        switch market {
        case .kenya:
            return "Fares are shown in Kenyan shillings. Pay with cash, M-Pesa, Airtel Money, Vuum Wallet, or card."
        case .drc:
            return "Fares are shown in CDF and USD. You can pay in either currency when your trip ends."
        case .both:
            return "Fares follow your market. Kenya uses KSh; DRC shows CDF and USD."
        }
    }

    private func paymentMethodRow(_ method: PaymentMethod) -> some View {
        Button {
            if method.isMobileMoney, payments.linkedPhone(for: method) == nil {
                linkingMethod = method
            } else if method == .card, payments.cardLast4 == nil {
                showAddCard = true
            } else {
                payments.select(method)
                syncTripPayment()
            }
        } label: {
            HStack(spacing: VuumLayout.rowSpacing) {
                VuumIconBadge(systemName: method.systemImage)
                VStack(alignment: .leading, spacing: 2) {
                    Text(method.title)
                        .font(VuumType.rowTitle)
                        .foregroundStyle(VuumColor.primaryText)
                    Text(payments.methodSubtitle(method))
                        .font(VuumType.caption)
                        .foregroundStyle(VuumColor.secondaryText)
                }
                Spacer()
                if payments.selectedMethod == method {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(VuumColor.brand)
                }
            }
            .padding(.vertical, 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(method.title), \(payments.methodSubtitle(method))")
        .accessibilityHint(payments.selectedMethod == method ? "Default payment method" : "Sets as default")
    }

    private func syncTripPayment() {
        if !tripSession.bookOnCompanyWallet {
            tripSession.paymentMethod = payments.selectedMethod
        }
    }
}

// MARK: - Ride options picker

struct PaymentMethodPickerRow: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var payments: PaymentMethodStore
    @EnvironmentObject private var tripSession: TripSession
    @State private var showHub = false

    private var market: AppLocale.Market {
        AppLocale.market(countryCode: session.countryCode)
    }

    var body: some View {
        Group {
            if tripSession.bookOnCompanyWallet {
                HStack {
                    Image(systemName: PaymentMethod.companyWallet.systemImage)
                    Text("Pay with Company")
                        .font(.system(size: 15, weight: .semibold))
                    Spacer()
                }
                .foregroundStyle(VuumColor.primaryText)
                .padding(12)
                .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 12))
            } else {
                Button { showHub = true } label: {
                    HStack {
                        Image(systemName: tripSession.paymentMethod.systemImage)
                        Text("Pay with \(tripSession.paymentMethod.title)")
                            .font(.system(size: 15, weight: .semibold))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                    .foregroundStyle(VuumColor.primaryText)
                    .padding(12)
                    .background(VuumColor.chipBackground, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            payments.ensureValidSelection(for: market)
            if !tripSession.bookOnCompanyWallet {
                tripSession.paymentMethod = payments.selectedMethod
            }
        }
        .onChange(of: payments.selectedMethod) { _, method in
            if !tripSession.bookOnCompanyWallet {
                tripSession.paymentMethod = method
            }
        }
        .onChange(of: tripSession.bookOnCompanyWallet) { _, onCompany in
            if !onCompany {
                tripSession.paymentMethod = payments.selectedMethod
            }
        }
        .sheet(isPresented: $showHub) {
            NavigationStack {
                PaymentHubView(showsDoneButton: true)
                    .environmentObject(session)
                    .environmentObject(payments)
                    .environmentObject(tripSession)
            }
            .presentationDetents([.large])
        }
    }
}

// MARK: - History

struct PaymentHistoryView: View {
    @EnvironmentObject private var payments: PaymentMethodStore

    var body: some View {
        Group {
            if payments.transactions.isEmpty {
                ContentUnavailableView(
                    "No payments yet",
                    systemImage: "creditcard",
                    description: Text("Trip charges and wallet top-ups will appear here.")
                )
            } else {
                List(payments.transactions) { tx in
                    NavigationLink {
                        PaymentTransactionDetailView(transaction: tx)
                    } label: {
                        PaymentTransactionRow(transaction: tx)
                    }
                }
            }
        }
        .navigationTitle("Payment history")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PaymentTransactionRow: View {
    let transaction: PaymentTransaction

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(transaction.tripLabel)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(VuumColor.primaryText)
                Spacer()
                Text(transaction.signedAmountDisplay)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(amountColor)
            }
            HStack {
                Text(transaction.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(transaction.method.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Text(transaction.status.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(statusColor)
        }
        .padding(.vertical, 4)
    }

    private var amountColor: Color {
        switch transaction.kind {
        case .tripCharge: return VuumColor.primaryText
        case .walletTopUp, .promoCredit, .refund: return .green
        }
    }

    private var statusColor: Color {
        switch transaction.status {
        case .successful: return .secondary
        case .failed, .cancelled: return .red
        case .refunded, .partiallyRefunded: return .orange
        case .pending, .processing: return VuumColor.brand
        }
    }
}

struct PaymentTransactionDetailView: View {
    let transaction: PaymentTransaction

    var body: some View {
        List {
            Section("Trip") {
                LabeledContent("Description", value: transaction.tripLabel)
                if let tripId = transaction.tripId {
                    LabeledContent("Trip ID", value: String(tripId.prefix(8)).uppercased())
                }
                LabeledContent("Date", value: transaction.date.formatted(date: .long, time: .shortened))
            }
            Section("Payment") {
                LabeledContent("Amount", value: transaction.amountDisplay)
                if transaction.currency != .usd {
                    LabeledContent("USD", value: String(format: "$%.2f", transaction.amountUSD))
                }
                LabeledContent("Currency", value: transaction.currency.rawValue)
                LabeledContent("Method", value: transaction.method.title)
                LabeledContent("Status", value: transaction.status.title)
                if let note = transaction.refundNote, !note.isEmpty {
                    LabeledContent("Refund", value: note)
                }
                if let receiptId = transaction.receiptId {
                    LabeledContent("Receipt", value: String(receiptId.prefix(8)).uppercased())
                }
            }
        }
        .navigationTitle("Transaction")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Add funds

struct AddFundsShellView: View {
    let market: AppLocale.Market
    @EnvironmentObject private var payments: PaymentMethodStore
    @Environment(\.dismiss) private var dismiss
    @State private var amountText = ""
    @State private var currency: PaymentCurrency = .cdf
    @State private var funding: PaymentMethod = .card
    @State private var errorMessage: String?

    private var fundingChoices: [PaymentMethod] {
        var list: [PaymentMethod] = []
        if payments.cardLast4 != nil { list.append(.card) }
        list.append(contentsOf: AppLocale.mobileMoneyMethods(for: market).filter { payments.linkedPhone(for: $0) != nil })
        if list.isEmpty { list = [.card] }
        return list
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Amount") {
                    Picker("Currency", selection: $currency) {
                        ForEach(currenciesForMarket) { c in
                            Text(c.rawValue).tag(c)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextField(amountPlaceholder, text: $amountText)
                        .keyboardType(.numberPad)
                }
                Section("Fund with") {
                    Picker("Method", selection: $funding) {
                        ForEach(fundingChoices) { method in
                            Text(method.title).tag(method)
                        }
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                }
                Section {
                    Text("Funds stay on this device until you use Vuum Wallet on a trip.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add funds")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                currency = currenciesForMarket.first ?? .cdf
                if let first = fundingChoices.first { funding = first }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        let amount = Int(amountText.filter(\.isNumber)) ?? 0
                        let ok = payments.addFunds(amountLocal: amount, currency: currency, fundingMethod: funding)
                        if ok {
                            dismiss()
                        } else {
                            errorMessage = currency == .usd
                                ? "Enter at least 1 USD"
                                : currency == .ksh
                                    ? "Enter at least KSh 100"
                                    : "Enter at least CDF 1,000"
                        }
                    }
                    .disabled(amountText.filter(\.isNumber).isEmpty)
                }
            }
        }
    }

    private var currenciesForMarket: [PaymentCurrency] {
        switch market {
        case .kenya: return [.ksh]
        case .drc: return [.cdf, .usd]
        case .both: return [.ksh, .cdf, .usd]
        }
    }

    private var amountPlaceholder: String {
        switch currency {
        case .ksh: return "Amount in KSh"
        case .cdf: return "Amount in CDF"
        case .usd: return "Amount in USD"
        }
    }
}

// MARK: - Shells

struct AddCardShellView: View {
    @EnvironmentObject private var payments: PaymentMethodStore
    @Environment(\.dismiss) private var dismiss
    @State private var nameOnCard = ""
    @State private var number = ""
    @State private var expiry = ""
    @State private var cvv = ""
    @State private var brand = "Visa"

    var body: some View {
        NavigationStack {
            Form {
                Section("Card details") {
                    Picker("Brand", selection: $brand) {
                        Text("Visa").tag("Visa")
                        Text("Mastercard").tag("Mastercard")
                    }
                    TextField("Name on card", text: $nameOnCard)
                        .textContentType(.name)
                    TextField("Card number", text: $number)
                        .keyboardType(.numberPad)
                        .textContentType(.creditCardNumber)
                    HStack {
                        TextField("MM/YY", text: $expiry)
                            .keyboardType(.numbersAndPunctuation)
                        TextField("CVV", text: $cvv)
                            .keyboardType(.numberPad)
                    }
                }
                Section {
                    Text("Your card is stored on this device for trip payments.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Add card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        payments.addCard(brand: brand, last4: number, holderName: nameOnCard)
                        dismiss()
                    }
                    .disabled(number.filter(\.isNumber).count < 4)
                }
            }
        }
    }
}

struct LinkMobileMoneyShellView: View {
    let method: PaymentMethod
    @EnvironmentObject private var payments: PaymentMethodStore
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var network: NetworkReachability
    @Environment(\.dismiss) private var dismiss
    @State private var phone = ""
    @State private var isLinking = false
    @State private var linkFailed = false

    var body: some View {
        NavigationStack {
            Group {
                if isLinking {
                    VuumConnectingView(message: L10n.t("status.linking_payment"))
                } else if linkFailed {
                    VuumErrorStateView(
                        title: L10n.t("status.error_title"),
                        message: network.isReachable
                            ? "We couldn't link this number. Check the digits and try again."
                            : L10n.t("status.offline_detail")
                    ) {
                        linkFailed = false
                    }
                } else {
                    Form {
                        Section {
                            TextField("Mobile number", text: $phone)
                                .keyboardType(.phonePad)
                                .textContentType(.telephoneNumber)
                        } header: {
                            Text(method.title)
                        } footer: {
                            Text("We’ll send a payment request to this number when you confirm a trip.")
                        }
                    }
                }
            }
            .navigationTitle("Link \(method.title)")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                if phone.isEmpty {
                    phone = payments.linkedPhone(for: method) ?? session.mobileNumber
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isLinking)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Link") {
                        Task { await performLink() }
                    }
                    .disabled(phone.filter(\.isNumber).count < 8 || isLinking)
                }
            }
        }
    }

    private func performLink() async {
        isLinking = true
        linkFailed = false
        let ok = await network.retry()
        isLinking = false
        guard ok else {
            linkFailed = true
            return
        }
        payments.linkMobileMoney(method, phone: phone)
        dismiss()
    }
}

/// Navigation-friendly promo codes list (Account → Promos & credits).
struct PromoCodesView: View {
    @EnvironmentObject private var promos: PromoCodesStore
    @State private var code = ""
    @State private var message: String?

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Enter promo code", text: $code)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                    Button("Add") {
                        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
                        guard !normalized.isEmpty else {
                            message = "Enter a code"
                            return
                        }
                        if promos.offer(for: normalized) == nil {
                            message = "This promo code isn’t valid"
                            return
                        }
                        let status = promos.validate(
                            code: normalized,
                            market: AppLocale.current,
                            estimatedFareLocal: AppLocale.minimumFareLocal(for: AppLocale.current) * 10,
                            isAirportTrip: false
                        )
                        switch status {
                        case .expired:
                            message = "This promo code has expired"
                        case .invalid:
                            message = "This promo code isn’t valid"
                        case .notEligible(let reason):
                            message = reason
                        case .applied, .idle:
                            let ok = promos.save(normalized)
                            message = ok ? "Code saved" : "Code already saved"
                            if ok { code = "" }
                        }
                    }
                    .font(.system(size: 14, weight: .semibold))
                }
                if let message {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Saved codes can be applied when choosing a ride.")
            }

            if !promos.savedOffers.isEmpty {
                Section("Saved") {
                    ForEach(promos.savedOffers) { offer in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(offer.code)
                                .font(.system(size: 15, weight: .semibold))
                            Text(offer.title)
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            Text(offer.detail)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            promos.remove(promos.savedOffers[index].code)
                        }
                    }
                }
            }

            Section("Available offers") {
                ForEach(promos.catalog.filter { offer in
                    if let expires = offer.expiresAt, expires < Date() { return false }
                    return true
                }) { offer in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(offer.code)
                            .font(.system(size: 15, weight: .semibold))
                        Text(offer.title)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Promos & credits")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct VouchersShellView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PromoCodesView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { dismiss() }
                    }
                }
        }
    }
}

struct BusinessPaymentProfileShellView: View {
    @EnvironmentObject private var payments: PaymentMethodStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Use business profile", isOn: $payments.businessProfileEnabled)
                    TextField("Company name", text: $payments.businessName)
                    TextField("Billing email", text: $payments.businessEmail)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                } footer: {
                    Text("Trips billed to your company appear on a monthly statement.")
                }
            }
            .navigationTitle("Business payments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        payments.saveBusinessProfile()
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TripReceiptsShortcutView: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss

    private var market: AppLocale.Market {
        AppLocale.market(countryCode: session.countryCode)
    }

    var body: some View {
        Group {
            if tripSession.tripHistory.isEmpty {
                ContentUnavailableView(
                    "No receipts yet",
                    systemImage: "doc.text",
                    description: Text("Completed trips will show fare receipts here.")
                )
            } else {
                List(tripSession.tripHistory) { receipt in
                    NavigationLink {
                        TripReceiptDetailView(receipt: receipt, market: market)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(receipt.dropoffName)
                                .font(.system(size: 16, weight: .semibold))
                            Text("\(receipt.pickupName) · \(receipt.tierName)")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                            HStack {
                                Text(receipt.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(
                                    AppLocale.formatFareTotal(
                                        cdf: receipt.fare.totalCDF,
                                        usd: receipt.fare.totalUSD,
                                        market: market
                                    )
                                )
                                .font(.system(size: 13, weight: .semibold))
                            }
                            Text(receipt.paymentMethod.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("Trip receipts")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") { dismiss() }
            }
        }
    }
}
