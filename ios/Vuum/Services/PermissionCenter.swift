import AVFoundation
import Combine
import CoreLocation
import CoreMotion
import Foundation
import UIKit
import UserNotifications

/// Centralized permission orchestration for the rider app.
///
/// Requests are contextual: home asks for location + notifications;
/// microphone is requested only when the rider starts in-trip safety audio.
@MainActor
final class PermissionCenter: ObservableObject {
    static let explainerDefaultsKey = "vuum.permissions.explainerShown"
    static let preciseLocationDefaultsKey = "vuum.privacy.shareLocationPrecise"

    @Published private(set) var locationAuthorization: CLAuthorizationStatus = .notDetermined
    @Published private(set) var notificationAuthorization: UNAuthorizationStatus = .notDetermined
    @Published private(set) var microphoneAuthorized = false
    @Published private(set) var microphoneDenied = false
    @Published private(set) var cameraAuthorized = false
    @Published private(set) var motionAuthorized = false

    private weak var locationManager: RiderLocationManager?
    private var locationAuthCancellable: AnyCancellable?
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        refreshLocalDeviceFlags()
    }

    var shouldShowExplainer: Bool {
        !defaults.bool(forKey: Self.explainerDefaultsKey)
    }

    var isLocationAuthorized: Bool {
        locationAuthorization == .authorizedWhenInUse || locationAuthorization == .authorizedAlways
    }

    var isLocationDenied: Bool {
        switch locationAuthorization {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    var isLocationNotDetermined: Bool {
        locationAuthorization == .notDetermined
    }

    var isNotificationAuthorized: Bool {
        switch notificationAuthorization {
        case .authorized, .provisional, .ephemeral:
            return true
        default:
            return false
        }
    }

    var isNotificationDenied: Bool {
        notificationAuthorization == .denied
    }

    var systemSettingsURL: URL? {
        URL(string: UIApplication.openSettingsURLString)
    }

    @discardableResult
    func openSystemSettings() -> Bool {
        guard let url = systemSettingsURL else { return false }
        UIApplication.shared.open(url)
        return true
    }

    func bind(locationManager: RiderLocationManager) {
        self.locationManager = locationManager
        locationAuthorization = locationManager.authorization
        locationAuthCancellable = locationManager.$authorization
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                self?.locationAuthorization = status
            }
        applyPreciseLocationPreference()
    }

    func markExplainerShown() {
        defaults.set(true, forKey: Self.explainerDefaultsKey)
    }

    func refreshStatuses() async {
        locationAuthorization = locationManager?.authorization ?? CLLocationManager().authorizationStatus
        notificationAuthorization = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        refreshLocalDeviceFlags()
        if CMMotionActivityManager.isActivityAvailable() {
            motionAuthorized = CMMotionActivityManager.authorizationStatus() == .authorized
        }
        applyPreciseLocationPreference()
    }

    /// Home essentials only — location for pickup/map + notifications for trip updates.
    /// Microphone / camera / motion stay deferred until a feature needs them.
    func requestHomePermissions() async {
        await requestLocationWhenInUse()
        // Let the location system prompt fully dismiss before notifications,
        // so the two iOS dialogs do not stack on top of each other.
        try? await Task.sleep(for: .milliseconds(900))
        await requestNotifications()
        await refreshStatuses()
    }

    /// Backward-compatible alias used by home explainer Continue.
    func requestCorePermissions() async {
        await requestHomePermissions()
    }

    func requestLocationWhenInUse() async {
        locationManager?.requestWhenInUse()
        // Allow Core Location to deliver the authorization callback.
        try? await Task.sleep(for: .milliseconds(350))
        locationAuthorization = locationManager?.authorization ?? locationAuthorization
    }

    /// Reserved for trip-share / live tracking that needs background location.
    /// When-in-use is enough for current pickup and map tracking.
    func requestLocationAlwaysIfNeeded() async {
        locationManager?.requestAlways()
        try? await Task.sleep(for: .milliseconds(350))
        locationAuthorization = locationManager?.authorization ?? locationAuthorization
    }

    func requestNotifications() async {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
            notificationAuthorization = granted ? .authorized : .denied
            if granted {
                notificationAuthorization = await UNUserNotificationCenter.current()
                    .notificationSettings().authorizationStatus
            }
        } catch {
            notificationAuthorization = .denied
        }
    }

    @discardableResult
    func requestMicrophone() async -> Bool {
        let session = AVAudioSession.sharedInstance()
        switch session.recordPermission {
        case .granted:
            microphoneAuthorized = true
            microphoneDenied = false
        case .denied:
            microphoneAuthorized = false
            microphoneDenied = true
        case .undetermined:
            let granted = await withCheckedContinuation { continuation in
                session.requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            microphoneAuthorized = granted
            microphoneDenied = !granted
        @unknown default:
            microphoneAuthorized = false
            microphoneDenied = true
        }
        return microphoneAuthorized
    }

    @discardableResult
    func requestCamera() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            cameraAuthorized = true
        case .notDetermined:
            cameraAuthorized = await AVCaptureDevice.requestAccess(for: .video)
        default:
            cameraAuthorized = false
        }
        return cameraAuthorized
    }

    @discardableResult
    func requestMotion() async -> Bool {
        guard CMMotionActivityManager.isActivityAvailable() else {
            motionAuthorized = false
            return false
        }

        let status = CMMotionActivityManager.authorizationStatus()
        switch status {
        case .authorized:
            motionAuthorized = true
        case .restricted, .denied:
            motionAuthorized = false
        case .notDetermined:
            motionAuthorized = await Self.promptMotionAuthorization()
        @unknown default:
            motionAuthorized = false
        }
        return motionAuthorized
    }

    func applyPreciseLocationPreference() {
        let precise: Bool
        if defaults.object(forKey: Self.preciseLocationDefaultsKey) == nil {
            precise = true
        } else {
            precise = defaults.bool(forKey: Self.preciseLocationDefaultsKey)
        }
        locationManager?.setPreciseLocationEnabled(precise)
    }

    private func refreshLocalDeviceFlags() {
        let mic = AVAudioSession.sharedInstance().recordPermission
        microphoneAuthorized = mic == .granted
        microphoneDenied = mic == .denied
        cameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        if CMMotionActivityManager.isActivityAvailable() {
            motionAuthorized = CMMotionActivityManager.authorizationStatus() == .authorized
        }
    }

    private static func promptMotionAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            let manager = CMMotionActivityManager()
            let end = Date()
            let start = end.addingTimeInterval(-60)
            manager.queryActivityStarting(from: start, to: end, to: .main) { _, _ in
                continuation.resume(returning: CMMotionActivityManager.authorizationStatus() == .authorized)
            }
        }
    }
}
