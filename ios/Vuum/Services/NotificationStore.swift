import Combine
import Foundation
import UIKit
import UserNotifications

/// Top-level inbox buckets used for filtering and chrome badges.
enum NotificationCategory: String, Codable, CaseIterable, Identifiable {
    case trip
    case promo
    case safety
    case payment
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .trip: return "Trips"
        case .promo: return "Offers"
        case .safety: return "Safety"
        case .payment: return "Payments"
        case .system: return "Account"
        }
    }
}

enum AppNotificationKind: String, Codable, CaseIterable, Identifiable {
    case otp
    case driverAssigned
    case driverArriving
    case driverArrived
    case tripStarted
    case tripCompleted
    case receipt
    case scheduledReminder
    case driverReassigned
    case paymentSucceeded
    case paymentFailed
    case cancellation
    case supportResponse
    case safetyEvent
    case recordingStarted
    case recordingStopped
    case incidentUpdate
    case promo

    /// Legacy aliases kept for decoding older inbox payloads.
    case trip
    case payment
    case safety
    case support
    case schedule
    case system

    var id: String { rawValue }

    var category: NotificationCategory {
        switch self {
        case .promo:
            return .promo
        case .paymentSucceeded, .paymentFailed, .payment, .receipt:
            return .payment
        case .safetyEvent, .recordingStarted, .recordingStopped, .incidentUpdate, .safety:
            return .safety
        case .otp, .supportResponse, .support, .system:
            return .system
        case .driverAssigned, .driverArriving, .driverArrived, .tripStarted, .tripCompleted,
             .driverReassigned, .cancellation, .scheduledReminder, .trip, .schedule:
            return .trip
        }
    }

    var label: String { category.title }

    var filterGroup: NotificationFilterGroup {
        switch category {
        case .promo: return .offers
        case .payment: return .payments
        case .safety: return .safety
        case .system: return .system
        case .trip: return .trips
        }
    }

    var systemImage: String {
        switch self {
        case .promo: return "tag.fill"
        case .otp: return "lock.shield.fill"
        case .driverAssigned, .driverReassigned: return "person.fill.checkmark"
        case .driverArriving: return "car.fill"
        case .driverArrived: return "mappin.and.ellipse"
        case .tripStarted: return "arrow.triangle.turn.up.right.diamond.fill"
        case .tripCompleted, .trip: return "checkmark.circle.fill"
        case .receipt: return "doc.text.fill"
        case .scheduledReminder, .schedule: return "calendar.badge.clock"
        case .paymentSucceeded, .payment: return "creditcard.fill"
        case .paymentFailed: return "exclamationmark.triangle.fill"
        case .cancellation: return "xmark.circle.fill"
        case .supportResponse, .support: return "bubble.left.and.bubble.right.fill"
        case .safetyEvent, .safety: return "shield.lefthalf.filled"
        case .recordingStarted, .recordingStopped: return "mic.fill"
        case .incidentUpdate: return "exclamationmark.shield.fill"
        case .system: return "bell.fill"
        }
    }
}

enum NotificationFilterGroup: String, CaseIterable, Identifiable {
    case all
    case trips
    case payments
    case offers
    case safety
    case system

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .trips: return "Trips"
        case .payments: return "Payments"
        case .offers: return "Offers"
        case .safety: return "Safety"
        case .system: return "Account"
        }
    }

    var category: NotificationCategory? {
        switch self {
        case .all: return nil
        case .trips: return .trip
        case .payments: return .payment
        case .offers: return .promo
        case .safety: return .safety
        case .system: return .system
        }
    }

    func includes(_ kind: AppNotificationKind) -> Bool {
        self == .all || kind.category == category
    }
}

struct AppNotification: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: AppNotificationKind
    let title: String
    let body: String
    let createdAt: Date
    var isRead: Bool

    var category: NotificationCategory { kind.category }
}

/// In-app notification inbox. OS permission lives in `PermissionCenter`.
@MainActor
final class NotificationStore: ObservableObject {
    private enum Keys {
        /// Bumped when sample seed / inbox layout changes so installs pick up a calmer default set.
        static let items = "vuum.notifications.items.v4"
    }

