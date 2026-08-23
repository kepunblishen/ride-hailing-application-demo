import Foundation

/// Charge request passed into a payment adapter (UI → provider).
struct PaymentChargeRequest: Equatable {
    var tripId: String
    var tripLabel: String
    var amountLocal: Int
    var amountUSD: Double
    var currency: PaymentCurrency
    var method: PaymentMethod
    var receiptId: String?
    var payerPhone: String?
    var cardLast4: String?
}

struct PaymentChargeResult: Equatable {
    var status: PaymentTransactionStatus
    var providerReference: String
    var message: String?
}

/// Boundary for real card / MM / corporate gateways later.
protocol PaymentProvider {
    var supportedMethods: [PaymentMethod] { get }
    func charge(_ request: PaymentChargeRequest) async -> PaymentChargeResult
}

protocol CardPaymentProvider: PaymentProvider {}
protocol MobileMoneyProvider: PaymentProvider {}
protocol CorporateBillingProvider: PaymentProvider {}

struct LocalCardPaymentProvider: CardPaymentProvider {
    var supportedMethods: [PaymentMethod] { [.card] }

    func charge(_ request: PaymentChargeRequest) async -> PaymentChargeResult {
        try? await Task.sleep(nanoseconds: 280_000_000)
        guard request.cardLast4 != nil else {
            return PaymentChargeResult(
                status: .failed,
                providerReference: "card-missing",
                message: "Add a card to pay with card."
            )
        }
        return PaymentChargeResult(
            status: .successful,
            providerReference: "card-\(UUID().uuidString.prefix(8))",
            message: nil
        )
    }
}

struct LocalMobileMoneyProvider: MobileMoneyProvider {
    var supportedMethods: [PaymentMethod] { [.mpesa, .airtelMoney, .orangeMoney] }

    func charge(_ request: PaymentChargeRequest) async -> PaymentChargeResult {
        try? await Task.sleep(nanoseconds: 320_000_000)
        guard let phone = request.payerPhone, phone.count >= 8 else {
            return PaymentChargeResult(
                status: .failed,
                providerReference: "mm-unlinked",
                message: "Link a mobile money number first."
            )
        }
        return PaymentChargeResult(
            status: .successful,
            providerReference: "mm-\(phone.suffix(4))-\(UUID().uuidString.prefix(6))",
            message: nil
        )
    }
}

struct LocalCorporateBillingProvider: CorporateBillingProvider {
    var supportedMethods: [PaymentMethod] { [.companyWallet] }

    func charge(_ request: PaymentChargeRequest) async -> PaymentChargeResult {
        try? await Task.sleep(nanoseconds: 200_000_000)
        return PaymentChargeResult(
            status: .successful,
            providerReference: "corp-\(UUID().uuidString.prefix(8))",
            message: nil
        )
    }
}

struct LocalCashPaymentProvider: PaymentProvider {
    var supportedMethods: [PaymentMethod] { [.cash] }

    func charge(_ request: PaymentChargeRequest) async -> PaymentChargeResult {
        PaymentChargeResult(
            status: .successful,
            providerReference: "cash-\(request.tripId.prefix(6))",
            message: nil
        )
    }
}

struct LocalWalletPaymentProvider: PaymentProvider {
    var supportedMethods: [PaymentMethod] { [.wallet] }
    private let hasSufficientBalance: (PaymentCurrency, Int, Double) -> Bool

    init(_ hasSufficientBalance: @escaping (PaymentCurrency, Int, Double) -> Bool) {
        self.hasSufficientBalance = hasSufficientBalance
    }

    func charge(_ request: PaymentChargeRequest) async -> PaymentChargeResult {
        try? await Task.sleep(nanoseconds: 180_000_000)
        let ok = hasSufficientBalance(request.currency, request.amountLocal, request.amountUSD)
        guard ok else {
            return PaymentChargeResult(
                status: .failed,
                providerReference: "wallet-low",
                message: "Not enough wallet balance. Add funds or choose another method."
            )
        }
        return PaymentChargeResult(
            status: .successful,
            providerReference: "wallet-\(UUID().uuidString.prefix(8))",
            message: nil
        )
    }
}

/// Routes charges to the correct local adapter; swap implementations when gateways go live.
@MainActor
final class PaymentGateway {
    private let card: CardPaymentProvider
    private let mobileMoney: MobileMoneyProvider
    private let corporate: CorporateBillingProvider
    private let cash: PaymentProvider
    private let wallet: PaymentProvider

    init(
        card: CardPaymentProvider = LocalCardPaymentProvider(),
        mobileMoney: MobileMoneyProvider = LocalMobileMoneyProvider(),
        corporate: CorporateBillingProvider = LocalCorporateBillingProvider(),
        cash: PaymentProvider = LocalCashPaymentProvider(),
        wallet: PaymentProvider
    ) {
        self.card = card
        self.mobileMoney = mobileMoney
        self.corporate = corporate
        self.cash = cash
        self.wallet = wallet
    }

    func charge(_ request: PaymentChargeRequest) async -> PaymentChargeResult {
        switch DeveloperDiagnostics.shared.paymentSimulation {
        case .forceSuccess:
            try? await Task.sleep(nanoseconds: 120_000_000)
            return PaymentChargeResult(
                status: .successful,
                providerReference: "diag-ok-\(UUID().uuidString.prefix(6))",
                message: nil
            )
        case .forceFailure:
            try? await Task.sleep(nanoseconds: 120_000_000)
            return PaymentChargeResult(
                status: .failed,
                providerReference: "diag-fail",
                message: "Payment could not be completed. Try another method."
            )
        case .automatic:
            break
        }

        let provider: PaymentProvider
        switch request.method {
        case .card: provider = card
        case .mpesa, .airtelMoney, .orangeMoney: provider = mobileMoney
        case .companyWallet: provider = corporate
        case .cash: provider = cash
        case .wallet: provider = wallet
        }
        return await provider.charge(request)
    }
}
