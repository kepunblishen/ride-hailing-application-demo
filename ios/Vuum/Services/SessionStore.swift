import Combine
import Foundation
import KeychainSwift

/// Persisted rider session. Survives app kill / phone restart until sign-out,
/// app delete, corrupted recovery, expiry, or a Sideloadly install that replaces the app container.
@MainActor
final class SessionStore: ObservableObject {
    private enum Keys {
        static let signedIn = "vuum.session.signedIn"
        static let mobile = "vuum.session.mobile"
        static let firstName = "vuum.session.firstName"
        static let lastName = "vuum.session.lastName"
        static let countryCode = "vuum.session.countryCode"
        static let email = "vuum.session.email"
        static let signedInAt = "vuum.session.signedInAt"
    }

    /// Soft expiry so long-abandoned installs re-authenticate (presentation-safe: 1 year).
    private static let maxSessionAge: TimeInterval = 365 * 24 * 60 * 60

    @Published private(set) var isSignedIn: Bool
    @Published private(set) var mobileNumber: String
    @Published private(set) var countryCode: String
    @Published private(set) var firstName: String
    @Published private(set) var lastName: String
    @Published private(set) var email: String

    private let keychain: KeychainSwift

    init(keychain: KeychainSwift = KeychainSwift()) {
        self.keychain = keychain
        Self.migrateFromUserDefaultsIfNeeded(into: keychain)

        isSignedIn = keychain.getBool(Keys.signedIn) ?? false
        mobileNumber = keychain.get(Keys.mobile) ?? ""
        countryCode = keychain.get(Keys.countryCode) ?? AppLocale.defaultCountryCode
        firstName = keychain.get(Keys.firstName) ?? ""
        lastName = keychain.get(Keys.lastName) ?? ""
        email = keychain.get(Keys.email) ?? ""

        reconcilePersistedState()
    }

    var displayName: String {
        let full = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return full.isEmpty ? "Rider" : full
    }

    var maskedMobile: String {
        let digits = mobileNumber.filter(\.isNumber)
        guard digits.count >= 2 else { return countryCode }
        let tail = String(digits.suffix(2))
        return "\(countryCode) ••••••••\(tail)"
    }

    func completeSignIn(
        countryCode: String,
        mobileNumber: String,
        firstName: String,
        lastName: String,
        email: String = ""
    ) {
        self.countryCode = countryCode
        self.mobileNumber = mobileNumber.filter(\.isNumber)
        self.firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.lastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        isSignedIn = true
        persist(signedInAt: Date())
    }

    func updateProfile(
        firstName: String,
        lastName: String,
        countryCode: String,
        mobileNumber: String,
        email: String
    ) {
        self.firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.lastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.countryCode = countryCode.trimmingCharacters(in: .whitespacesAndNewlines)
        self.mobileNumber = mobileNumber.filter(\.isNumber)
        self.email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        persist(signedInAt: persistedSignedInAt() ?? Date())
    }

    /// Clears the local session after a delete-account confirmation.
    func deleteAccount() {
        signOut()
    }

    func signOut() {
        isSignedIn = false
        mobileNumber = ""
        firstName = ""
        lastName = ""
        email = ""
        countryCode = AppLocale.defaultCountryCode
        keychain.delete(Keys.signedIn)
        keychain.delete(Keys.mobile)
        keychain.delete(Keys.firstName)
        keychain.delete(Keys.lastName)
        keychain.delete(Keys.countryCode)
        keychain.delete(Keys.email)
        keychain.delete(Keys.signedInAt)
    }

    // MARK: - Persistence

    private func persist(signedInAt: Date) {
        keychain.set(true, forKey: Keys.signedIn, withAccess: .accessibleAfterFirstUnlockThisDeviceOnly)
        keychain.set(mobileNumber, forKey: Keys.mobile, withAccess: .accessibleAfterFirstUnlockThisDeviceOnly)
        keychain.set(countryCode, forKey: Keys.countryCode, withAccess: .accessibleAfterFirstUnlockThisDeviceOnly)
        keychain.set(firstName, forKey: Keys.firstName, withAccess: .accessibleAfterFirstUnlockThisDeviceOnly)
        keychain.set(lastName, forKey: Keys.lastName, withAccess: .accessibleAfterFirstUnlockThisDeviceOnly)
        keychain.set(email, forKey: Keys.email, withAccess: .accessibleAfterFirstUnlockThisDeviceOnly)
        keychain.set(
            String(signedInAt.timeIntervalSince1970),
            forKey: Keys.signedInAt,
            withAccess: .accessibleAfterFirstUnlockThisDeviceOnly
        )
    }

    private func persistedSignedInAt() -> Date? {
        guard let raw = keychain.get(Keys.signedInAt),
              let interval = TimeInterval(raw)
        else { return nil }
        return Date(timeIntervalSince1970: interval)
    }

    /// Drop corrupted or expired Keychain sessions so splash → auth is coherent.
    private func reconcilePersistedState() {
        guard isSignedIn else { return }

        if mobileNumber.filter(\.isNumber).count < 6 {
            signOut()
            return
        }

        if let signedInAt = persistedSignedInAt(),
           Date().timeIntervalSince(signedInAt) > Self.maxSessionAge {
            signOut()
            return
        }

        // Legacy sessions without a timestamp: stamp now so expiry starts cleanly.
        if persistedSignedInAt() == nil {
            persist(signedInAt: Date())
        }
    }

    /// One-shot move from earlier UserDefaults-backed sessions into Keychain.
    private static func migrateFromUserDefaultsIfNeeded(into keychain: KeychainSwift) {
        let defaults = UserDefaults.standard
        guard keychain.getBool(Keys.signedIn) != true,
              defaults.bool(forKey: Keys.signedIn)
        else { return }

        keychain.set(true, forKey: Keys.signedIn, withAccess: .accessibleAfterFirstUnlockThisDeviceOnly)
        if let mobile = defaults.string(forKey: Keys.mobile) {
            keychain.set(mobile, forKey: Keys.mobile, withAccess: .accessibleAfterFirstUnlockThisDeviceOnly)
        }
        if let code = defaults.string(forKey: Keys.countryCode) {
            keychain.set(code, forKey: Keys.countryCode, withAccess: .accessibleAfterFirstUnlockThisDeviceOnly)
        }
        if let first = defaults.string(forKey: Keys.firstName) {
            keychain.set(first, forKey: Keys.firstName, withAccess: .accessibleAfterFirstUnlockThisDeviceOnly)
        }
        if let last = defaults.string(forKey: Keys.lastName) {
            keychain.set(last, forKey: Keys.lastName, withAccess: .accessibleAfterFirstUnlockThisDeviceOnly)
        }
        if let mail = defaults.string(forKey: Keys.email) {
            keychain.set(mail, forKey: Keys.email, withAccess: .accessibleAfterFirstUnlockThisDeviceOnly)
        }
        keychain.set(
            String(Date().timeIntervalSince1970),
            forKey: Keys.signedInAt,
            withAccess: .accessibleAfterFirstUnlockThisDeviceOnly
        )

        defaults.removeObject(forKey: Keys.signedIn)
        defaults.removeObject(forKey: Keys.mobile)
        defaults.removeObject(forKey: Keys.firstName)
        defaults.removeObject(forKey: Keys.lastName)
        defaults.removeObject(forKey: Keys.countryCode)
        defaults.removeObject(forKey: Keys.email)
    }
}
