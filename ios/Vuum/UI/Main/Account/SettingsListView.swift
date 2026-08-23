import SwiftUI

struct SettingsListView: View {
    @EnvironmentObject private var notifications: NotificationStore

    var body: some View {
        List {
            Section(L10n.Settings.preferences) {
                NavigationLink {
                    AppPreferencesView()
                } label: {
                    settingsRow(
                        L10n.Settings.appPreferences,
                        "globe",
                        L10n.Settings.appPreferencesDetail
                    )
                }
                NavigationLink {
                    NotificationInboxView()
                } label: {
                    HStack(spacing: VuumLayout.rowSpacing) {
                        settingsRow(L10n.Settings.inbox, "tray.full.fill", L10n.Settings.inboxDetail)
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
                    CommunicationSettingsView()
                } label: {
                    settingsRow(
                        L10n.Settings.notificationSettings,
                        "bell.fill",
                        L10n.Settings.notificationSettingsDetail
                    )
                }
                NavigationLink {
                    SavedPlacesView()
                } label: {
                    settingsRow(
                        L10n.Settings.savedPlaces,
                        "mappin.and.ellipse",
                        L10n.Settings.savedPlacesDetail
                    )
                }
            }

            Section(L10n.Settings.privacyAccess) {
                NavigationLink {
                    PrivacySettingsView()
                } label: {
                    settingsRow(L10n.Account.privacy, "hand.raised.fill", L10n.Settings.privacyDetail)
                }
                NavigationLink {
                    SecuritySettingsView()
                } label: {
                    settingsRow(L10n.Settings.security, "lock.shield.fill", L10n.Settings.securityDetail)
                }
                NavigationLink {
                    AccessibilitySettingsView()
                } label: {
                    settingsRow(
                        L10n.Settings.accessibility,
                        "accessibility",
                        L10n.Settings.accessibilityDetail
                    )
                }
                NavigationLink {
                    CalendarSettingsView()
                } label: {
                    settingsRow(
                        L10n.Settings.calendar,
                        "calendar",
                        L10n.Settings.calendarDetail
                    )
                }
            }

            Section(L10n.Settings.accountSafety) {
                NavigationLink {
                    SafetySettingsView()
                } label: {
                    settingsRow(
                        L10n.Settings.safetySettings,
                        "shield.fill",
                        L10n.Settings.safetySettingsDetail
                    )
                }
                NavigationLink {
                    TrustedContactsView()
                } label: {
                    settingsRow(
                        L10n.Account.trustedContacts,
                        "person.2.fill",
                        L10n.Settings.trustedDetail
                    )
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(VuumColor.groupedBackground.ignoresSafeArea())
        .listRowSeparatorTint(VuumColor.divider)
        .tint(VuumColor.brand)
        .navigationTitle(L10n.Settings.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func settingsRow(_ title: String, _ icon: String, _ subtitle: String) -> some View {
        HStack(spacing: VuumLayout.rowSpacing) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(VuumColor.brand)
                .frame(width: 28, alignment: .center)
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
        .padding(.vertical, 2)
    }
}

struct AccessibilitySettingsView: View {
    @AppStorage("vuum.a11y.largerText") private var largerText = false
    @AppStorage("vuum.a11y.reduceMotion") private var reduceMotion = false
    @AppStorage("vuum.a11y.boldButtons") private var boldButtons = false
    @AppStorage("vuum.a11y.screenReaderHints") private var screenReaderHints = true

    var body: some View {
        List {
            Section {
                Toggle("Larger text preference", isOn: $largerText)
                Toggle("Reduce motion in maps", isOn: $reduceMotion)
                Toggle("Emphasize primary buttons", isOn: $boldButtons)
                Toggle("VoiceOver trip announcements", isOn: $screenReaderHints)
            }
            Section {
                Text("These preferences stay on this device and shape how trip screens present information.")
                    .font(.footnote)
                    .foregroundStyle(VuumColor.secondaryText)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(VuumColor.groupedBackground.ignoresSafeArea())
        .listRowSeparatorTint(VuumColor.divider)
        .tint(VuumColor.brand)
        .navigationTitle(L10n.Settings.accessibility)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct CalendarSettingsView: View {
    @AppStorage("vuum.calendar.addReservations") private var addReservations = true
    @AppStorage("vuum.calendar.remindBefore") private var remindBefore = true
    @AppStorage("vuum.calendar.shareWorkCalendar") private var shareWorkCalendar = false

    var body: some View {
        List {
            Section("Reservations") {
                Toggle("Add reserved trips to Calendar", isOn: $addReservations)
                Toggle("Remind me before pickup", isOn: $remindBefore)
            }
            Section("Work") {
                Toggle("Suggest work calendar for business trips", isOn: $shareWorkCalendar)
            }
            Section {
                Text("Calendar entries are created locally when you reserve a ride from Services.")
                    .font(.footnote)
                    .foregroundStyle(VuumColor.secondaryText)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(VuumColor.groupedBackground.ignoresSafeArea())
        .listRowSeparatorTint(VuumColor.divider)
        .tint(VuumColor.brand)
        .navigationTitle(L10n.Settings.calendar)
        .navigationBarTitleDisplayMode(.inline)
    }
}
