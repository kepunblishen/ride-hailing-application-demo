import Combine
import Foundation

enum AuthStep: Equatable {
    case getStarted
    case otp
    case terms
    case confirmInfo
    case welcome
}

enum AuthAsyncPhase: Equatable {
    case idle
    case loading
    case success
    case error
}

@MainActor
final class AuthFlowController: ObservableObject {
    private static let countryCodeKey = "vuum.auth.lastCountryCode"
    private static let countryFlagKey = "vuum.auth.lastCountryFlag"
    private static let otpValiditySeconds: TimeInterval = 180
    private static let resendCooldownSeconds = 30
    private static let maxOTPAttempts = 5
    /// Alternate local verification path until a real backup-code provider is wired.
    private static let backupOTP = "0000"

    @Published var step: AuthStep = .getStarted
    @Published var countryCode: String
    @Published var countryFlag: String
    @Published var phoneLocal: String = ""
    @Published var otpDigits: [String] = ["", "", "", ""]
    @Published var agreedToTerms = false
    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var email: String = ""

    @Published private(set) var phoneSendPhase: AuthAsyncPhase = .idle
    @Published private(set) var otpVerifyPhase: AuthAsyncPhase = .idle
    @Published private(set) var profileSavePhase: AuthAsyncPhase = .idle
    @Published private(set) var phoneError: String?
    @Published private(set) var otpError: String?
    @Published private(set) var profileError: String?
    @Published private(set) var resendSecondsRemaining = 0
    @Published private(set) var isResending = false

