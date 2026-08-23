import Combine
import Foundation

/// Auth/onboarding UI language only. Persists in UserDefaults and does **not** change
/// main-app `AppPreferences` — Home and trip flow stay on the default app language.
final class AuthLocale: ObservableObject {
    static let shared = AuthLocale()
    static let storageKey = "vuum.auth.language"

    enum Language: String, CaseIterable, Identifiable {
        case englishUS = "en-US"
        case englishUK = "en-GB"
        case french = "fr"
        case lingala = "ln"
        case kiswahili = "sw"

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .englishUS: return "English (US)"
            case .englishUK: return "English (UK)"
            case .french: return "Français"
            case .lingala: return "Lingala"
            case .kiswahili: return "Kiswahili"
            }
        }

        var flagEmoji: String {
            switch self {
            case .englishUS: return "🇺🇸"
            case .englishUK: return "🇬🇧"
            case .french: return "🇫🇷"
            case .lingala: return "🇨🇩"
            case .kiswahili: return "🇰🇪"
            }
        }

        /// Maps to the shared L10n catalog (US/UK share English copy).
        var appLanguage: AppLanguage {
            switch self {
            case .englishUS, .englishUK: return .english
            case .french: return .french
            case .lingala: return .lingala
            case .kiswahili: return .kiswahili
            }
        }
    }

    @Published var language: Language {
        didSet {
            guard language != oldValue else { return }
            UserDefaults.standard.set(language.rawValue, forKey: Self.storageKey)
        }
    }

    /// When true, `L10n` resolves against this store instead of `AppPreferences`.
    @Published var isActive = false

    init(defaults: UserDefaults = .standard) {
        let raw = defaults.string(forKey: Self.storageKey) ?? ""
        language = Language(rawValue: raw) ?? .englishUS
    }

    var resolvedAppLanguage: AppLanguage { language.appLanguage }

    func select(_ value: Language) {
        language = value
    }
}
