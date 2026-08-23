import SwiftUI
import UIKit

struct NotificationInboxView: View {
    @EnvironmentObject private var notifications: NotificationStore
    @EnvironmentObject private var permissions: PermissionCenter
    @Environment(\.openURL) private var openURL

    @State private var filter: NotificationFilterGroup = .all

    private var pushEnabled: Bool {
        switch permissions.notificationAuthorization {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    private var filteredItems: [AppNotification] {
        notifications.items.filter { filter.includes($0.kind) }
    }

    var body: some View {
        List {
            if !pushEnabled {
                Section {
                    permissionCard
                }
            }

            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(NotificationFilterGroup.allCases) { group in
                            filterChip(group)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
            }

            if filteredItems.isEmpty {
                Section {
                    VuumEmptyStateView(
                        systemImage: "bell.slash",
                        title: notifications.items.isEmpty
                            ? L10n.t("status.empty_notifications_title")
                            : "Nothing in this filter",
                        message: notifications.items.isEmpty
                            ? L10n.t("status.empty_notifications_detail")
                            : "Try another category or mark new alerts as you ride."
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            } else {
                Section {
                    ForEach(filteredItems) { item in
                        Button {
                            notifications.markRead(item.id)
                        } label: {
                            notificationRow(item)
                        }
                        .buttonStyle(.plain)
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
                                .tint(.blue)
                            }
                        }
                    }
                } header: {
                    Text("\(filteredItems.count) · \(notifications.unreadCount) unread")
                }
            }
        }
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
                }
                .accessibilityLabel("Inbox actions")
            }
        }
        .task {
            await permissions.refreshStatuses()
        }
    }

    private func filterChip(_ group: NotificationFilterGroup) -> some View {
        Button {
            filter = group
        } label: {
            Text(group.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(filter == group ? VuumColor.brandInk : VuumColor.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    filter == group ? VuumColor.brand.opacity(0.9) : VuumColor.chipBackground,
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Stay updated on trips", systemImage: "bell.badge.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(VuumColor.primaryText)

            Text("Get driver arrival, trip, receipt, and safety updates on this device.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
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
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(VuumColor.brandInk, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 6)
    }

    private func notificationRow(_ item: AppNotification) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.kind.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(iconBackground(for: item.kind), in: RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(.system(size: 15, weight: item.isRead ? .semibold : .bold))
                        .foregroundStyle(VuumColor.primaryText)
                    Spacer(minLength: 8)
                    Text(relativeTime(item.createdAt))
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Text(item.kind.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color(red: 0.2, green: 0.45, blue: 0.95))

                Text(item.body)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !item.isRead {
                Circle()
                    .fill(Color(red: 0.2, green: 0.45, blue: 0.95))
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.title). \(item.kind.label). \(item.body)")
        .accessibilityHint(item.isRead ? "Read" : "Unread. Double tap to mark as read.")
    }

    private func iconBackground(for kind: AppNotificationKind) -> Color {
        switch kind.category {
        case .promo:
            return VuumColor.brand
        case .payment:
            return Color(red: 0.15, green: 0.55, blue: 0.35)
        case .safety:
            return Color(red: 0.85, green: 0.35, blue: 0.2)
        case .system:
            return Color(white: 0.35)
        case .trip:
            return Color(red: 0.2, green: 0.45, blue: 0.95)
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