    /// Simulated SMS code — last 4 national digits (presenter-friendly; replaceable by a real OTP provider).
    private(set) var expectedOTP: String = "0000"
    private var otpExpiresAt: Date?
    private var otpAttempts = 0
    private var resendTask: Task<Void, Never>?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let stored = defaults.string(forKey: Self.countryCodeKey), !stored.isEmpty {
            countryCode = stored
            countryFlag = defaults.string(forKey: Self.countryFlagKey) ?? AppLocale.flag(for: stored)
        } else {
            countryCode = AppLocale.defaultCountryCode
            countryFlag = AppLocale.defaultCountryFlag
        }
    }

    var phoneDigits: String {
        phoneLocal.filter(\.isNumber)
    }

    /// National number used for session / OTP mask (trunk `0` stripped).
    var normalizedPhoneDigits: String {
        AppLocale.normalizedLocalDigits(phoneLocal)
    }

    var phonePlaceholder: String {
        AppLocale.phonePlaceholder(for: countryCode)
    }

    var countryFlagLabel: String {
        AppLocale.flagLabel(for: countryCode)
    }

    var requiredLocalDigitCount: Int {
        AppLocale.requiredLocalDigitCount(for: countryCode)
    }

    var canContinuePhone: Bool {
        phoneSendPhase != .loading
            && AppLocale.isValidLocalNumber(phoneLocal, countryCode: countryCode)
    }

    var otpCode: String {
        otpDigits.joined()
    }

    var canSubmitOTP: Bool {
        otpVerifyPhase != .loading
            && otpCode.count == 4
            && otpCode.allSatisfy(\.isNumber)
            && otpAttempts < Self.maxOTPAttempts
    }

    var canSubmitProfile: Bool {
        profileSavePhase != .loading
            && isValidName(firstName)
            && isValidName(lastName)
            && isValidEmailIfPresent
    }

    var isValidEmailIfPresent: Bool {
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return trimmed.contains("@")
            && trimmed.contains(".")
            && trimmed.count >= 5
            && !trimmed.hasPrefix("@")
            && !trimmed.hasSuffix("@")
    }

    var maskedPhoneForOTP: String {
        let digits = normalizedPhoneDigits
        let tail = digits.count >= 2 ? String(digits.suffix(2)) : digits
        return "\(countryCode) ••••••••\(tail)"
    }

    var formattedPhoneDisplay: String {
        AppLocale.formatLocalNumber(normalizedPhoneDigits, countryCode: countryCode)
    }

    var canResendOTP: Bool {
        !isResending && resendSecondsRemaining == 0 && otpVerifyPhase != .loading
    }

    func selectCountry(code: String, flag: String) {
        countryCode = code
        countryFlag = flag
        defaults.set(code, forKey: Self.countryCodeKey)
        defaults.set(flag, forKey: Self.countryFlagKey)
        phoneError = nil
        let maxDigits = AppLocale.requiredLocalDigitCount(for: code) + 1
        let digits = phoneLocal.filter(\.isNumber)
        if digits.count > maxDigits {
            phoneLocal = String(digits.prefix(maxDigits))
        }
    }

    func applyPhoneInput(_ raw: String) {
        phoneError = nil
        let maxDigits = requiredLocalDigitCount + 1
        phoneLocal = String(raw.filter(\.isNumber).prefix(maxDigits))
    }

    func applyName(_ raw: String, to keyPath: ReferenceWritableKeyPath<AuthFlowController, String>) {
        profileError = nil
        let filtered = String(raw.unicodeScalars.filter { scalar in
            CharacterSet.letters.contains(scalar)
                || scalar == " " as UnicodeScalar
                || scalar == "-" as UnicodeScalar
                || scalar == "'" as UnicodeScalar
                || scalar == "’" as UnicodeScalar
        }.map(Character.init).prefix(40))
        self[keyPath: keyPath] = filtered
    }

    func applyEmail(_ raw: String) {
        profileError = nil
        email = String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(80))
    }

    func setOTPDigit(_ value: String, at index: Int) {
        guard otpDigits.indices.contains(index) else { return }
        otpError = nil
        if otpVerifyPhase == .error { otpVerifyPhase = .idle }
        otpDigits[index] = String(value.filter(\.isNumber).prefix(1))
    }

    /// Paste / autofill entire OTP into the four boxes.
    func applyOTPPaste(_ raw: String) {
        otpError = nil
        if otpVerifyPhase == .error { otpVerifyPhase = .idle }
        let digits = Array(raw.filter(\.isNumber).prefix(4))
        otpDigits = (0..<4).map { i in
            i < digits.count ? String(digits[i]) : ""
        }
    }

    /// Silently fills the expected local OTP when the rider has not typed anything yet.
    func autofillExpectedOTPIfEmpty() {
        guard otpDigits.allSatisfy(\.isEmpty) else { return }
        let code = expectedOTP.filter(\.isNumber)
        guard code.count == 4 else { return }
        applyOTPPaste(code)
    }

    func goToOTP() {
        Task { await sendCodeAndAdvance() }
    }

    func goToTerms() {
        Task { await verifyOTPAndAdvance() }
    }

    /// Validates a backup code entered from the backup-code sheet.
    func submitBackupCode(_ raw: String) {
        Task { await verifyBackupCodeAndAdvance(raw) }
    }

    func goToConfirmInfo() {
        guard agreedToTerms else { return }
        step = .confirmInfo
    }

    func goToWelcome() {
        Task { await saveProfileAndAdvance() }
    }

    func resendCode() {
        guard canResendOTP else { return }
        Task { await performResend() }
    }

    func goBack() {
        phoneSendPhase = .idle
        otpVerifyPhase = .idle
        profileSavePhase = .idle
        phoneError = nil
        otpError = nil
        profileError = nil
        switch step {
        case .getStarted:
            break
        case .otp:
            cancelResendTimer()
            step = .getStarted
        case .terms:
            step = .otp
        case .confirmInfo:
            step = .terms
        case .welcome:
            step = .confirmInfo
        }
    }

    func reset() {
        cancelResendTimer()
        step = .getStarted
        if let stored = defaults.string(forKey: Self.countryCodeKey), !stored.isEmpty {
            countryCode = stored
            countryFlag = defaults.string(forKey: Self.countryFlagKey) ?? AppLocale.flag(for: stored)
        } else {
            countryCode = AppLocale.defaultCountryCode
            countryFlag = AppLocale.defaultCountryFlag
        }
        phoneLocal = ""
        otpDigits = ["", "", "", ""]
        agreedToTerms = false
        firstName = ""
        lastName = ""
        email = ""
        phoneSendPhase = .idle
        otpVerifyPhase = .idle
        profileSavePhase = .idle
        phoneError = nil
        otpError = nil
        profileError = nil
        expectedOTP = "0000"
        otpExpiresAt = nil
        otpAttempts = 0
        resendSecondsRemaining = 0
        isResending = false
    }

    // MARK: - Private async flow

    private func sendCodeAndAdvance() async {
        guard canContinuePhone else {
            phoneError = L10n.Auth.phoneInvalid
            return
        }
        phoneLocal = normalizedPhoneDigits
        phoneSendPhase = .loading
        phoneError = nil
        try? await Task.sleep(for: .milliseconds(700))
        guard !Task.isCancelled else { return }
        beginOTPChallenge()
        phoneSendPhase = .idle
        step = .otp
    }

    private func verifyOTPAndAdvance() async {
        guard canSubmitOTP else { return }

        if isOTPExpired {
            otpVerifyPhase = .error
            otpError = L10n.Auth.otpExpired
            return
        }

        otpVerifyPhase = .loading
        otpError = nil
        try? await Task.sleep(for: .milliseconds(650))
        guard !Task.isCancelled else { return }

        if otpCode != expectedOTP {
            otpAttempts += 1
            otpVerifyPhase = .error
            otpDigits = ["", "", "", ""]
            otpError = otpAttempts >= Self.maxOTPAttempts
                ? L10n.Auth.otpTooManyAttempts
                : L10n.Auth.otpInvalid
            return
        }

        completeOTPSuccess()
    }

    private func verifyBackupCodeAndAdvance(_ raw: String) async {
        let code = String(raw.filter(\.isNumber).prefix(4))
        guard code.count == 4 else {
            otpVerifyPhase = .error
            otpError = L10n.Auth.otpInvalid
            return
        }
        if isOTPExpired {
            otpVerifyPhase = .error
            otpError = L10n.Auth.otpExpired
            return
        }
        otpVerifyPhase = .loading
        otpError = nil
        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled else { return }
        if code != Self.backupOTP {
            otpAttempts += 1
            otpVerifyPhase = .error
            otpError = otpAttempts >= Self.maxOTPAttempts
                ? L10n.Auth.otpTooManyAttempts
                : L10n.Auth.otpInvalid
            return
        }
        completeOTPSuccess()
    }

    private func completeOTPSuccess() {
        otpVerifyPhase = .success
        cancelResendTimer()
        agreedToTerms = false
        step = .terms
        otpVerifyPhase = .idle
    }

    private func saveProfileAndAdvance() async {
        guard canSubmitProfile else {
            if !isValidName(firstName) || !isValidName(lastName) {
                profileError = L10n.Auth.nameInvalid
            } else if !isValidEmailIfPresent {
                profileError = L10n.Auth.emailInvalid
            }
            return
        }
        profileSavePhase = .loading
        profileError = nil
        firstName = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        lastName = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        try? await Task.sleep(for: .milliseconds(500))
        guard !Task.isCancelled else { return }
        profileSavePhase = .success
        step = .welcome
        profileSavePhase = .idle
    }

    private func performResend() async {
        isResending = true
        otpError = nil
        otpVerifyPhase = .idle
        try? await Task.sleep(for: .milliseconds(550))
        guard !Task.isCancelled else {
            isResending = false
            return
        }
        beginOTPChallenge()
        isResending = false
    }

    private func beginOTPChallenge() {
        let digits = normalizedPhoneDigits
        expectedOTP = digits.count >= 4 ? String(digits.suffix(4)) : "1234"
        otpDigits = ["", "", "", ""]
        otpAttempts = 0
        otpExpiresAt = Date().addingTimeInterval(Self.otpValiditySeconds)
        otpError = nil
        otpVerifyPhase = .idle
        startResendCooldown()
    }

    private var isOTPExpired: Bool {
        guard let otpExpiresAt else { return true }
        return Date() > otpExpiresAt
    }

    private func startResendCooldown() {
        cancelResendTimer()
        resendSecondsRemaining = Self.resendCooldownSeconds
        resendTask = Task { [weak self] in
            while let self, self.resendSecondsRemaining > 0 {
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
                self.resendSecondsRemaining -= 1
            }
        }
    }

    private func cancelResendTimer() {
        resendTask?.cancel()
        resendTask = nil
        resendSecondsRemaining = 0
    }

    private func isValidName(_ raw: String) -> Bool {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }
}
