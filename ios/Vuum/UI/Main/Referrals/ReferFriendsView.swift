import SwiftUI
import UIKit

// MARK: - Referral invite lifecycle (maps to anti-fraud chain)

/// Anti-fraud pipeline — rewards only after a paid first ride, not on screen open.
enum ReferralLifecycle: String, Codable, CaseIterable {
    case invited
    case registered
    case verified
    case activated
    case firstRideCompleted
    case paymentSuccessful
    case commissionEligible

    var title: String {
        switch self {
        case .invited: return "Invite sent"
        case .registered: return "Registered"
        case .verified: return "Verified"
        case .activated: return "Activated"
        case .firstRideCompleted: return "First ride completed"
        case .paymentSuccessful: return "Payment successful"
        case .commissionEligible: return "Reward earned"
        }
    }

    var systemImage: String {
        switch self {
        case .invited: return "paperplane.fill"
        case .registered: return "person.badge.plus"
        case .verified: return "checkmark.shield.fill"
        case .activated: return "bolt.fill"
        case .firstRideCompleted: return "car.fill"
        case .paymentSuccessful: return "banknote.fill"
        case .commissionEligible: return "checkmark.seal.fill"
        }
    }

    var next: ReferralLifecycle? {
        switch self {
        case .invited: return .registered
        case .registered: return .verified
        case .verified: return .activated
        case .activated: return .firstRideCompleted
        case .firstRideCompleted: return .paymentSuccessful
        case .paymentSuccessful: return .commissionEligible
        case .commissionEligible: return nil
        }
    }

    var advanceActionTitle: String? {
        switch self {
        case .invited: return "Friend registered"
        case .registered: return "Mark verified"
        case .verified: return "Mark activated"
        case .activated: return nil // First paid ride comes from trip completion / FieldSalesStore
        case .firstRideCompleted: return "Payment confirmed"
        case .paymentSuccessful: return "Release reward"
        case .commissionEligible: return nil
        }
    }

    var isRewardEarned: Bool { self == .commissionEligible }

    var asEligibilityMilestone: EligibilityMilestone? {
        switch self {
        case .invited: return nil
        case .registered: return .registered
        case .verified: return .verified
        case .activated: return .activated
        case .firstRideCompleted: return .firstRideCompleted
        case .paymentSuccessful: return .paymentSuccessful
        case .commissionEligible: return .commissionEligible
        }
    }
}

struct ReferralInvite: Identifiable, Codable, Equatable {
    let id: UUID
    var displayName: String
    var lifecycle: ReferralLifecycle
    var rewardCDF: Int
    var createdAt: Date
    var completedAt: Date?
    var source: RecruitmentSource
    var salesExecutiveId: String?

    var statusTitle: String { lifecycle.title }
    var systemImage: String { lifecycle.systemImage }
}

/// Local invite code + first-ride reward tracking (client-side; no backend).
@MainActor
final class ReferralStore: ObservableObject {
    private enum Keys {
        static let inviteCode = "vuum.referral.inviteCode"
        static let invitesJSON = "vuum.referral.invites"
        static let creditCDF = "vuum.referral.creditCDF"
    }

    static let rewardCDF = 5_000
    static let rewardUSD = 2.00

    @Published private(set) var inviteCode: String
    @Published private(set) var invites: [ReferralInvite]
    @Published private(set) var walletCreditCDF: Int

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let existing = defaults.string(forKey: Keys.inviteCode), !existing.isEmpty {
            inviteCode = existing
        } else {
            let generated = Self.makeInviteCode()
            defaults.set(generated, forKey: Keys.inviteCode)
            inviteCode = generated
        }

        walletCreditCDF = defaults.integer(forKey: Keys.creditCDF)

