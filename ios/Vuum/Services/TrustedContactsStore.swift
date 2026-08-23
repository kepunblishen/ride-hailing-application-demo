import Combine
import Foundation

struct TrustedContact: Identifiable, Equatable, Codable, Hashable {
    var id: String
    var name: String
    var phone: String
    var relationship: String
    /// Primary contact for automatic trip-share prompts.
    var isDefault: Bool
    /// Shown during SOS as an emergency reach-out target.
    var isEmergency: Bool
    /// Reminder to share live trip status with this contact when a ride starts.
    var notifyOnTripShare: Bool

    var displayPhone: String {
        phone.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var telURL: URL? {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty else { return nil }
        return URL(string: "tel://\(digits)")
    }

    var smsURL: URL? {
        let digits = phone.filter { $0.isNumber || $0 == "+" }
        guard !digits.isEmpty else { return nil }
        return URL(string: "sms:\(digits)")
    }
}

/// Persists trusted / emergency contacts in UserDefaults for Trust & Safety.
@MainActor
final class TrustedContactsStore: ObservableObject {
    private enum Keys {
        static let contacts = "vuum.trustedContacts"
    }

    static let maxContacts = 5

    @Published private(set) var contacts: [TrustedContact]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        contacts = Self.load(from: defaults)
    }

    var canAddMore: Bool { contacts.count < Self.maxContacts }

    var defaultContact: TrustedContact? {
        contacts.first(where: \.isDefault) ?? contacts.first
    }

    var emergencyContacts: [TrustedContact] {
        let flagged = contacts.filter(\.isEmergency)
        return flagged.isEmpty ? contacts : flagged
    }

    var tripShareRecipients: [TrustedContact] {
        let flagged = contacts.filter(\.notifyOnTripShare)
        if !flagged.isEmpty { return flagged }
        if let defaultContact { return [defaultContact] }
        return []
    }

    func add(
        name: String,
        phone: String,
        relationship: String,
        isDefault: Bool = false,
        isEmergency: Bool = true,
        notifyOnTripShare: Bool = true
    ) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedRel = relationship.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedPhone.isEmpty, canAddMore else { return }

        var next = contacts
        let makeDefault = isDefault || next.isEmpty
        if makeDefault {
            for idx in next.indices { next[idx].isDefault = false }
        }

        next.append(
            TrustedContact(
                id: UUID().uuidString,
                name: trimmedName,
                phone: trimmedPhone,
                relationship: trimmedRel.isEmpty ? "Contact" : trimmedRel,
                isDefault: makeDefault,
                isEmergency: isEmergency,
                notifyOnTripShare: notifyOnTripShare
            )
        )
        contacts = next
        persist()
    }

    func update(_ contact: TrustedContact) {
        guard let idx = contacts.firstIndex(where: { $0.id == contact.id }) else { return }
        var next = contact
        next.name = contact.name.trimmingCharacters(in: .whitespacesAndNewlines)
        next.phone = contact.phone.trimmingCharacters(in: .whitespacesAndNewlines)
        next.relationship = contact.relationship.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !next.name.isEmpty, !next.phone.isEmpty else { return }
        if next.relationship.isEmpty { next.relationship = "Contact" }

        var list = contacts
        if next.isDefault {
            for i in list.indices { list[i].isDefault = false }
        }
        list[idx] = next
        if !list.contains(where: \.isDefault), let first = list.indices.first {
            list[first].isDefault = true
        }
        contacts = list
        persist()
    }

    func setDefault(id: String) {
        guard contacts.contains(where: { $0.id == id }) else { return }
        contacts = contacts.map { contact in
            var copy = contact
            copy.isDefault = contact.id == id
            return copy
        }
        persist()
    }

    func remove(id: String) {
        contacts.removeAll { $0.id == id }
        if !contacts.isEmpty, !contacts.contains(where: \.isDefault) {
            contacts[0].isDefault = true
        }
        persist()
    }

    func remove(at offsets: IndexSet) {
        contacts.remove(atOffsets: offsets)
        if !contacts.isEmpty, !contacts.contains(where: \.isDefault) {
            contacts[0].isDefault = true
        }
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(contacts) else { return }
        defaults.set(data, forKey: Keys.contacts)
    }

    private static func load(from defaults: UserDefaults) -> [TrustedContact] {
        guard let data = defaults.data(forKey: Keys.contacts) else { return [] }
        if let decoded = try? JSONDecoder().decode([TrustedContact].self, from: data) {
            return decoded
        }
        // Migrate legacy contacts that lacked safety flags.
        struct Legacy: Codable {
            var id: String
            var name: String
            var phone: String
            var relationship: String
        }
        guard let legacy = try? JSONDecoder().decode([Legacy].self, from: data) else { return [] }
        return legacy.enumerated().map { index, item in
            TrustedContact(
                id: item.id,
                name: item.name,
                phone: item.phone,
                relationship: item.relationship,
                isDefault: index == 0,
                isEmergency: true,
                notifyOnTripShare: true
            )
        }
    }
}

enum TripShare {
    static func tripID(for trip: ActiveTrip) -> String {
        if !trip.id.isEmpty { return trip.id.uppercased() }
        let raw = "\(trip.tripPIN)-\(trip.driver.plate)"
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
        return String(raw.prefix(12))
    }

    /// Stable live-share URL for the current trip (local string for ShareLink).
    static func liveShareURLString(for trip: ActiveTrip) -> String {
        let raw = "\(trip.id)-\(trip.tripPIN)-\(trip.driver.plate)-\(trip.dropoff.id)"
            .uppercased()
            .filter { $0.isLetter || $0.isNumber }
        let token = String(raw.prefix(16))
        let padded = token.padding(toLength: 10, withPad: "X", startingAt: 0)
        return "https://share.vuum.app/live/\(padded)"
    }

    static func phaseLabel(for phase: TripPhase) -> String {
        switch phase {
        case .matched, .driverEnRoute:
            return "Driver en route"
        case .driverArrived:
            return "Driver arrived"
        case .inTrip:
            return "In trip"
        case .completed:
            return "Completed"
        default:
            return "Active"
        }
    }

    static func message(for trip: ActiveTrip, phase: TripPhase = .inTrip) -> String {
        let eta = TripGeo.formatDuration(minutes: max(trip.etaMinutes, 0))
        let link = liveShareURLString(for: trip)
        let tripID = tripID(for: trip)
        return """
        I'm on a Vuum trip — follow my ride live:
        \(link)

        Trip ID: \(tripID)
        Status: \(phaseLabel(for: phase))
        Driver: \(trip.driver.name) · \(trip.driver.vehicle) · \(trip.driver.plate)
        To: \(trip.dropoff.name)
        ETA: \(eta)
        Trip PIN: \(trip.tripPIN)

        If anything looks wrong, call me or contact Vuum support.
        """
    }

    static func message(for trip: ActiveTrip, contact: TrustedContact, phase: TripPhase) -> String {
        """
        Hi \(contact.name.split(separator: " ").first.map(String.init) ?? contact.name),

        \(message(for: trip, phase: phase))
        """
    }

    static var shareByDefaultEnabled: Bool {
        UserDefaults.standard.object(forKey: "vuum.safety.shareByDefault") as? Bool ?? true
    }
}
