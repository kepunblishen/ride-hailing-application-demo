import XCTest
@testable import Vuum

@MainActor
final class PaymentReferralEligibilityTests: XCTestCase {
    private var paymentSuite: String!
    private var referralSuite: String!
    private var paymentDefaults: UserDefaults!
    private var referralDefaults: UserDefaults!
    private var payments: PaymentMethodStore!
    private var referrals: ReferralStore!

    override func setUp() {
        super.setUp()
        paymentSuite = "vuum.tests.pay.\(UUID().uuidString)"
        referralSuite = "vuum.tests.ref.\(UUID().uuidString)"
        paymentDefaults = UserDefaults(suiteName: paymentSuite)!
        referralDefaults = UserDefaults(suiteName: referralSuite)!
        paymentDefaults.removePersistentDomain(forName: paymentSuite)
        referralDefaults.removePersistentDomain(forName: referralSuite)
        payments = PaymentMethodStore(defaults: paymentDefaults)
        referrals = ReferralStore(defaults: referralDefaults)
    }

    override func tearDown() {
        paymentDefaults?.removePersistentDomain(forName: paymentSuite)
        referralDefaults?.removePersistentDomain(forName: referralSuite)
        payments = nil
        referrals = nil
        paymentDefaults = nil
        referralDefaults = nil
        super.tearDown()
    }

    func testMarketPaymentCatalogAndSelectionGate() {
        let kenya = payments.availableMethods(for: .kenya)
        XCTAssertTrue(kenya.contains(.mpesa))
        XCTAssertTrue(kenya.contains(.cash))
        XCTAssertFalse(kenya.contains(.orangeMoney))

        let drc = payments.availableMethods(for: .drc)
        XCTAssertTrue(drc.contains(.orangeMoney))
        XCTAssertTrue(drc.contains(.airtelMoney))
        XCTAssertFalse(drc.contains(.mpesa))

        XCTAssertFalse(payments.canSelect(.card))
        XCTAssertFalse(payments.canSelect(.mpesa))
        XCTAssertTrue(payments.canSelect(.cash))
        XCTAssertTrue(payments.canSelect(.wallet))
    }

    func testCardAndMobileMoneyLinkingUnlockSelection() {
        payments.addCard(brand: "Visa", last4: "4242", holderName: "Amina")
        XCTAssertTrue(payments.canSelect(.card))
        XCTAssertEqual(payments.selectedMethod, .card)
        XCTAssertTrue(payments.cardDisplayLabel.contains("4242"))

        payments.linkMobileMoney(.mpesa, phone: "0712345678")
        XCTAssertEqual(payments.linkedPhone(for: .mpesa), "0712345678".filter(\.isNumber))
        XCTAssertTrue(payments.canSelect(.mpesa))
        XCTAssertEqual(payments.selectedMethod, .mpesa)

        payments.unlinkMobileMoney(.mpesa)
        XCTAssertNil(payments.linkedPhone(for: .mpesa))
        XCTAssertEqual(payments.selectedMethod, .cash)
    }

    func testWalletFundsAndTopUpMinimums() {
        XCTAssertTrue(payments.hasWalletFunds(currency: .cdf, local: 1_000, usd: 0))
        XCTAssertFalse(payments.addFunds(amountLocal: 50, currency: .ksh, fundingMethod: .card))
        XCTAssertTrue(payments.addFunds(amountLocal: 500, currency: .ksh, fundingMethod: .card))
        XCTAssertGreaterThanOrEqual(payments.walletBalanceKSh, 500)

        let before = payments.walletBalanceCDF
        XCTAssertTrue(payments.addFunds(amountLocal: 2_000, currency: .cdf, fundingMethod: .airtelMoney))
        XCTAssertEqual(payments.walletBalanceCDF, before + 2_000)
    }

    func testEnsureValidSelectionFallsBackWhenMethodUnavailable() {
        payments.linkMobileMoney(.mpesa, phone: "712345678")
        XCTAssertEqual(payments.selectedMethod, .mpesa)
        payments.ensureValidSelection(for: .drc)
        XCTAssertNotEqual(payments.selectedMethod, .mpesa)
        XCTAssertTrue(payments.availableMethods(for: .drc).contains(payments.selectedMethod))
    }

    func testVoucherAddIsIdempotent() {
        XCTAssertTrue(payments.addVoucher("  vuum10 "))
        XCTAssertFalse(payments.addVoucher("VUUM10"))
        XCTAssertTrue(payments.savedVouchers.contains("VUUM10"))
    }

    func testReferralLifecycleBlocksActivatedSkipAndRewardsOnPaidRide() {
        XCTAssertFalse(referrals.inviteCode.isEmpty)
        XCTAssertTrue(referrals.inviteCode.hasPrefix("VUUM"))

        let pending = referrals.invites.first { $0.lifecycle == .invited }
        XCTAssertNotNil(pending)
        if let id = pending?.id {
            referrals.advanceLifecycle(id: id) // registered
            referrals.advanceLifecycle(id: id) // verified
            referrals.advanceLifecycle(id: id) // activated
            let activated = referrals.invites.first { $0.id == id }
            XCTAssertEqual(activated?.lifecycle, .activated)
            referrals.advanceLifecycle(id: id) // must no-op at activated
            XCTAssertEqual(referrals.invites.first { $0.id == id }?.lifecycle, .activated)
        }

        let creditBefore = referrals.walletCreditCDF
        referrals.markPaidFirstRide(displayName: "Jean-Paul M.")
        let jean = referrals.invites.first { $0.displayName == "Jean-Paul M." }
        XCTAssertEqual(jean?.lifecycle, .commissionEligible)
        XCTAssertEqual(referrals.walletCreditCDF, creditBefore + ReferralStore.rewardCDF)
        XCTAssertTrue(jean?.lifecycle.isRewardEarned == true)
    }

    func testReferralLifecycleNextChainAndEligibilityMapping() {
        XCTAssertEqual(ReferralLifecycle.invited.next, .registered)
        XCTAssertEqual(ReferralLifecycle.paymentSuccessful.next, .commissionEligible)
        XCTAssertNil(ReferralLifecycle.commissionEligible.next)
        XCTAssertEqual(ReferralLifecycle.activated.advanceActionTitle, nil)
        XCTAssertEqual(
            ReferralLifecycle.firstRideCompleted.asEligibilityMilestone,
            .firstRideCompleted
        )
        XCTAssertEqual(EligibilityMilestone.registered < EligibilityMilestone.commissionEligible, true)
    }

    func testAddInviteRequiresName() {
        let before = referrals.invites.count
        referrals.addInvite(displayName: "   ")
        XCTAssertEqual(referrals.invites.count, before)
        referrals.addInvite(displayName: "Noah K.")
        XCTAssertEqual(referrals.invites.first?.displayName, "Noah K.")
        XCTAssertEqual(referrals.invites.first?.lifecycle, .invited)
    }
}