        if let data = defaults.data(forKey: Keys.invitesJSON),
           let decoded = try? JSONDecoder().decode([ReferralInvite].self, from: data) {
            invites = decoded
        } else {
            invites = Self.seedInvites()
            walletCreditCDF = invites.filter(\.lifecycle.isRewardEarned).reduce(0) { $0 + $1.rewardCDF }
            defaults.set(walletCreditCDF, forKey: Keys.creditCDF)
            persistInvites()
        }
    }

    var shareMessage: String {
        """
        Ride with Vuum! Use my invite code \(inviteCode) when you sign up. \
        After your first completed ride is paid, we both earn a reward.
        """
    }

    var earnedRewardCount: Int {
        invites.filter(\.lifecycle.isRewardEarned).count
    }

    var totalEarnedCDF: Int {
        invites.filter(\.lifecycle.isRewardEarned).reduce(0) { $0 + $1.rewardCDF }
    }

    var pendingCount: Int {
        invites.filter { !$0.lifecycle.isRewardEarned }.count
    }

    /// Advances one anti-fraud step. Reward credit only lands on `commissionEligible`.
    func advanceLifecycle(id: UUID) {
        guard let index = invites.firstIndex(where: { $0.id == id }) else { return }
        guard let next = invites[index].lifecycle.next else { return }
        // Do not skip from activated → first ride via UI alone.
        if invites[index].lifecycle == .activated { return }
        let previous = invites[index].lifecycle
        invites[index].lifecycle = next
        if next == .commissionEligible, previous != .commissionEligible {
            invites[index].completedAt = Date()
            walletCreditCDF += invites[index].rewardCDF
            defaults.set(walletCreditCDF, forKey: Keys.creditCDF)
        }
        persistInvites()
    }

    /// Called when FieldSalesStore confirms a genuine paid first ride for a matching recruit name.
    func markPaidFirstRide(displayName: String) {
        guard let index = invites.firstIndex(where: {
            $0.displayName.caseInsensitiveCompare(displayName) == .orderedSame
                && $0.lifecycle == .activated
        }) else { return }
        invites[index].lifecycle = .firstRideCompleted
        persistInvites()
        advanceLifecycle(id: invites[index].id) // → paymentSuccessful
        advanceLifecycle(id: invites[index].id) // → commissionEligible
    }

    func addInvite(displayName: String, source: RecruitmentSource = .referralCode) {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let invite = ReferralInvite(
            id: UUID(),
            displayName: trimmed,
            lifecycle: .invited,
            rewardCDF: Self.rewardCDF,
            createdAt: Date(),
            completedAt: nil,
            source: source,
            salesExecutiveId: source == .fieldSales ? "fs-lushi-01" : nil
        )
        invites.insert(invite, at: 0)
        persistInvites()
    }

    private func persistInvites() {
        if let data = try? JSONEncoder().encode(invites) {
            defaults.set(data, forKey: Keys.invitesJSON)
        }
    }

    private static func makeInviteCode() -> String {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        let suffix = (0..<6).map { _ in alphabet.randomElement()! }
        return "VUUM" + String(suffix)
    }

    private static func seedInvites() -> [ReferralInvite] {
        let calendar = Calendar.current
        let now = Date()
        return [
            ReferralInvite(
                id: UUID(),
                displayName: "Grace K.",
                lifecycle: .commissionEligible,
                rewardCDF: rewardCDF,
                createdAt: calendar.date(byAdding: .day, value: -12, to: now) ?? now,
                completedAt: calendar.date(byAdding: .day, value: -8, to: now),
                source: .referralCode,
                salesExecutiveId: nil
            ),
            ReferralInvite(
                id: UUID(),
                displayName: "Jean-Paul M.",
                lifecycle: .activated,
                rewardCDF: rewardCDF,
                createdAt: calendar.date(byAdding: .day, value: -3, to: now) ?? now,
                completedAt: nil,
                source: .fieldSales,
                salesExecutiveId: "fs-lushi-01"
            ),
            ReferralInvite(
                id: UUID(),
                displayName: "Amina T.",
                lifecycle: .invited,
                rewardCDF: rewardCDF,
                createdAt: calendar.date(byAdding: .day, value: -1, to: now) ?? now,
                completedAt: nil,
                source: .referralCode,
                salesExecutiveId: nil
            ),
        ]
    }
}

struct ReferFriendsView: View {
    @StateObject private var store = ReferralStore()
    @EnvironmentObject private var fieldSales: FieldSalesStore
    @State private var newFriendName = ""
    @State private var codeCopied = false

    var body: some View {
        listContent
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(VuumColor.groupedBackground.ignoresSafeArea())
            .listRowSeparatorTint(VuumColor.divider)
            .tint(VuumColor.brand)
            .navigationTitle("Refer friends")
            .navigationBarTitleDisplayMode(.inline)
    }

