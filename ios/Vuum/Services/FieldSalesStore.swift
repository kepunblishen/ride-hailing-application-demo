import Combine
import Foundation

/// Local field-sales attribution, anti-fraud eligibility, and internal suspicious-trip flags.
/// Designed so a future backend can replace persistence without rewriting rider UI.
@MainActor
final class FieldSalesStore: ObservableObject {
    private enum Keys {
        static let recruitments = "vuum.fieldSales.recruitments"
        static let suspicious = "vuum.fieldSales.suspiciousFlags"
        static let checklist = "vuum.fieldSales.checklist"
        static let riderAttribution = "vuum.fieldSales.riderAttribution"
    }

    static let defaultCommissionCDF = 8_000
    static let minGenuineFareCDF = 1_500
    static let minGenuineDurationMinutes = 3

    @Published private(set) var salesExecutives: [SalesExecutive]
    @Published private(set) var recruitments: [RecruitmentAttribution]
    @Published private(set) var suspiciousFlags: [SuspiciousTripFlag]
    @Published private(set) var checklist: [FieldSalesChecklistItem]
    /// Attribution for the signed-in rider (who recruited them), if any.
    @Published private(set) var riderAttribution: RecruitmentAttribution?

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        salesExecutives = Self.seedExecutives()

        if let data = defaults.data(forKey: Keys.recruitments),
           let decoded = try? JSONDecoder().decode([RecruitmentAttribution].self, from: data) {
            recruitments = decoded
        } else {
            recruitments = Self.seedRecruitments()
            persistRecruitments()
        }

        if let data = defaults.data(forKey: Keys.suspicious),
           let decoded = try? JSONDecoder().decode([SuspiciousTripFlag].self, from: data) {
            suspiciousFlags = decoded
        } else {
            suspiciousFlags = []
        }

        if let data = defaults.data(forKey: Keys.checklist),
           let decoded = try? JSONDecoder().decode([FieldSalesChecklistItem].self, from: data) {
            checklist = decoded
        } else {
            checklist = Self.defaultChecklist()
            persistChecklist()
        }

