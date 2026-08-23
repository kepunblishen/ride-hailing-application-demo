import Combine
import CoreLocation
import Foundation

@MainActor
final class RiderLocationManager: NSObject, ObservableObject {
    @Published private(set) var authorization: CLAuthorizationStatus
    @Published private(set) var latestLocation: CLLocation?
    @Published private(set) var locationServicesEnabled: Bool
    @Published private(set) var lastErrorMessage: String?
    @Published private(set) var isUpdating = false

    private let manager = CLLocationManager()
    private var prefersPrecise = true

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

    var canProvidePickup: Bool {
        isAuthorized && locationServicesEnabled
    }

    override init() {
        authorization = manager.authorizationStatus
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
            // Refresh a fix so pickup reflects the new accuracy band.
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
    }

    func stopUpdating() {
        manager.stopUpdatingLocation()
        isUpdating = false
    }

    /// One-shot refresh used after Settings returns or when the rider adjusts privacy.
    func refreshCurrentLocation() {
        guard isAuthorized, locationServicesEnabled else { return }
        applyAccuracy()
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
}

extension RiderLocationManager: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorization = manager.authorizationStatus
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
