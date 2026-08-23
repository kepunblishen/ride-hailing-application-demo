import Combine
import Foundation

/// Hidden diagnostics for engineers / presenters. Not part of the normal rider journey.
@MainActor
final class DeveloperDiagnostics: ObservableObject {
    static let shared = DeveloperDiagnostics()

    enum PaymentSimulation: String, CaseIterable, Identifiable {
        case automatic
        case forceSuccess
        case forceFailure

        var id: String { rawValue }

        var title: String {
            switch self {
            case .automatic: return "Automatic"
            case .forceSuccess: return "Force success"
            case .forceFailure: return "Force failure"
            }
        }
    }

    private enum Keys {
        static let unlocked = "vuum.diagnostics.unlocked"
        static let forceOffline = "vuum.diagnostics.forceOffline"
        static let paymentSim = "vuum.diagnostics.paymentSim"
    }

    /// Session + persisted unlock so IPA presenters can keep tools available after relaunch.
    @Published var isUnlocked: Bool {
        didSet { defaults.set(isUnlocked, forKey: Keys.unlocked) }
    }

    @Published var forceNetworkOffline: Bool {
        didSet { defaults.set(forceNetworkOffline, forKey: Keys.forceOffline) }
    }

    @Published var paymentSimulation: PaymentSimulation {
        didSet { defaults.set(paymentSimulation.rawValue, forKey: Keys.paymentSim) }
    }

    /// Secret tap counter on About → Version (not shown in UI).
    @Published private(set) var unlockTapCount = 0

    private let defaults: UserDefaults
    private let unlockThreshold = 7

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isUnlocked = defaults.bool(forKey: Keys.unlocked)
        forceNetworkOffline = defaults.bool(forKey: Keys.forceOffline)
        let sim = defaults.string(forKey: Keys.paymentSim) ?? PaymentSimulation.automatic.rawValue
        paymentSimulation = PaymentSimulation(rawValue: sim) ?? .automatic
    }

    @discardableResult
    func registerUnlockTap() -> Bool {
        unlockTapCount += 1
        if unlockTapCount >= unlockThreshold {
            isUnlocked = true
            unlockTapCount = 0
            return true
        }
        return false
    }

    func lock() {
        isUnlocked = false
        unlockTapCount = 0
        forceNetworkOffline = false
        paymentSimulation = .automatic
    }
}