    @Published private(set) var items: [AppNotification] = []

    private let defaults: UserDefaults
    private let center: UNUserNotificationCenter
    /// Icon badge mirrors unread count only while a rider session is active.
    private var iconBadgeEnabled = false

    var unreadCount: Int {
        items.reduce(0) { $0 + ($1.isRead ? 0 : 1) }
    }

    func unreadCount(in category: NotificationCategory) -> Int {
        items.reduce(0) { count, item in
            count + (!item.isRead && item.category == category ? 1 : 0)
        }
    }

    init(
        defaults: UserDefaults = .standard,
        center: UNUserNotificationCenter = .current()
    ) {
        self.defaults = defaults
        self.center = center
        loadOrSeed()
        // Cold start / splash / auth: never show a leftover home-screen badge.
        applyIconBadge(0)
    }

    /// Keep the home-screen badge aligned with session: unread while signed in, zero when signed out.
    func applySessionState(isSignedIn: Bool) {
        if isSignedIn {
            iconBadgeEnabled = true
            syncAppBadge()
        } else {
            clearForSignedOutSession()
        }
    }

    /// Session ended — no badge, no pending rider alerts, inbox treated as read for a logged-out device.
    func clearForSignedOutSession() {
        iconBadgeEnabled = false
        if items.contains(where: { !$0.isRead }) {
            for index in items.indices {
                items[index].isRead = true
            }
            persist()
        }
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
        applyIconBadge(0)
    }

