import Combine
import Foundation

/// Shared payment selection, wallet balances, and transaction ledger (UserDefaults).
@MainActor
final class PaymentMethodStore: ObservableObject {
    private enum Keys {
        static let selected = "vuum.payment.selected"
        static let cardLast4 = "vuum.payment.cardLast4"
        static let cardBrand = "vuum.payment.cardBrand"
        static let cardName = "vuum.payment.cardName"
        static let vouchers = "vuum.payment.vouchers"
        static let businessEnabled = "vuum.payment.businessEnabled"
        static let businessName = "vuum.payment.businessName"
        static let businessEmail = "vuum.payment.businessEmail"
        static let mpesaPhone = "vuum.payment.mpesaPhone"
        static let airtelPhone = "vuum.payment.airtelPhone"
        static let orangePhone = "vuum.payment.orangePhone"
        static let walletKSh = "vuum.payment.walletKSh"
        static let walletCDF = "vuum.payment.walletCDF"
        static let walletUSD = "vuum.payment.walletUSD"
        static let transactions = "vuum.payment.transactions"
        static let seededLedger = "vuum.payment.seededLedger.v1"
    }

    @Published private(set) var selectedMethod: PaymentMethod
    @Published private(set) var cardLast4: String?
    @Published private(set) var cardBrand: String?
    @Published private(set) var cardHolderName: String?
    @Published private(set) var savedVouchers: [String]
    @Published var businessProfileEnabled: Bool
    @Published var businessName: String
    @Published var businessEmail: String
    @Published var mpesaPhone: String
    @Published var airtelPhone: String
    @Published var orangePhone: String
    @Published private(set) var walletBalanceKSh: Int
    @Published private(set) var walletBalanceCDF: Int
    @Published private(set) var walletBalanceUSD: Double
    @Published private(set) var transactions: [PaymentTransaction]
    @Published private(set) var lastChargeMessage: String?

