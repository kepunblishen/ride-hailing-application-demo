import Combine
import CoreLocation
import Foundation

@MainActor
final class RiderLocationManager: NSObject, ObservableObject {
    @Published private(set) var authorization: CLAuthorizationStatus
    @Published private(set) var accuracyAuthorization: CLAccuracyAuthorization
    @Published private(set) var latestLocation: CLLocation?
    @Published private(set) var locationServicesEnabled: Bool
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var isUpdating = false

    private let manager = CLLocationManager()
    private var prefersPrecise = true

    /// Reject fixes older than this or with invalid / absurd horizontal accuracy.
    private let maxLocationAgeSeconds: TimeInterval = 45
    private let maxAcceptableAccuracyMeters: CLLocationAccuracy = 500

    var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    var isDenied: Bool {
        switch authorization {
        case .denied, .restricted:
            return true
        default:
            return false
        }
    }

    /// iOS “Precise Location” is on (or pre-iOS 14 full accuracy).
    var isPreciseLocation: Bool {
        accuracyAuthorization == .fullAccuracy
    }

    var canProvidePickup: Bool {
        isAuthorized && locationServicesEnabled
    }

    override init() {
        authorization = manager.authorizationStatus
        accuracyAuthorization = manager.accuracyAuthorization
        locationServicesEnabled = CLLocationManager.locationServicesEnabled()
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBest
        manager.distanceFilter = 8
        manager.pausesLocationUpdatesAutomatically = true
        manager.activityType = .automotiveNavigation
    }

    func requestWhenInUse() {
        locationServicesEnabled = CLLocationManager.locationServicesEnabled()
        guard locationServicesEnabled else {
            lastErrorMessage = "Location Services are turned off on this device."
            return
        }

        switch manager.authorizationStatus {
        case .notDetermined:
            lastErrorMessage = nil
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            lastErrorMessage = nil
            startUpdatingIfAllowed()
            requestTemporaryPreciseIfNeeded()
        case .denied, .restricted:
            stopUpdating()
            lastErrorMessage = "Location access is off. Turn it on in Settings to set your pickup."
        @unknown default:
            break
        }
    }

    /// Upgrade path for trip share / background tracking. Prefer when-in-use until product needs always.
    func requestAlways() {
        locationServicesEnabled = CLLocationManager.locationServicesEnabled()
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse:
            manager.requestAlwaysAuthorization()
        case .authorizedAlways:
            startUpdatingIfAllowed()
        default:
            break
        }
    }

    func setPreciseLocationEnabled(_ enabled: Bool) {
        prefersPrecise = enabled
        applyAccuracy()
        if isAuthorized {
            if enabled {
                requestTemporaryPreciseIfNeeded()
            }
            // Refresh a fix so pickup reflects the new accuracy band.
            manager.requestLocation()
        }
    }

    /// Rider tapped “Improve accuracy” — ask iOS for temporary full accuracy when reduced.
    func requestPreciseLocationUpgrade() {
        prefersPrecise = true
        applyAccuracy()
        requestTemporaryPreciseIfNeeded()
        if isAuthorized {
            manager.requestLocation()
        }
    }

    func startUpdatingIfAllowed() {
        locationServicesEnabled = CLLocationManager.locationServicesEnabled()
        guard locationServicesEnabled else {
            isUpdating = false
            lastErrorMessage = "Location Services are turned off on this device."
            return
        }
        let status = manager.authorizationStatus
        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            isUpdating = false
            return
        }
        applyAccuracy()
        manager.startUpdatingLocation()
        isUpdating = true
        lastErrorMessage = nil
        requestTemporaryPreciseIfNeeded()
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        isUpdating = false
    }

    /// One-shot refresh used after Settings returns or when the rider adjusts privacy.
    func refreshCurrentLocation() {
        guard isAuthorized, locationServicesEnabled else { return }
        applyAccuracy()
        requestTemporaryPreciseIfNeeded()
        manager.requestLocation()
    }

    private func applyAccuracy() {
        if prefersPrecise {
            manager.desiredAccuracy = kCLLocationAccuracyBest
            manager.distanceFilter = 8
        } else {
            manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
            manager.distanceFilter = 50
        }
    }

    private func requestTemporaryPreciseIfNeeded() {
        guard prefersPrecise, isAuthorized else { return }
        guard manager.accuracyAuthorization == .reducedAccuracy else { return }
        manager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: "PickupAccuracy")
    }

    private func isAcceptableFix(_ location: CLLocation) -> Bool {
        let age = -location.timestamp.timeIntervalSinceNow
        guard age >= 0, age <= maxLocationAgeSeconds else { return false }
        // negative horizontalAccuracy means invalid
        guard location.horizontalAccuracy >= 0 else { return false }
        if prefersPrecise {
            return location.horizontalAccuracy <= maxAcceptableAccuracyMeters
        }
        return location.horizontalAccuracy <= max(maxAcceptableAccuracyMeters, 1_000)
    }
}

extension RiderLocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorization = manager.authorizationStatus
            accuracyAuthorization = manager.accuracyAuthorization
            locationServicesEnabled = CLLocationManager.locationServicesEnabled()
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                lastErrorMessage = nil
                startUpdatingIfAllowed()
            case .denied, .restricted:
                stopUpdating()
                lastErrorMessage = "Location access is off. Turn it on in Settings to set your pickup."
            case .notDetermined:
                stopUpdating()
            @unknown default:
                break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            accuracyAuthorization = manager.accuracyAuthorization
            guard isAcceptableFix(location) else {
                // Keep waiting for a usable fix; surface guidance only when we have none yet.
                if latestLocation == nil {
                    lastErrorMessage = "Waiting for a clearer GPS fix. Move somewhere with a better sky view."
                }
                return
            }
            latestLocation = location
            lastErrorMessage = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            if let clError = error as? CLError {
                switch clError.code {
                case .denied:
                    lastErrorMessage = "Location access is off. Turn it on in Settings to set your pickup."
                    stopUpdating()
                case .locationUnknown:
                    lastErrorMessage = "Waiting for a GPS fix. Move somewhere with a clearer sky view."
                case .network:
                    lastErrorMessage = "Location is temporarily unavailable. Check your connection."
                default:
                    lastErrorMessage = "Could not read your current location."
                }
            } else {
                lastErrorMessage = "Could not read your current location."
            }
        }
    }
}
