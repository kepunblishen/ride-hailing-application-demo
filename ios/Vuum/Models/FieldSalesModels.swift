import Foundation

/// Who sourced a rider or driver into Vuum (field-sales / growth attribution).
enum RecruitmentSource: String, Codable, CaseIterable, Identifiable {
    case organic
    case referralCode
    case fieldSales
    case corporateInvite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .organic: return "Organic"
        case .referralCode: return "Friend referral"
        case .fieldSales: return "Field sales"
        case .corporateInvite: return "Corporate invite"
        }
    }
}

enum RecruitmentKind: String, Codable, CaseIterable, Identifiable {
    case rider
    case driver

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rider: return "Rider"
        case .driver: return "Driver"
        }
    }
}

/// Commission lifecycle for a recruitment (never awarded on screen open alone).
enum CommissionState: String, Codable, CaseIterable, Identifiable {
    case pending
    case eligible
    case awarded
    case blocked
    case voided

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pending: return "Pending"
        case .eligible: return "Eligible"
        case .awarded: return "Awarded"
        case .blocked: return "Blocked"
        case .voided: return "Voided"
        }
    }
}

/// Ordered anti-fraud prerequisites before commission / referral rewards.
enum EligibilityMilestone: String, Codable, CaseIterable, Identifiable, Comparable {
    case registered
    case verified
    case activated
    case firstRideCompleted
    case paymentSuccessful
    case commissionEligible

    var id: String { rawValue }

    private var rank: Int {
        switch self {
        case .registered: return 0
        case .verified: return 1
        case .activated: return 2
        case .firstRideCompleted: return 3
        case .paymentSuccessful: return 4
        case .commissionEligible: return 5
        }
    }

    static func < (lhs: EligibilityMilestone, rhs: EligibilityMilestone) -> Bool {
        lhs.rank < rhs.rank
    }

    var title: String {
        switch self {
        case .registered: return "Registered"
        case .verified: return "Verified"
        case .activated: return "Activated"
        case .firstRideCompleted: return "First ride completed"
        case .paymentSuccessful: return "Payment successful"
        case .commissionEligible: return "Commission eligible"
        }
    }
}

struct SalesExecutive: Identifiable, Equatable, Codable, Hashable {
    let id: String
    var displayName: String
    /// Short code used on recruitment materials (e.g. FS-LU-042).
    var salesCode: String
    var regionLabel: String
}

struct RecruitmentAttribution: Identifiable, Equatable, Codable, Hashable {
    let id: String
    var kind: RecruitmentKind
    var source: RecruitmentSource
    var salesExecutiveId: String?
    var referralCode: String?
    var displayName: String
    var recruitedAt: Date
    var activatedAt: Date?
    var firstRideTripId: String?
    var firstRideCompletedAt: Date?
    var paymentConfirmedAt: Date?
    var commissionState: CommissionState
    var commissionAmountCDF: Int
    var highestMilestone: EligibilityMilestone
    var blockReason: String?

    var isCommissionSettled: Bool {
        commissionState == .awarded
    }
}

/// Internal risk signal — not shown on rider-facing trip UI.
enum SuspiciousTripReason: String, Codable, CaseIterable, Identifiable {
    case veryShortTrip
    case zeroOrTokenFare
    case unpaid
    case cancelledAfterMatch
    case rapidRepeatBooking
    case missingPaymentMethod

    var id: String { rawValue }

    var title: String {
        switch self {
        case .veryShortTrip: return "Very short trip"
        case .zeroOrTokenFare: return "Token / zero fare"
        case .unpaid: return "Payment not successful"
        case .cancelledAfterMatch: return "Cancelled after match"
        case .rapidRepeatBooking: return "Rapid repeat booking"
        case .missingPaymentMethod: return "Missing payment method"
        }
    }
}

enum SuspiciousFlagSeverity: String, Codable, CaseIterable {
    case info
    case watch
    case high
}

struct SuspiciousTripFlag: Identifiable, Equatable, Codable, Hashable {
    let id: String
    var tripId: String
    var tripLabel: String
    var reasons: [SuspiciousTripReason]
    var severity: SuspiciousFlagSeverity
    var createdAt: Date
    var notes: String?
}

/// Presenter prep items for field-sales / growth story (diagnostics only).
struct FieldSalesChecklistItem: Identifiable, Equatable, Codable, Hashable {
    let id: String
    var title: String
    var detail: String
    var isComplete: Bool
}