    private let defaults: UserDefaults
    private lazy var gateway: PaymentGateway = PaymentGateway(
        wallet: LocalWalletPaymentProvider { [weak self] currency, local, usd in
            guard let self else { return false }
            return self.hasWalletFunds(currency: currency, local: local, usd: usd)
        }
    )

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let raw = defaults.string(forKey: Keys.selected),
           let method = PaymentMethod(rawValue: raw),
           method != .companyWallet {
            selectedMethod = method
        } else {
            selectedMethod = .cash
        }
        cardLast4 = defaults.string(forKey: Keys.cardLast4)
        cardBrand = defaults.string(forKey: Keys.cardBrand)
        cardHolderName = defaults.string(forKey: Keys.cardName)
        savedVouchers = defaults.stringArray(forKey: Keys.vouchers) ?? []
        businessProfileEnabled = defaults.bool(forKey: Keys.businessEnabled)
        businessName = defaults.string(forKey: Keys.businessName) ?? ""
        businessEmail = defaults.string(forKey: Keys.businessEmail) ?? ""
        mpesaPhone = defaults.string(forKey: Keys.mpesaPhone) ?? ""
        airtelPhone = defaults.string(forKey: Keys.airtelPhone) ?? ""
        orangePhone = defaults.string(forKey: Keys.orangePhone) ?? ""
        walletBalanceKSh = defaults.object(forKey: Keys.walletKSh) as? Int ?? 4_850
        walletBalanceCDF = defaults.object(forKey: Keys.walletCDF) as? Int ?? 125_000
        walletBalanceUSD = defaults.object(forKey: Keys.walletUSD) as? Double ?? 42.50
        transactions = Self.loadTransactions(from: defaults)
        if !defaults.bool(forKey: Keys.seededLedger), transactions.isEmpty {
            transactions = Self.sampleLedger()
            persistTransactions()
            defaults.set(true, forKey: Keys.seededLedger)
            persistWalletBalances()
        }
    }

    var defaultMethodTitle: String { selectedMethod.title }

    func availableMethods(for market: AppLocale.Market) -> [PaymentMethod] {
        AppLocale.ridePaymentMethods(for: market)
    }

    func select(_ method: PaymentMethod) {
        selectedMethod = method
        if method != .companyWallet {
            defaults.set(method.rawValue, forKey: Keys.selected)
        }
    }

    func ensureValidSelection(for market: AppLocale.Market) {
        let allowed = availableMethods(for: market)
        if selectedMethod != .companyWallet, !allowed.contains(selectedMethod) {
            select(allowed.first ?? .cash)
        }
    }

    func canSelect(_ method: PaymentMethod) -> Bool {
        switch method {
        case .card:
            return cardLast4 != nil
        case .mpesa, .airtelMoney, .orangeMoney:
            return linkedPhone(for: method) != nil
        case .wallet, .cash, .companyWallet:
            return true
        }
    }

    func addCard(brand: String, last4: String, holderName: String = "") {
        let digits = String(last4.filter(\.isNumber).suffix(4))
        guard digits.count == 4 else { return }
        cardBrand = brand.trimmingCharacters(in: .whitespacesAndNewlines)
        cardLast4 = digits
        let name = holderName.trimmingCharacters(in: .whitespacesAndNewlines)
        cardHolderName = name.isEmpty ? nil : name
        defaults.set(cardBrand, forKey: Keys.cardBrand)
        defaults.set(cardLast4, forKey: Keys.cardLast4)
        if let cardHolderName {
            defaults.set(cardHolderName, forKey: Keys.cardName)
        } else {
            defaults.removeObject(forKey: Keys.cardName)
        }
        select(.card)
    }

    func removeCard() {
        cardBrand = nil
        cardLast4 = nil
        cardHolderName = nil
        defaults.removeObject(forKey: Keys.cardBrand)
        defaults.removeObject(forKey: Keys.cardLast4)
        defaults.removeObject(forKey: Keys.cardName)
        if selectedMethod == .card {
            select(.cash)
        }
    }

    var cardDisplayLabel: String {
        guard let last4 = cardLast4 else { return "Add a card" }
        let brand = cardBrand?.isEmpty == false ? (cardBrand ?? "Card") : "Card"
        return "\(brand) · •••• \(last4)"
    }

    @discardableResult
    func addVoucher(_ code: String) -> Bool {
        let normalized = code.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !normalized.isEmpty, !savedVouchers.contains(normalized) else { return false }
        savedVouchers.insert(normalized, at: 0)
        defaults.set(savedVouchers, forKey: Keys.vouchers)
        let credit = PaymentTransaction(
            id: UUID().uuidString,
            date: Date(),
            kind: .promoCredit,
            tripId: nil,
            tripLabel: "Promo · \(normalized)",
            amountLocal: 0,
            amountUSD: 0,
            currency: .usd,
            method: .wallet,
            status: .successful,
            refundNote: nil,
            receiptId: nil
        )
        prepend(credit)
        return true
    }

    func removeVoucher(_ code: String) {
        savedVouchers.removeAll { $0 == code }
        defaults.set(savedVouchers, forKey: Keys.vouchers)
    }

    func saveBusinessProfile() {
        defaults.set(businessProfileEnabled, forKey: Keys.businessEnabled)
        defaults.set(businessName, forKey: Keys.businessName)
        defaults.set(businessEmail, forKey: Keys.businessEmail)
    }

    func linkMobileMoney(_ method: PaymentMethod, phone: String) {
        let digits = phone.filter(\.isNumber)
        switch method {
        case .mpesa:
            mpesaPhone = digits
            defaults.set(digits, forKey: Keys.mpesaPhone)
        case .airtelMoney:
            airtelPhone = digits
            defaults.set(digits, forKey: Keys.airtelPhone)
        case .orangeMoney:
            orangePhone = digits
            defaults.set(digits, forKey: Keys.orangePhone)
        default:
            break
        }
        select(method)
    }

    func unlinkMobileMoney(_ method: PaymentMethod) {
        switch method {
        case .mpesa:
            mpesaPhone = ""
            defaults.removeObject(forKey: Keys.mpesaPhone)
        case .airtelMoney:
            airtelPhone = ""
            defaults.removeObject(forKey: Keys.airtelPhone)
        case .orangeMoney:
            orangePhone = ""
            defaults.removeObject(forKey: Keys.orangePhone)
        default:
            break
        }
        if selectedMethod == method {
            select(.cash)
        }
    }

    func linkedPhone(for method: PaymentMethod) -> String? {
        let value: String
        switch method {
        case .mpesa: value = mpesaPhone
        case .airtelMoney: value = airtelPhone
        case .orangeMoney: value = orangePhone
        default: return nil
        }
        return value.isEmpty ? nil : value
    }

    func methodSubtitle(_ method: PaymentMethod) -> String {
        switch method {
        case .cash:
            return "Pay the driver directly"
        case .wallet:
            return "Use your Vuum balance"
        case .mpesa, .airtelMoney, .orangeMoney:
            if let phone = linkedPhone(for: method), phone.count >= 2 {
                return "••••\(phone.suffix(2))"
            }
            return "Tap to link number"
        case .card:
            return cardLast4 != nil ? cardDisplayLabel : "Visa, Mastercard"
        case .companyWallet:
            return "Bill to your company"
        }
    }

    // MARK: - Wallet

    func walletBalanceLabel(for market: AppLocale.Market) -> String {
        switch market {
        case .kenya:
            return "KSh \(walletBalanceKSh.formatted())"
        case .drc:
            return "CDF \(walletBalanceCDF.formatted()) · $\(String(format: "%.2f", walletBalanceUSD))"
        case .both:
            return "KSh \(walletBalanceKSh.formatted()) · CDF \(walletBalanceCDF.formatted())"
        }
    }

    @discardableResult
    func addFunds(
        amountLocal: Int,
        currency: PaymentCurrency,
        fundingMethod: PaymentMethod
    ) -> Bool {
        guard amountLocal > 0 || (currency == .usd && amountLocal > 0) else { return false }
        switch currency {
        case .ksh:
            guard amountLocal >= 100 else { return false }
            walletBalanceKSh += amountLocal
        case .cdf:
            guard amountLocal >= 1_000 else { return false }
            walletBalanceCDF += amountLocal
        case .usd:
            let usd = Double(amountLocal)
            guard usd >= 1 else { return false }
            walletBalanceUSD += usd
        }
        persistWalletBalances()
        let tx = PaymentTransaction(
            id: UUID().uuidString,
            date: Date(),
            kind: .walletTopUp,
            tripId: nil,
            tripLabel: "Wallet top-up",
            amountLocal: currency == .usd ? Int(Double(amountLocal).rounded()) : amountLocal,
            amountUSD: currency == .usd ? Double(amountLocal) : AppLocale.usdFromLocal(amountLocal, market: currency == .ksh ? .kenya : .drc),
            currency: currency,
            method: fundingMethod,
            status: .successful,
            refundNote: nil,
            receiptId: nil
        )
        prepend(tx)
        return true
    }

    func hasWalletFunds(currency: PaymentCurrency, local: Int, usd: Double) -> Bool {
        switch currency {
        case .ksh: return walletBalanceKSh >= local
        case .cdf: return walletBalanceCDF >= local
        case .usd: return walletBalanceUSD + 0.001 >= usd
        }
    }

    // MARK: - Trip charge

    /// Records a trip fare through the local payment gateway and updates wallet when needed.
    @discardableResult
    func recordTripPayment(
        tripId: String,
        tripLabel: String,
        fareLocal: Int,
        fareUSD: Double,
        market: AppLocale.Market,
        method: PaymentMethod,
        receiptId: String?
    ) async -> PaymentTransaction {
        lastChargeMessage = nil
        let currency: PaymentCurrency
        switch market {
        case .kenya: currency = .ksh
        case .drc, .both: currency = .cdf
        }

        var pending = PaymentTransaction(
            id: UUID().uuidString,
            date: Date(),
            kind: .tripCharge,
            tripId: tripId,
            tripLabel: tripLabel,
            amountLocal: fareLocal,
            amountUSD: fareUSD,
            currency: currency,
            method: method,
            status: .processing,
            refundNote: nil,
            receiptId: receiptId
        )
        prepend(pending)

        let request = PaymentChargeRequest(
            tripId: tripId,
            tripLabel: tripLabel,
            amountLocal: fareLocal,
            amountUSD: fareUSD,
            currency: currency,
            method: method,
            receiptId: receiptId,
            payerPhone: linkedPhone(for: method),
            cardLast4: cardLast4
        )
        let result = await gateway.charge(request)
        pending.status = result.status
        lastChargeMessage = result.message

        if result.status == .successful {
            if method == .wallet {
                debitWallet(currency: currency, local: fareLocal, usd: fareUSD)
            }
        }

        if let idx = transactions.firstIndex(where: { $0.id == pending.id }) {
            transactions[idx] = pending
            persistTransactions()
        }
        return pending
    }

    func markRefunded(transactionId: String, partial: Bool = false, note: String? = nil) {
        guard let idx = transactions.firstIndex(where: { $0.id == transactionId }) else { return }
        var tx = transactions[idx]
        tx.status = partial ? .partiallyRefunded : .refunded
        tx.refundNote = note ?? (partial ? "Partial refund issued" : "Refund issued")
        transactions[idx] = tx
        persistTransactions()
    }

    // MARK: - Persistence helpers

    private func debitWallet(currency: PaymentCurrency, local: Int, usd: Double) {
        switch currency {
        case .ksh: walletBalanceKSh = max(0, walletBalanceKSh - local)
        case .cdf: walletBalanceCDF = max(0, walletBalanceCDF - local)
        case .usd: walletBalanceUSD = max(0, walletBalanceUSD - usd)
        }
        persistWalletBalances()
    }

    private func persistWalletBalances() {
        defaults.set(walletBalanceKSh, forKey: Keys.walletKSh)
        defaults.set(walletBalanceCDF, forKey: Keys.walletCDF)
        defaults.set(walletBalanceUSD, forKey: Keys.walletUSD)
    }

    private func prepend(_ tx: PaymentTransaction) {
        transactions.insert(tx, at: 0)
        if transactions.count > 80 {
            transactions = Array(transactions.prefix(80))
        }
        persistTransactions()
    }

    private func persistTransactions() {
        guard let data = try? JSONEncoder().encode(transactions) else { return }
        defaults.set(data, forKey: Keys.transactions)
    }

    private static func loadTransactions(from defaults: UserDefaults) -> [PaymentTransaction] {
        guard let data = defaults.data(forKey: Keys.transactions),
              let decoded = try? JSONDecoder().decode([PaymentTransaction].self, from: data)
        else { return [] }
        return decoded
    }

    private static func sampleLedger() -> [PaymentTransaction] {
        let cal = Calendar.current
        let now = Date()
        return [
            PaymentTransaction(
                id: "seed-1",
                date: cal.date(byAdding: .day, value: -2, to: now) ?? now,
                kind: .tripCharge,
                tripId: "seed-trip-1",
                tripLabel: "Gombe → Airport",
                amountLocal: 28_500,
                amountUSD: 10.20,
                currency: .cdf,
                method: .airtelMoney,
                status: .successful,
                refundNote: nil,
                receiptId: nil
            ),
            PaymentTransaction(
                id: "seed-2",
                date: cal.date(byAdding: .day, value: -5, to: now) ?? now,
                kind: .walletTopUp,
                tripId: nil,
                tripLabel: "Wallet top-up",
                amountLocal: 50_000,
                amountUSD: 18.00,
                currency: .cdf,
                method: .card,
                status: .successful,
                refundNote: nil,
                receiptId: nil
            ),
            PaymentTransaction(
                id: "seed-3",
                date: cal.date(byAdding: .day, value: -8, to: now) ?? now,
                kind: .tripCharge,
                tripId: "seed-trip-2",
                tripLabel: "Westlands → CBD",
                amountLocal: 650,
                amountUSD: 5.00,
                currency: .ksh,
                method: .mpesa,
                status: .successful,
                refundNote: nil,
                receiptId: nil
            ),
            PaymentTransaction(
                id: "seed-4",
                date: cal.date(byAdding: .day, value: -12, to: now) ?? now,
                kind: .tripCharge,
                tripId: "seed-trip-3",
                tripLabel: "Kolwezi centre → Mine gate",
                amountLocal: 42_000,
                amountUSD: 15.00,
                currency: .cdf,
                method: .cash,
                status: .refunded,
                refundNote: "Trip cancelled after payment",
                receiptId: nil
            ),
        ]
    }
}
