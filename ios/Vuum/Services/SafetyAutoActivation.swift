import Foundation

/// Rules that auto-enable rider safety features (RFQ SA09).
enum SafetyAutoActivation {
    static let autoRecordKey = "vuum.safety.autoRecordNightLong"
    static let autoShareKey = "vuum.safety.shareByDefault"
    static let audioQualityKey = "vuum.safety.audioQuality"

    enum AudioQuality: String, CaseIterable, Identifiable {
        case economy
        case standard
        case high

        var id: String { rawValue }

        var title: String {
            switch self {
            case .economy: return "Economy (8 kHz)"
            case .standard: return "Standard (16 kHz)"
            case .high: return "High (24 kHz)"
            }
        }

        var sampleRate: Double {
            switch self {
            case .economy: return 8_000
            case .standard: return 16_000
            case .high: return 24_000
            }
        }

        var encoderQuality: Int {
            switch self {
            case .economy: return 32 // AVAudioQuality.min-ish
            case .standard: return 64 // medium
            case .high: return 96 // high
            }
        }

        static func current(defaults: UserDefaults = .standard) -> AudioQuality {
            AudioQuality(rawValue: defaults.string(forKey: audioQualityKey) ?? "") ?? .standard
        }
    }

    struct Decision: Equatable {
        var shouldAutoShare: Bool
        var shouldAutoRecord: Bool
        var reason: String?
    }

    static func evaluate(
        date: Date = Date(),
        distanceKm: Double,
        defaults: UserDefaults = .standard
    ) -> Decision {
        let hour = Calendar.current.component(.hour, from: date)
        let isNight = hour >= 21 || hour < 5
        let isLong = distanceKm >= 12
        let autoRecordEnabled = defaults.object(forKey: autoRecordKey) as? Bool ?? true
        let autoShare = defaults.object(forKey: autoShareKey) as? Bool ?? true

        var reasons: [String] = []
        if isNight { reasons.append("night trip") }
        if isLong { reasons.append("longer route") }

        let trigger = (isNight || isLong) && autoRecordEnabled
        return Decision(
            shouldAutoShare: autoShare,
            shouldAutoRecord: trigger,
            reason: trigger ? reasons.joined(separator: " · ") : nil
        )
    }
}