    func markRead(_ id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }), !items[index].isRead else { return }
        items[index].isRead = true
        persist()
        syncAppBadge()
    }

    func markAllRead() {
        guard items.contains(where: { !$0.isRead }) else { return }
        for index in items.indices {
            items[index].isRead = true
        }
        persist()
        syncAppBadge()
    }

    func remove(_ id: UUID) {
        items.removeAll { $0.id == id }
        persist()
        syncAppBadge()
    }

    func clearRead() {
        items.removeAll { $0.isRead }
        persist()
        syncAppBadge()
    }

    func post(_ kind: AppNotificationKind, title: String, body: String) {
        prepend(
            AppNotification(
                id: UUID(),
                kind: kind,
                title: title,
                body: body,
                createdAt: Date(),
                isRead: false
            )
        )
    }

    func postTripUpdate(title: String, body: String) {
        post(.trip, title: title, body: body)
    }

    func postPromo(title: String, body: String) {
        post(.promo, title: title, body: body)
    }

    func postOTP() {
        post(
            .otp,
            title: "Verification code sent",
            body: "Enter the code we sent to your phone to continue signing in."
        )
    }

    func postDriverAssigned(driverName: String, vehicle: String, plate: String, etaMinutes: Int) {
        post(
            .driverAssigned,
            title: "\(driverName) is on the way",
            body: "ETA \(TripGeo.formatDuration(minutes: max(etaMinutes, 0))) · \(vehicle) · \(plate)"
        )
    }

    func postDriverArriving(driverName: String, minutes: Int) {
        post(
            .driverArriving,
            title: "Driver arriving soon",
            body: "\(driverName) is \(max(minutes, 1)) min away. Meet them at your pickup."
        )
    }

    func postDriverArrived() {
        post(
            .driverArrived,
            title: "Your driver is here",
            body: "Meet them at your pickup point and share your trip PIN to start."
        )
    }

    func postTripStarted() {
        post(
            .tripStarted,
            title: "Trip started",
            body: "You’re on the way. Follow the live route and share your trip anytime from Safety."
        )
    }

    func postTripCompleted() {
        post(
            .tripCompleted,
            title: "Trip completed",
            body: "Your receipt is ready in Activity. Thanks for riding with Vuum."
        )
    }

    func postReceiptReady(destination: String) {
        post(
            .receipt,
            title: "Receipt ready",
            body: "Your trip to \(destination) has been saved. Open Activity to review the fare."
        )
    }

    func postCancellation(reason: String? = nil) {
        let detail = reason?.trimmingCharacters(in: .whitespacesAndNewlines)
        post(
            .cancellation,
            title: "Trip cancelled",
            body: (detail?.isEmpty == false) ? detail! : "Your trip was cancelled. You can request a new ride anytime."
        )
    }

    func postDriverReassigned(driverName: String, vehicle: String, plate: String) {
        post(
            .driverReassigned,
            title: "New driver assigned",
            body: "\(driverName) will pick you up · \(vehicle) · \(plate)"
        )
    }

    func postScheduledReminder(pickup: String, when: Date) {
        post(
            .scheduledReminder,
            title: "Upcoming reserved ride",
            body: "Pickup at \(pickup) · \(when.formatted(date: .abbreviated, time: .shortened))"
        )
    }

    func postPaymentSucceeded(amountLabel: String) {
        post(
            .paymentSucceeded,
            title: "Payment successful",
            body: "\(amountLabel) was charged to your selected payment method."
        )
    }

    func postPaymentFailed() {
        post(
            .paymentFailed,
            title: "Payment could not be completed",
            body: "Update your payment method in Account and try again."
        )
    }

    func postSupportResponse() {
        post(
            .supportResponse,
            title: "Support replied",
            body: "We reviewed your request. Open Help for the latest update."
        )
    }

    func postSafetyEvent(title: String, body: String) {
        post(.safetyEvent, title: title, body: body)
    }

    func postRecordingStarted() {
        post(
            .recordingStarted,
            title: "Audio recording on",
            body: "This trip is being recorded on your device. Your driver is notified while recording is active."
        )
    }

    func postRecordingStopped() {
        post(
            .recordingStopped,
            title: "Audio recording stopped",
            body: "Recording ended. The file is removed after the trip unless you report an incident."
        )
    }

    func postIncidentUpdate(title: String, body: String) {
        post(.incidentUpdate, title: title, body: body)
    }

    private func prepend(_ item: AppNotification) {
        items.insert(item, at: 0)
        if items.count > 80 {
            items = Array(items.prefix(80))
        }
        persist()
        syncAppBadge()
    }

    private func loadOrSeed() {
        // Fresh storage key so installs pick up the calmer seed set (legacy keys ignored).
        if let data = defaults.data(forKey: Keys.items),
           let decoded = try? JSONDecoder().decode([AppNotification].self, from: data),
           !decoded.isEmpty {
            items = decoded.sorted { $0.createdAt > $1.createdAt }
            syncAppBadge()
            return
        }
        seedSampleInbox()
    }

    private func seedSampleInbox() {
        let now = Date()
        items = [
            AppNotification(
                id: UUID(),
                kind: .driverArriving,
                title: "Driver arriving soon",
                body: "Jean-Claude is 3 min away. Meet them at the lobby entrance.",
                createdAt: now.addingTimeInterval(-8 * 60),
                isRead: false
            ),
            AppNotification(
                id: UUID(),
                kind: .receipt,
                title: "Receipt ready",
                body: "Your trip to Gécamines is saved in Activity.",
                createdAt: now.addingTimeInterval(-5 * 3600),
                isRead: false
            ),
            AppNotification(
                id: UUID(),
                kind: .paymentSucceeded,
                title: "Payment successful",
                body: "CDF 7,660 was charged to Orange Money.",
                createdAt: now.addingTimeInterval(-5 * 3600 + 90),
                isRead: true
            ),
            AppNotification(
                id: UUID(),
                kind: .supportResponse,
                title: "Support replied",
                body: "Your lost-item request is being reviewed in Help.",
                createdAt: now.addingTimeInterval(-2 * 24 * 3600),
                isRead: true
            ),
            AppNotification(
                id: UUID(),
                kind: .promo,
                title: "20% off your next ride",
                body: "Use code VUUM20 this week on Comfort trips.",
                createdAt: now.addingTimeInterval(-3 * 24 * 3600),
                isRead: true
            ),
        ].sorted { $0.createdAt > $1.createdAt }
        persist()
        syncAppBadge()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: Keys.items)
    }

    private func syncAppBadge() {
        guard iconBadgeEnabled else {
            applyIconBadge(0)
            return
        }
        applyIconBadge(unreadCount)
    }

    private func applyIconBadge(_ count: Int) {
        let value = max(0, count)
        center.setBadgeCount(value)
        UIApplication.shared.applicationIconBadgeNumber = value
    }
}
