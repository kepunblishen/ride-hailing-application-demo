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
                    HStack(spacing: VuumLayout.chipSpacing) {
                        ForEach(NotificationFilterGroup.allCases) { group in
                            VuumFilterChip(title: group.title, selected: filter == group) {
                                filter = group
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .listRowInsets(EdgeInsets(
                    top: 6,
                    leading: VuumLayout.pageInset,
                    bottom: 6,
                    trailing: VuumLayout.pageInset
                ))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if filteredItems.isEmpty {
                Section {
                    inboxEmptyState
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(
                            top: 12,
                            leading: VuumLayout.pageInset,
                            bottom: 12,
                            trailing: VuumLayout.pageInset
                        ))
                        .listRowSeparator(.hidden)
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
                        .listRowInsets(EdgeInsets(
                            top: 8,
                            leading: VuumLayout.pageInset,
                            bottom: 8,
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
                } header: {
                    Text("\(filteredItems.count) · \(notifications.unreadCount) unread")
                        .foregroundStyle(VuumColor.secondaryText)
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
            Image(systemName: "bell.slash")
                .font(.system(size: 32, weight: .medium))
                .foregroundStyle(VuumColor.accent)
                .frame(width: 64, height: 64)
                .background(VuumColor.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: VuumLayout.radiusCard, style: .continuous))

            VStack(spacing: 6) {
                Text(
                    notifications.items.isEmpty
                        ? L10n.t("status.empty_notifications_title")
                        : "Nothing in this filter"
                )
                .font(VuumType.titleSmall)
                .foregroundStyle(VuumColor.primaryText)
                .multilineTextAlignment(.center)

                Text(
                    notifications.items.isEmpty
                        ? L10n.t("status.empty_notifications_detail")
                        : "Try another category or mark new alerts as you ride."
                )
                .font(VuumType.body)
                .foregroundStyle(VuumColor.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .accessibilityElement(children: .combine)
    }

    private var permissionCard: some View {
        VStack(alignment: .leading, spacing: VuumLayout.rowSpacing) {
            Label("Stay updated on trips", systemImage: "bell.badge.fill")
                .font(VuumType.rowTitle)
                .foregroundStyle(VuumColor.primaryText)
                .symbolRenderingMode(.hierarchical)
                .tint(VuumColor.accent)

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
            Image(systemName: item.kind.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(VuumColor.accentOn)
                .frame(width: VuumLayout.iconBadge, height: VuumLayout.iconBadge)
                .background(iconBackground(for: item.kind), in: RoundedRectangle(cornerRadius: VuumLayout.radiusChip, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 15, weight: item.isRead ? .semibold : .bold))
                        .foregroundStyle(VuumColor.primaryText)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 8)
                    Text(relativeTime(item.createdAt))
                        .font(VuumType.caption)
                        .foregroundStyle(VuumColor.secondaryText)
                }

                Text(item.kind.label)
                    .font(VuumType.captionSemibold)
                    .foregroundStyle(VuumColor.accent)

                Text(item.body)
                    .font(VuumType.callout)
                    .foregroundStyle(VuumColor.secondaryText)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !item.isRead {
                Circle()
                    .fill(VuumColor.accent)
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                    .accessibilityHidden(true)
            }
        }
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
            return VuumColor.success
        case .safety:
            return VuumColor.danger
        case .system:
            return VuumColor.secondaryText
        case .trip:
            return VuumColor.accent
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
