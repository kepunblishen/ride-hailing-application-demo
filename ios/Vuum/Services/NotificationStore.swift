import Combine
import Foundation
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
        static let items = "vuum.notifications.items.v3"
    }

    @Published private(set) var items: [AppNotification] = []

    private let defaults: UserDefaults
    private let center: UNUserNotificationCenter

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
        items.removeAll(\.isRead)
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
        // Fresh v3 key so installs pick up the full category seed (legacy keys ignored).
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
                kind: .driverAssigned,
                title: "Jean-Claude is on the way",
                body: "ETA 8 min · Toyota Corolla · ABC 482 · Comfort",
                createdAt: now.addingTimeInterval(-18 * 60),
                isRead: false
            ),
            AppNotification(
                id: UUID(),
                kind: .promo,
                title: "20% off your next ride",
                body: "Use code VUUM20 this week on Comfort and XL trips in Lubumbashi.",
                createdAt: now.addingTimeInterval(-3 * 3600),
                isRead: false
            ),
            AppNotification(
                id: UUID(),
                kind: .receipt,
                title: "Receipt ready",
                body: "Your trip to Gécamines is saved in Activity with a full fare breakdown.",
                createdAt: now.addingTimeInterval(-5 * 3600),
                isRead: false
            ),
            AppNotification(
                id: UUID(),
                kind: .tripStarted,
                title: "Trip started",
                body: "You’re heading to Gécamines. Share live status from Safety anytime.",
                createdAt: now.addingTimeInterval(-5 * 3600 - 25 * 60),
                isRead: true
            ),
            AppNotification(
                id: UUID(),
                kind: .driverArrived,
                title: "Your driver is here",
                body: "Meet Jean-Claude at your pickup and share your trip PIN to start.",
                createdAt: now.addingTimeInterval(-5 * 3600 - 28 * 60),
                isRead: true
            ),
            AppNotification(
                id: UUID(),
                kind: .recordingStarted,
                title: "Audio recording on",
                body: "In-trip audio capture started on your device. Your driver was notified.",
                createdAt: now.addingTimeInterval(-5 * 3600 - 20 * 60),
                isRead: true
            ),
            AppNotification(
                id: UUID(),
                kind: .recordingStopped,
                title: "Audio recording stopped",
                body: "Recording ended before drop-off. File kept only if you report an incident.",
                createdAt: now.addingTimeInterval(-5 * 3600 - 5 * 60),
                isRead: true
            ),
            AppNotification(
                id: UUID(),
                kind: .tripCompleted,
                title: "Trip completed",
                body: "You arrived at Gécamines. Rate your trip from Activity when you’re ready.",
                createdAt: now.addingTimeInterval(-5 * 3600 + 60),
                isRead: true
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
                kind: .scheduledReminder,
                title: "Upcoming reserved ride",
                body: "Airport pickup tomorrow at 06:40. We’ll notify you when a driver is assigned.",
                createdAt: now.addingTimeInterval(-8 * 3600),
                isRead: true
            ),
            AppNotification(
                id: UUID(),
                kind: .driverReassigned,
                title: "New driver assigned",
                body: "Amina will pick you up · Hyundai Tucson · KDG 219",
                createdAt: now.addingTimeInterval(-30 * 3600),
                isRead: true
            ),
            AppNotification(
                id: UUID(),
                kind: .cancellation,
                title: "Trip cancelled",
                body: "Your Comfort trip to Hub Mall was cancelled. No cancellation fee applied.",
                createdAt: now.addingTimeInterval(-36 * 3600),
                isRead: true
            ),
            AppNotification(
                id: UUID(),
                kind: .paymentFailed,
                title: "Payment could not be completed",
                body: "We couldn’t charge your card ending in 4242. Update payment methods in Account.",
                createdAt: now.addingTimeInterval(-2 * 24 * 3600),
                isRead: true
            ),
            AppNotification(
                id: UUID(),
                kind: .supportResponse,
                title: "Support replied",
                body: "Your lost-item request for yesterday’s Comfort trip is being reviewed.",
                createdAt: now.addingTimeInterval(-2 * 24 * 3600 - 3600),
                isRead: true
            ),
            AppNotification(
                id: UUID(),
                kind: .safetyEvent,
                title: "Trip share link updated",
                body: "Trusted contacts can follow your live trip status while you ride.",
                createdAt: now.addingTimeInterval(-3 * 24 * 3600),
                isRead: true
            ),
            AppNotification(
                id: UUID(),
                kind: .incidentUpdate,
                title: "Incident report received",
                body: "Safety is reviewing your report from trip #VU-1842. We’ll follow up in Help.",
                createdAt: now.addingTimeInterval(-4 * 24 * 3600),
                isRead: true
            ),
            AppNotification(
                id: UUID(),
                kind: .otp,
                title: "Verification code sent",
                body: "Use the code we texted you to finish signing in to Vuum.",
                createdAt: now.addingTimeInterval(-5 * 24 * 3600),
                isRead: true
            ),
            AppNotification(
                id: UUID(),
                kind: .promo,
                title: "Invite friends, ride free",
                body: "Share your invite link. You both get a ride credit after their first trip.",
                createdAt: now.addingTimeInterval(-6 * 24 * 3600),
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
        center.setBadgeCount(unreadCount)
    }
}