    private var listContent: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Share your code")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(VuumColor.secondaryText)
                    HStack {
                        Text(store.inviteCode)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .tracking(1.5)
                            .textSelection(.enabled)
                        Spacer()
                        Button {
                            UIPasteboard.general.string = store.inviteCode
                            codeCopied = true
                        } label: {
                            Image(systemName: codeCopied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(VuumColor.brand)
                                .frame(width: 40, height: 40)
                                .background(VuumColor.brand.opacity(0.2), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(codeCopied ? "Copied" : "Copy invite code")
                    }
                    Text("Friends enter this code when they create an account. Rewards unlock only after their first completed, paid ride.")
                        .font(.system(size: 13))
                        .foregroundStyle(VuumColor.secondaryText)
                }
                .padding(.vertical, 4)

                ShareLink(item: store.shareMessage) {
                    Label("Share invite", systemImage: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(VuumColor.brand)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
            }

            if let attr = fieldSales.riderAttribution {
                Section("Your attribution") {
                    LabeledContent("Source", value: attr.source.title)
                    if let code = attr.referralCode {
                        LabeledContent("Code", value: code)
                    }
                    if let exec = fieldSales.executive(for: attr.salesExecutiveId) {
                        LabeledContent("Sales partner", value: "\(exec.displayName) · \(exec.salesCode)")
                    }
                    Text(attr.highestMilestone.title)
                        .font(.footnote)
                        .foregroundStyle(VuumColor.secondaryText)
                }
            }

            Section("Credits & rewards") {
                LabeledContent("Reward per friend", value: "CDF \(ReferralStore.rewardCDF.formatted())")
                LabeledContent("Approx. USD", value: String(format: "$%.2f", ReferralStore.rewardUSD))
                LabeledContent("Wallet credit", value: "CDF \(store.walletCreditCDF.formatted())")
                LabeledContent("Rewards earned", value: "\(store.earnedRewardCount)")
                LabeledContent("Pending invites", value: "\(store.pendingCount)")
                Text("Eligible ride: first genuine completed trip with successful payment. Opening this screen does not grant credit.")
                    .font(.footnote)
                    .foregroundStyle(VuumColor.secondaryText)
            }

            Section("Your invites") {
                if store.invites.isEmpty {
                    Text("No invites yet. Share your code to get started.")
                        .foregroundStyle(VuumColor.secondaryText)
                } else {
                    ForEach(store.invites) { invite in
                        inviteRow(invite)
                    }
                }
            }

            Section("Add a friend") {
                TextField("Friend’s name", text: $newFriendName)
                    .textInputAutocapitalization(.words)
                Button("Track invite") {
                    let name = newFriendName
                    store.addInvite(displayName: name)
                    fieldSales.addRecruitment(
                        displayName: name,
                        kind: .rider,
                        source: .referralCode,
                        referralCode: store.inviteCode
                    )
                    newFriendName = ""
                }
                .disabled(newFriendName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onChange(of: codeCopied) { _, copied in
            guard copied else { return }
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                codeCopied = false
            }
        }
        .onChange(of: fieldSales.recruitments) { _, recruitments in
            for item in recruitments where item.commissionState == .awarded {
                store.markPaidFirstRide(displayName: item.displayName)
            }
        }
    }

    @ViewBuilder
    private func inviteRow(_ invite: ReferralInvite) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: invite.systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(invite.lifecycle.isRewardEarned ? Color.green : VuumColor.brand)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 4) {
                    Text(invite.displayName)
                        .font(.system(size: 16, weight: .semibold))
                    Text(invite.statusTitle)
                        .font(.system(size: 13))
                        .foregroundStyle(VuumColor.secondaryText)
                    Text(invite.source.title)
                        .font(.system(size: 12))
                        .foregroundStyle(VuumColor.secondaryText)
                    if let salesId = invite.salesExecutiveId {
                        Text("Sales · \(salesId)")
                            .font(.system(size: 11))
                            .foregroundStyle(VuumColor.secondaryText)
                    }
                    Text(invite.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.system(size: 12))
                        .foregroundStyle(VuumColor.secondaryText)
                }
                Spacer(minLength: 0)
                if invite.lifecycle.isRewardEarned {
                    Text("CDF \(invite.rewardCDF.formatted())")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }

            if let action = invite.lifecycle.advanceActionTitle {
                Button(action) {
                    store.advanceLifecycle(id: invite.id)
                }
                .font(.system(size: 14, weight: .semibold))
                .buttonStyle(.bordered)
            } else if invite.lifecycle == .activated {
                Text("Waiting for first paid ride")
                    .font(.caption)
                    .foregroundStyle(VuumColor.secondaryText)
            }
        }
        .padding(.vertical, 4)
    }
}
