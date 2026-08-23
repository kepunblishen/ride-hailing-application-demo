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
                        HStack {
                            accountRow(
                                L10n.Settings.inbox,
                                "tray.full.fill",
                                L10n.Settings.inboxDetail
                            )
                            Spacer(minLength: 8)
                            if notifications.unreadCount > 0 {
                                Text("\(notifications.unreadCount)")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
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
                        session.signOut()
                    } label: {
                        Text(L10n.Account.signOut)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .navigationTitle(L10n.Account.title)
        }
    }

    private var profileHeader: some View {
        HStack(spacing: 14) {
            Circle()
                .fill(VuumColor.brand)
                .frame(width: 64, height: 64)
                .overlay(
                    Text(String(session.firstName.prefix(1)).uppercased())
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayName)
                    .font(.system(size: 20, weight: .semibold))
                Text(session.maskedMobile)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                Text(L10n.Account.personalInfo)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(VuumColor.brandInk)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(VuumColor.brand.opacity(0.25), in: Capsule())
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    private func accountRow(_ title: String, _ icon: String, _ subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(VuumColor.brandInk)
                .frame(width: 34, height: 34)
                .background(VuumColor.brand.opacity(0.22), in: RoundedRectangle(cornerRadius: 9))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
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
                ContentUnavailableView(
                    L10n.Activity.emptyTitle,
                    systemImage: "clock",
                    description: Text(L10n.Activity.emptyDetail)
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
                        .font(.system(size: 28, weight: .bold))
                    Text("Silver member")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(VuumColor.brandInk)
                    ProgressView(value: 0.42)
                        .tint(VuumColor.brand)
                    Text("760 points to Gold")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
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
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(L10n.Account.rewards)
        .navigationBarTitleDisplayMode(.inline)
    }
}
