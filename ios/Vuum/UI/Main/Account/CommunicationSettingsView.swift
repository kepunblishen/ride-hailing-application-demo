import SwiftUI
import UIKit

struct CommunicationSettingsView: View {
    @EnvironmentObject private var permissions: PermissionCenter
    @Environment(\.openURL) private var openURL
    @AppStorage("vuum.notify.tripUpdates") private var tripUpdates = true
    @AppStorage("vuum.notify.promotions") private var promotions = false
    @AppStorage("vuum.notify.receipts") private var receipts = true
    @AppStorage("vuum.notify.scheduled") private var scheduledReminders = true
    @AppStorage("vuum.notify.safety") private var safetyNotifications = true
    @AppStorage("vuum.notify.support") private var supportUpdates = true
    @AppStorage("vuum.notify.sms") private var sms = true
    @AppStorage("vuum.notify.email") private var email = false
    @AppStorage("vuum.notify.products") private var productNews = true
    @AppStorage("vuum.notify.quietHours") private var quietHours = false

    private var pushEnabled: Bool {
        switch permissions.notificationAuthorization {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    NotificationInboxView()
                } label: {
                    Label(L10n.Settings.openInbox, systemImage: "tray.full.fill")
                }
            }

            Section(L10n.Settings.devicePermission) {
                LabeledContent(
                    L10n.Settings.pushAlerts,
                    value: pushEnabled ? L10n.Settings.on : L10n.Settings.off
                )
                Button {
                    Task {
                        if permissions.notificationAuthorization == .denied {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        } else {
                            await permissions.requestNotifications()
                        }
                    }
                } label: {
                    Text(
                        permissions.notificationAuthorization == .denied
                            ? L10n.Settings.openSettings
                            : L10n.Settings.enableNotifications
                    )
                }
            }

            Section(L10n.Settings.pushSection) {
                Toggle(L10n.Settings.tripUpdates, isOn: $tripUpdates)
                Toggle(L10n.Settings.scheduledReminders, isOn: $scheduledReminders)
                Toggle(L10n.Settings.safetyNotifications, isOn: $safetyNotifications)
                Toggle(L10n.Settings.supportUpdates, isOn: $supportUpdates)
                Toggle(L10n.Settings.promotions, isOn: $promotions)
                Toggle(L10n.Settings.productNews, isOn: $productNews)
                Toggle(L10n.t("settings.receipt_alerts"), isOn: $receipts)
                Toggle(L10n.Settings.quietHours, isOn: $quietHours)
            }

            Section(L10n.Settings.messagesSection) {
                Toggle(L10n.Settings.smsAlerts, isOn: $sms)
                Toggle(L10n.Settings.emailReceipts, isOn: $email)
            }

            Section {
                Text(L10n.Settings.notifyFooter)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(L10n.Account.notifications)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await permissions.refreshStatuses()
        }
    }
}
