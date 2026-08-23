import SwiftUI
import UIKit

struct NotificationInboxView: View {
    @EnvironmentObject private var notifications: NotificationStore
    @EnvironmentObject private var permissions: PermissionCenter
    @Environment(\.openURL) private var openURL

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
            if !pushEnabled {
                Section {
                    permissionCard
                }
            }

            if notifications.items.isEmpty {
                Section {
                    inboxEmptyState
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(
                            top: 24,
                            leading: VuumLayout.pageInset,
                            bottom: 24,
                            trailing: VuumLayout.pageInset
                        ))
                        .listRowSeparator(.hidden)
                }
            } else {
                Section {
                    ForEach(notifications.items) { item in
                        Button {
                            notifications.markRead(item.id)
                        } label: {
                            notificationRow(item)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(
                            top: 12,
                            leading: VuumLayout.pageInset,
                            bottom: 12,
                            trailing: VuumLayout.pageInset
                        ))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                notifications.remove(item.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            if !item.isRead {
                                Button {
                                    notifications.markRead(item.id)
                                } label: {
                                    Label("Read", systemImage: "envelope.open")
                                }
                                .tint(VuumColor.accent)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(VuumColor.groupedBackground.ignoresSafeArea())
        .navigationTitle("Inbox")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if notifications.unreadCount > 0 {
                        Button("Mark all read") {
                            notifications.markAllRead()
                        }
                    }
                    Button("Clear read", role: .destructive) {
                        notifications.clearRead()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(VuumColor.primaryText)
                }
                .accessibilityLabel("Inbox actions")
            }
        }
        .task {
            await permissions.refreshStatuses()
        }
    }

    private var inboxEmptyState: some View {
        VStack(spacing: VuumLayout.stackSpacing) {
            Image(systemName: "bell")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(VuumColor.secondaryText)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 56, height: 56)

            VStack(spacing: 6) {
                Text(L10n.t("status.empty_notifications_title"))
                    .font(VuumType.titleSmall)
                    .foregroundStyle(VuumColor.primaryText)
                    .multilineTextAlignment(.center)

                Text(L10n.t("status.empty_notifications_detail"))
                    .font(VuumType.body)
                    .foregroundStyle(VuumColor.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .accessibilityElement(children: .combine)
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: VuumLayout.rowSpacing) {
            Label("Stay updated on trips", systemImage: "bell.badge")
                .font(VuumType.rowTitle)
                .foregroundStyle(VuumColor.primaryText)
                .symbolRenderingMode(.hierarchical)

            Text("Get driver arrival, trip, receipt, and safety updates on this device.")
                .font(VuumType.callout)
                .foregroundStyle(VuumColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

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
                Text(permissions.notificationAuthorization == .denied ? "Open Settings" : "Enable notifications")
                    .font(VuumType.bodySemibold)
                    .foregroundStyle(VuumColor.accentOn)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(VuumColor.brand, in: RoundedRectangle(cornerRadius: VuumLayout.radiusControl, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }

    private func notificationRow(_ item: AppNotification) -> some View {
        HStack(alignment: .top, spacing: VuumLayout.rowSpacing) {
            Image(systemName: quietSystemImage(for: item.kind))
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(item.isRead ? VuumColor.secondaryText : VuumColor.primaryText)
                .symbolRenderingMode(.hierarchical)
                .frame(width: 28, alignment: .center)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 15, weight: item.isRead ? .regular : .semibold))
                        .foregroundStyle(VuumColor.primaryText)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Spacer(minLength: 8)
                    Text(relativeTime(item.createdAt))
                        .font(VuumType.caption)
                        .foregroundStyle(VuumColor.secondaryText)
                }

                Text(item.body)
                    .font(VuumType.callout)
                    .foregroundStyle(VuumColor.secondaryText)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
            }

            if !item.isRead {
                Circle()
                    .fill(VuumColor.accent)
                    .frame(width: 7, height: 7)
                    .padding(.top, 6)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title). \(item.body)")
        .accessibilityHint(item.isRead ? "Read" : "Unread. Double tap to mark as read.")
    }

    /// Glyph-only symbols — no filled badge blobs.
    private func quietSystemImage(for kind: AppNotificationKind) -> String {
        switch kind {
        case .promo: return "tag"
        case .otp: return "lock.shield"
        case .driverAssigned, .driverReassigned: return "person"
        case .driverArriving: return "car"
        case .driverArrived: return "mappin.and.ellipse"
        case .tripStarted: return "arrow.triangle.turn.up.right.diamond"
        case .tripCompleted, .trip: return "checkmark.circle"
        case .receipt: return "doc.text"
        case .scheduledReminder, .schedule: return "calendar"
        case .paymentSucceeded, .payment: return "creditcard"
        case .paymentFailed: return "exclamationmark.triangle"
        case .cancellation: return "xmark.circle"
        case .supportResponse, .support: return "bubble.left.and.bubble.right"
        case .safetyEvent, .safety: return "shield.lefthalf.filled"
        case .recordingStarted, .recordingStopped: return "mic"
        case .incidentUpdate: return "exclamationmark.shield"
        case .system: return "bell"
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