        if let data = defaults.data(forKey: Keys.riderAttribution),
           let decoded = try? JSONDecoder().decode(RecruitmentAttribution.self, from: data) {
            riderAttribution = decoded
        } else {
            riderAttribution = Self.seedRiderAttribution()
            persistRiderAttribution()
        }
    }

    var pendingCommissionCount: Int {
        recruitments.filter { $0.commissionState == .pending || $0.commissionState == .eligible }.count
    }

    var awardedCommissionCDF: Int {
        recruitments.filter { $0.commissionState == .awarded }.reduce(0) { $0 + $1.commissionAmountCDF }
    }

    var checklistProgress: (done: Int, total: Int) {
        (checklist.filter(\.isComplete).count, checklist.count)
    }

    // MARK: - Eligibility (anti-fraud)

    /// Advances a recruitment only when prerequisites are met. Does not award on UI open.
    @discardableResult
    func advanceEligibility(
        recruitmentId: String,
        to milestone: EligibilityMilestone,
        tripId: String? = nil,
        paymentSucceeded: Bool = false,
        blockReason: String? = nil
    ) -> RecruitmentAttribution? {
        guard let index = recruitments.firstIndex(where: { $0.id == recruitmentId }) else { return nil }
        var item = recruitments[index]

        if item.commissionState == .blocked || item.commissionState == .voided {
            return item
        }

        if let blockReason {
            item.commissionState = .blocked
            item.blockReason = blockReason
            item.highestMilestone = max(item.highestMilestone, milestone)
            recruitments[index] = item
            persistRecruitments()
            return item
        }

        guard milestone >= item.highestMilestone || milestone == .commissionEligible else {
            return item
        }

        // Enforce chain order.
        switch milestone {
        case .registered:
            item.highestMilestone = .registered
        case .verified:
            guard item.highestMilestone >= .registered else { return item }
            item.highestMilestone = .verified
        case .activated:
            guard item.highestMilestone >= .verified else { return item }
            item.highestMilestone = .activated
            item.activatedAt = item.activatedAt ?? Date()
        case .firstRideCompleted:
            guard item.highestMilestone >= .activated else { return item }
            item.highestMilestone = .firstRideCompleted
            item.firstRideCompletedAt = Date()
            item.firstRideTripId = tripId
        case .paymentSuccessful:
            guard item.highestMilestone >= .firstRideCompleted, paymentSucceeded else { return item }
            item.highestMilestone = .paymentSuccessful
            item.paymentConfirmedAt = Date()
        case .commissionEligible:
            guard item.highestMilestone >= .paymentSuccessful else { return item }
            item.highestMilestone = .commissionEligible
            item.commissionState = .eligible
        }

        recruitments[index] = item
        persistRecruitments()
        syncRiderAttributionIfNeeded(item)
        return item
    }

    /// Awards commission only when chain reached `commissionEligible`.
    @discardableResult
    func awardCommissionIfEligible(recruitmentId: String) -> Bool {
        guard let index = recruitments.firstIndex(where: { $0.id == recruitmentId }) else { return false }
        var item = recruitments[index]
        guard item.highestMilestone >= .commissionEligible,
              item.commissionState == .eligible || item.commissionState == .pending
        else { return false }
        item.commissionState = .awarded
        recruitments[index] = item
        persistRecruitments()
        syncRiderAttributionIfNeeded(item)
        return true
    }

    /// Called after a genuine completed + paid trip. Updates recruitments and rider self-attribution.
    func evaluateAfterCompletedTrip(
        tripId: String,
        tripLabel: String,
        fareCDF: Int,
        durationMinutes: Int?,
        paymentSucceeded: Bool,
        paymentMethodPresent: Bool
    ) {
        var reasons: [SuspiciousTripReason] = []
        if fareCDF < Self.minGenuineFareCDF { reasons.append(.zeroOrTokenFare) }
        if let durationMinutes, durationMinutes < Self.minGenuineDurationMinutes {
            reasons.append(.veryShortTrip)
        }
        if !paymentSucceeded { reasons.append(.unpaid) }
        if !paymentMethodPresent { reasons.append(.missingPaymentMethod) }

        let recent = suspiciousFlags.filter { $0.createdAt.timeIntervalSinceNow > -600 }
        if recent.count >= 2 { reasons.append(.rapidRepeatBooking) }

        if !reasons.isEmpty {
            let severity: SuspiciousFlagSeverity =
                reasons.contains(.unpaid) || reasons.contains(.zeroOrTokenFare) ? .high : .watch
            let flag = SuspiciousTripFlag(
                id: UUID().uuidString,
                tripId: tripId,
                tripLabel: tripLabel,
                reasons: reasons,
                severity: severity,
                createdAt: Date(),
                notes: nil
            )
            suspiciousFlags.insert(flag, at: 0)
            persistSuspicious()
        }

        let genuine = paymentSucceeded
            && fareCDF >= Self.minGenuineFareCDF
            && (durationMinutes == nil || durationMinutes! >= Self.minGenuineDurationMinutes)

        // Advance pending rider recruitments that are waiting on first ride.
        for recruitment in recruitments where recruitment.kind == .rider
            && recruitment.commissionState != .awarded
            && recruitment.commissionState != .blocked
            && recruitment.commissionState != .voided
            && recruitment.highestMilestone >= .activated
            && recruitment.highestMilestone < .commissionEligible
        {
            if !genuine {
                _ = advanceEligibility(
                    recruitmentId: recruitment.id,
                    to: .firstRideCompleted,
                    tripId: tripId,
                    blockReason: reasons.map(\.title).joined(separator: ", ")
                )
                continue
            }
            _ = advanceEligibility(
                recruitmentId: recruitment.id,
                to: .firstRideCompleted,
                tripId: tripId
            )
            _ = advanceEligibility(
                recruitmentId: recruitment.id,
                to: .paymentSuccessful,
                tripId: tripId,
                paymentSucceeded: true
            )
            _ = advanceEligibility(recruitmentId: recruitment.id, to: .commissionEligible)
            _ = awardCommissionIfEligible(recruitmentId: recruitment.id)
        }

        if var selfAttr = riderAttribution, genuine {
            if selfAttr.highestMilestone < .firstRideCompleted {
                selfAttr.highestMilestone = .firstRideCompleted
                selfAttr.firstRideTripId = tripId
                selfAttr.firstRideCompletedAt = Date()
            }
            if paymentSucceeded, selfAttr.highestMilestone < .paymentSuccessful {
                selfAttr.highestMilestone = .paymentSuccessful
                selfAttr.paymentConfirmedAt = Date()
            }
            if selfAttr.highestMilestone >= .paymentSuccessful {
                selfAttr.highestMilestone = .commissionEligible
                if selfAttr.commissionState == .pending {
                    selfAttr.commissionState = .eligible
                }
            }
            riderAttribution = selfAttr
            persistRiderAttribution()
        } else if var selfAttr = riderAttribution, !genuine, !reasons.isEmpty {
            selfAttr.commissionState = .blocked
            selfAttr.blockReason = reasons.map(\.title).joined(separator: ", ")
            riderAttribution = selfAttr
            persistRiderAttribution()
        }
    }

    func flagCancelledAfterMatch(tripId: String, tripLabel: String) {
        let flag = SuspiciousTripFlag(
            id: UUID().uuidString,
            tripId: tripId,
            tripLabel: tripLabel,
            reasons: [.cancelledAfterMatch],
            severity: .info,
            createdAt: Date(),
            notes: nil
        )
        suspiciousFlags.insert(flag, at: 0)
        persistSuspicious()
    }

    func addRecruitment(
        displayName: String,
        kind: RecruitmentKind,
        source: RecruitmentSource,
        salesCode: String? = nil,
        referralCode: String? = nil
    ) {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let execId = salesExecutives.first(where: { $0.salesCode == salesCode })?.id
        let item = RecruitmentAttribution(
            id: UUID().uuidString,
            kind: kind,
            source: source,
            salesExecutiveId: execId,
            referralCode: referralCode,
            displayName: trimmed,
            recruitedAt: Date(),
            activatedAt: nil,
            firstRideTripId: nil,
            firstRideCompletedAt: nil,
            paymentConfirmedAt: nil,
            commissionState: .pending,
            commissionAmountCDF: Self.defaultCommissionCDF,
            highestMilestone: .registered,
            blockReason: nil
        )
        recruitments.insert(item, at: 0)
        persistRecruitments()
        _ = advanceEligibility(recruitmentId: item.id, to: .verified)
        _ = advanceEligibility(recruitmentId: item.id, to: .activated)
    }

    func setChecklistItem(id: String, complete: Bool) {
        guard let index = checklist.firstIndex(where: { $0.id == id }) else { return }
        checklist[index].isComplete = complete
        persistChecklist()
    }

    func resetChecklist() {
        checklist = Self.defaultChecklist()
        persistChecklist()
    }

    func clearSuspiciousFlags() {
        suspiciousFlags = []
        persistSuspicious()
    }

    func resetGrowthData() {
        recruitments = Self.seedRecruitments()
        persistRecruitments()
        riderAttribution = Self.seedRiderAttribution()
        persistRiderAttribution()
        clearSuspiciousFlags()
        resetChecklist()
    }

    func executive(for id: String?) -> SalesExecutive? {
        guard let id else { return nil }
        return salesExecutives.first { $0.id == id }
    }

    // MARK: - Persistence

    private func persistRecruitments() {
        if let data = try? JSONEncoder().encode(recruitments) {
            defaults.set(data, forKey: Keys.recruitments)
        }
    }

    private func persistSuspicious() {
        if let data = try? JSONEncoder().encode(suspiciousFlags) {
            defaults.set(data, forKey: Keys.suspicious)
        }
    }

    private func persistChecklist() {
        if let data = try? JSONEncoder().encode(checklist) {
            defaults.set(data, forKey: Keys.checklist)
        }
    }

    private func persistRiderAttribution() {
        if let riderAttribution,
           let data = try? JSONEncoder().encode(riderAttribution) {
            defaults.set(data, forKey: Keys.riderAttribution)
        }
    }

    private func syncRiderAttributionIfNeeded(_ item: RecruitmentAttribution) {
        guard riderAttribution?.id == item.id else { return }
        riderAttribution = item
        persistRiderAttribution()
    }

    // MARK: - Seeds

    private static func seedExecutives() -> [SalesExecutive] {
        [
            SalesExecutive(
                id: "fs-lushi-01",
                displayName: "Patrick M.",
                salesCode: "FS-LU-042",
                regionLabel: "Lubumbashi"
            ),
            SalesExecutive(
                id: "fs-kolwezi-01",
                displayName: "Grace N.",
                salesCode: "FS-KW-018",
                regionLabel: "Kolwezi"
            ),
        ]
    }

    private static func seedRiderAttribution() -> RecruitmentAttribution {
        RecruitmentAttribution(
            id: "self-attr-seed",
            kind: .rider,
            source: .fieldSales,
            salesExecutiveId: "fs-lushi-01",
            referralCode: "FS-LU-042",
            displayName: "You",
            recruitedAt: Calendar.current.date(byAdding: .day, value: -14, to: Date()) ?? Date(),
            activatedAt: Calendar.current.date(byAdding: .day, value: -13, to: Date()),
            firstRideTripId: nil,
            firstRideCompletedAt: nil,
            paymentConfirmedAt: nil,
            commissionState: .pending,
            commissionAmountCDF: defaultCommissionCDF,
            highestMilestone: .activated,
            blockReason: nil
        )
    }

    private static func seedRecruitments() -> [RecruitmentAttribution] {
        let calendar = Calendar.current
        let now = Date()
        return [
            RecruitmentAttribution(
                id: "rec-grace",
                kind: .rider,
                source: .referralCode,
                salesExecutiveId: nil,
                referralCode: "VUUMFRIEND",
                displayName: "Grace K.",
                recruitedAt: calendar.date(byAdding: .day, value: -12, to: now) ?? now,
                activatedAt: calendar.date(byAdding: .day, value: -11, to: now),
                firstRideTripId: "seed-trip-1",
                firstRideCompletedAt: calendar.date(byAdding: .day, value: -8, to: now),
                paymentConfirmedAt: calendar.date(byAdding: .day, value: -8, to: now),
                commissionState: .awarded,
                commissionAmountCDF: defaultCommissionCDF,
                highestMilestone: .commissionEligible,
                blockReason: nil
            ),
            RecruitmentAttribution(
                id: "rec-jp",
                kind: .rider,
                source: .fieldSales,
                salesExecutiveId: "fs-lushi-01",
                referralCode: "FS-LU-042",
                displayName: "Jean-Paul M.",
                recruitedAt: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
                activatedAt: calendar.date(byAdding: .day, value: -2, to: now),
                firstRideTripId: nil,
                firstRideCompletedAt: nil,
                paymentConfirmedAt: nil,
                commissionState: .pending,
                commissionAmountCDF: defaultCommissionCDF,
                highestMilestone: .activated,
                blockReason: nil
            ),
            RecruitmentAttribution(
                id: "rec-driver-1",
                kind: .driver,
                source: .fieldSales,
                salesExecutiveId: "fs-kolwezi-01",
                referralCode: "FS-KW-018",
                displayName: "David K.",
                recruitedAt: calendar.date(byAdding: .day, value: -20, to: now) ?? now,
                activatedAt: calendar.date(byAdding: .day, value: -18, to: now),
                firstRideTripId: nil,
                firstRideCompletedAt: nil,
                paymentConfirmedAt: nil,
                commissionState: .pending,
                commissionAmountCDF: 12_000,
                highestMilestone: .activated,
                blockReason: nil
            ),
        ]
    }

    private static func defaultChecklist() -> [FieldSalesChecklistItem] {
        [
            FieldSalesChecklistItem(
                id: "chk-code",
                title: "Show sales / invite code",
                detail: "Open Refer friends and share a code tied to field sales.",
                isComplete: false
            ),
            FieldSalesChecklistItem(
                id: "chk-chain",
                title: "Explain eligibility chain",
                detail: "Registered → verified → activated → first paid ride → commission.",
                isComplete: false
            ),
            FieldSalesChecklistItem(
                id: "chk-antifraud",
                title: "Anti-fraud gate",
                detail: "Confirm rewards do not unlock from opening a screen alone.",
                isComplete: false
            ),
            FieldSalesChecklistItem(
                id: "chk-attrib",
                title: "Attribution sources",
                detail: "Field sales vs friend referral vs corporate invite.",
                isComplete: false
            ),
            FieldSalesChecklistItem(
                id: "chk-driver",
                title: "Driver recruitment path",
                detail: "Mention driver activation still waits on a genuine first trip.",
                isComplete: false
            ),
            FieldSalesChecklistItem(
                id: "chk-flags",
                title: "Suspicious trip signals",
                detail: "Internal flags for unpaid / token fare / ultra-short trips.",
                isComplete: false
            ),
        ]
    }
}
