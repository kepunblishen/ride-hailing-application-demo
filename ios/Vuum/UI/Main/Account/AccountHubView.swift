import SwiftUI

/// Uber/Bolt-style account hub for the signed-in rider.
struct AccountHubView: View {
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var preferences: AppPreferences
    @EnvironmentObject private var notifications: NotificationStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        PersonalInfoView()
                    } label: {
                        profileHeader
                    }
                }

                Section {
                    NavigationLink {
                        NotificationInboxView()
                    } label: {
                        HStack(spacing: VuumLayout.rowSpacing) {
                            accountRow(
                                L10n.Settings.inbox,
                                "tray.full.fill",
                                L10n.Settings.inboxDetail
                            )
                            if notifications.unreadCount > 0 {
                                Text("\(notifications.unreadCount)")
                                    .font(VuumType.micro)
                                    .foregroundStyle(VuumColor.accentOn)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(VuumColor.brand, in: Capsule())
                                    .accessibilityLabel("\(notifications.unreadCount) unread")
                            }
                        }
                    }
                    NavigationLink {
                        WalletSettingsView()
                    } label: {
                        accountRow(
                            L10n.Account.wallet,
                            "creditcard.fill",
                            AppLocale.currencySubtitle(
                                for: AppLocale.market(countryCode: session.countryCode)
                            )
                        )
                    }
                    NavigationLink {
                        PaymentMethodsView()
                    } label: {
                        accountRow(
                            L10n.Account.paymentMethods,
                            "banknote",
                            L10n.Account.paymentMethodsDetail
                        )
                    }
                    Button {
                        MainTabNavigation.openActivity()
                    } label: {
                        accountRow(
                            L10n.Account.tripHistory,
                            "clock.arrow.circlepath",
                            tripSession.tripHistory.isEmpty
                                ? L10n.Account.noTripsYet
                                : L10n.format("account.recent_trips_count", tripSession.tripHistory.count)
                        )
                    }
                    .buttonStyle(.plain)
                }

                Section {
                    NavigationLink {
                        SafetySettingsView()
                    } label: {
                        accountRow(L10n.Account.safety, "shield.lefthalf.filled", L10n.Account.safetyDetail)
                    }
                    NavigationLink {
                        TrustedContactsView()
                    } label: {
                        accountRow(
                            L10n.Account.trustedContacts,
                            "person.2.fill",
                            L10n.Account.trustedContactsDetail
                        )
                    }
                    NavigationLink {
                        BusinessProfileView()
                    } label: {
                        accountRow(
                            L10n.Account.businessProfile,
                            "briefcase.fill",
                            L10n.Account.businessProfileDetail
                        )
                    }
                }

                Section(L10n.Account.promosSection) {
                    NavigationLink {
                        PromoCodesView()
                    } label: {
                        accountRow(
                            L10n.Account.promosCredits,
                            "ticket.fill",
                            L10n.Account.promosCreditsDetail
                        )
                    }
                    NavigationLink {
                        LoyaltyRewardsView()
                    } label: {
                        accountRow(
                            L10n.Account.rewards,
                            "star.circle.fill",
                            L10n.Account.rewardsDetail
                        )
                    }
                    NavigationLink {
                        ReferFriendsView()
                    } label: {
                        accountRow(
                            L10n.Account.referFriends,
                            "gift.fill",
                            L10n.Account.referFriendsDetail
                        )
                    }
                }

                Section {
                    NavigationLink {
                        SettingsListView()
                    } label: {
                        accountRow(L10n.Account.settings, "gearshape.fill", L10n.Account.settingsDetail)
                    }
                    NavigationLink {
                        SupportCenterView()
                    } label: {
                        accountRow(
                            L10n.Account.helpSupport,
                            "questionmark.circle.fill",
                            L10n.Account.helpSupportDetail
                        )
                    }
                    NavigationLink {
                        AboutLegalView()
                    } label: {
                        accountRow(L10n.Account.about, "info.circle.fill", L10n.Account.aboutDetail)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        tripSession.resetToHome()
                        notifications.clearForSignedOutSession()
                        session.signOut()
                    } label: {
                        Text(L10n.Account.signOut)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(VuumColor.groupedBackground.ignoresSafeArea())
            .navigationTitle(L10n.Account.title)
        }
    }

    private var profileInitials: String {
        let first = session.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let last = session.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstLetter = first.first.map { String($0) } ?? ""
        let lastLetter = last.first.map { String($0) } ?? ""
        let fromNames = (firstLetter + lastLetter).uppercased()
        if fromNames.count == 2 {
            return fromNames
        }
        let display = session.displayName
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { !$0.isWhitespace }
        let chars = display.prefix(2).map { String($0) }.joined().uppercased()
        return chars.isEmpty ? "?" : chars
    }

    private var profileHeader: some View {
        HStack(spacing: VuumLayout.rowSpacing) {
            ZStack {
                Circle()
                    .fill(VuumColor.chipBackground)
                Circle()
                    .strokeBorder(
                        VuumColor.secondaryText.opacity(0.55),
                        style: StrokeStyle(lineWidth: 1.5, dash: [3, 3])
                    )
                Text(profileInitials)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(VuumColor.primaryText)
            }
            .frame(width: 64, height: 64)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 6) {
                Text(session.displayName)
                    .font(VuumType.titleSmall)
                    .foregroundStyle(VuumColor.primaryText)
                Text(session.maskedMobile)
                    .font(VuumType.callout)
                    .foregroundStyle(VuumColor.secondaryText)
                Text(L10n.Account.personalInfo)
                    .font(VuumType.caption)
                    .foregroundStyle(VuumColor.secondaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    private func accountRow(_ title: String, _ icon: String, _ subtitle: String) -> some View {
        HStack(spacing: VuumLayout.rowSpacing) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(VuumColor.brand)
                .frame(width: VuumLayout.iconBadge, height: VuumLayout.iconBadge)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(VuumType.rowTitle)
                    .foregroundStyle(VuumColor.primaryText)
                Text(subtitle)
                    .font(VuumType.caption)
                    .foregroundStyle(VuumColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Trip history (also reachable from Account)

struct TripHistoryLinkView: View {
    @EnvironmentObject private var tripSession: TripSession
    @EnvironmentObject private var session: SessionStore

    private var market: AppLocale.Market {
        AppLocale.market(countryCode: session.countryCode)
    }

    var body: some View {
        Group {
            if tripSession.tripHistory.isEmpty {
                VuumEmptyStateView(
                    systemImage: "clock",
                    title: L10n.Activity.emptyTitle,
                    message: L10n.Activity.emptyDetail,
                    actionTitle: L10n.t("status.empty_trips_action"),
                    action: { MainTabNavigation.openHome(beginBooking: true) }
                )
            } else {
                List(tripSession.tripHistory) { receipt in
                    NavigationLink {
                        TripReceiptDetailView(receipt: receipt, market: market)
                    } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(receipt.dropoffName)
                                .font(VuumType.rowTitle)
                                .foregroundStyle(VuumColor.primaryText)
                            Text("\(receipt.pickupName) · \(receipt.tierName)")
                                .font(VuumType.caption)
                                .foregroundStyle(VuumColor.secondaryText)
                            HStack {
                                Text(receipt.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(VuumType.caption)
                                    .foregroundStyle(VuumColor.secondaryText)
                                Spacer()
                                Text(
                                    AppLocale.formatFareTotal(
                                        cdf: receipt.fare.totalCDF,
                                        usd: receipt.fare.totalUSD,
                                        market: market
                                    )
                                )
                                .font(VuumType.captionSemibold)
                                .foregroundStyle(VuumColor.primaryText)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle(L10n.Account.tripHistory)
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Loyalty shell

struct LoyaltyRewardsView: View {
    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("1,240 points")
                        .font(VuumType.hero)
                        .foregroundStyle(VuumColor.primaryText)
                    Text("Silver member")
                        .font(VuumType.bodySemibold)
                        .foregroundStyle(VuumColor.accent)
                    ProgressView(value: 0.42)
                        .tint(VuumColor.brand)
                    Text("760 points to Gold")
                        .font(VuumType.caption)
                        .foregroundStyle(VuumColor.secondaryText)
                }
                .padding(.vertical, 6)
            }
            Section("Perks") {
                Label("Priority support on trips", systemImage: "checkmark.circle")
                Label("Occasional fare credits", systemImage: "checkmark.circle")
                Label("Birthday ride discount", systemImage: "checkmark.circle")
            }
            Section {
                Text("Points update after each completed trip. Partner mining & corporate programs can unlock higher tiers.")
                    .font(VuumType.caption)
                    .foregroundStyle(VuumColor.secondaryText)
            }
        }
        .navigationTitle(L10n.Account.rewards)
        .navigationBarTitleDisplayMode(.inline)
    }
}
