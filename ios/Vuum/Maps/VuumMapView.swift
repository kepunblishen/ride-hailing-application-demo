import SwiftUI
import UIKit

#if canImport(GoogleMaps)
import GoogleMaps
#endif

struct VuumMapView: UIViewRepresentable {
    var cameraTarget: GeoPoint
    var zoom: Float = 14
    var pins: [MapPin] = []
    var route: [GeoPoint] = []
    var fitCoordinates: [GeoPoint] = []
    var followDriver: Bool = false
    /// When this value changes, the camera re-animates to `cameraTarget` (Home recenter).
    var cameraFocusNonce: Int = 0
    /// Shows the Google Maps “my location” control (default off — sheets cover the corner).
    var showsMyLocationButton: Bool = false
    /// Extra map padding so markers/routes stay above bottom sheets.
    var contentPadding: EdgeInsets = EdgeInsets(top: 24, leading: 16, bottom: 220, trailing: 16)
    var showsTraffic: Bool = true
    /// Lite / low-data: prefer simpler basemap styling and thinner polylines.
    var lowDataMode: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        #if canImport(GoogleMaps)
        if MapBootstrap.isConfigured {
            let map = GMSMapView(
                frame: .zero,
                camera: GMSCameraPosition.camera(
                    withLatitude: cameraTarget.latitude,
                    longitude: cameraTarget.longitude,
                    zoom: zoom
                )
            )
            map.isMyLocationEnabled = true
            map.settings.myLocationButton = showsMyLocationButton
            map.settings.compassButton = false
            map.isTrafficEnabled = showsTraffic
            map.mapType = lowDataMode ? .normal : .normal
            map.padding = uiEdgeInsets(from: contentPadding)
            Self.applyOptionalBrandMapStyle(to: map, lowDataMode: lowDataMode)
            context.coordinator.mapView = map
            return map
        }
        #endif
        return MapPlaceholderView(frame: .zero)
    }

    /// Prep hook for Uber-like styled tiles: drop `VuumMapStyle.json` in the app bundle
    /// (Google Maps JSON style). No-op until that resource exists — default Google basemap.
    #if canImport(GoogleMaps)
    private static func applyOptionalBrandMapStyle(to map: GMSMapView, lowDataMode: Bool) {
        let resourceName = lowDataMode ? "VuumMapStyleLite" : "VuumMapStyle"
        guard let url = Bundle.main.url(forResource: resourceName, withExtension: "json")
            ?? Bundle.main.url(forResource: "VuumMapStyle", withExtension: "json"),
              let style = try? GMSMapStyle(contentsOfFileURL: url)
        else { return }
        map.mapStyle = style
    }
    #endif

    func updateUIView(_ uiView: UIView, context: Context) {
        #if canImport(GoogleMaps)
        guard let map = uiView as? GMSMapView else { return }
        map.settings.myLocationButton = showsMyLocationButton
        map.padding = uiEdgeInsets(from: contentPadding)
        map.isTrafficEnabled = showsTraffic
        context.coordinator.sync(
            map: map,
            pins: pins,
            route: route,
            fitCoordinates: fitCoordinates,
            cameraTarget: cameraTarget,
            zoom: zoom,
            followDriver: followDriver,
            cameraFocusNonce: cameraFocusNonce,
            lowDataMode: lowDataMode
        )
        #endif
    }

    private func uiEdgeInsets(from insets: EdgeInsets) -> UIEdgeInsets {
        UIEdgeInsets(
            top: insets.top,
            left: insets.leading,
            bottom: insets.bottom,
            right: insets.trailing
        )
    }

    final class Coordinator {
        #if canImport(GoogleMaps)
        weak var mapView: GMSMapView?
        private var markers: [String: GMSMarker] = [:]
        private var polyline: GMSPolyline?
        private var lastFitSignature: String = ""
        private var didInitialCamera = false
        private var lastCameraFocusNonce: Int = 0

        func sync(
            map: GMSMapView,
            pins: [MapPin],
            route: [GeoPoint],
            fitCoordinates: [GeoPoint],
            cameraTarget: GeoPoint,
            zoom: Float,
            followDriver: Bool,
            cameraFocusNonce: Int,
            lowDataMode: Bool = false
        ) {
            let ids = Set(pins.map(\.id))
            for key in markers.keys where !ids.contains(key) {
                markers[key]?.map = nil
                markers.removeValue(forKey: key)
            }

            for pin in pins {
                let marker = markers[pin.id] ?? GMSMarker()
                marker.position = pin.coordinate.coordinate
                marker.groundAnchor = CGPoint(x: 0.5, y: 0.5)
                marker.icon = icon(for: pin)
                marker.rotation = pin.kind == .driver || pin.kind == .nearby ? pin.heading : 0
                marker.flat = pin.kind == .driver || pin.kind == .nearby
                marker.map = map
                markers[pin.id] = marker
            }

            polyline?.map = nil
            if route.count >= 2 {
                let path = GMSMutablePath()
                for point in route {
                    path.add(point.coordinate)
                }
                let line = GMSPolyline(path: path)
                line.strokeColor = UIColor(red: 245 / 255, green: 165 / 255, blue: 36 / 255, alpha: 1)
                line.strokeWidth = lowDataMode ? 3.5 : 5
                line.map = map
                polyline = line
            } else {
                polyline = nil
            }

            if fitCoordinates.count >= 2 {
                let signature = fitCoordinates
                    .map { "\($0.latitude),\($0.longitude)" }
                    .joined(separator: "|")
                if signature != lastFitSignature {
                    lastFitSignature = signature
                    var bounds = GMSCoordinateBounds()
                    for point in fitCoordinates {
                        bounds = bounds.includingCoordinate(point.coordinate)
                    }
                    let update = GMSCameraUpdate.fit(bounds, withPadding: 64)
                    map.animate(with: update)
                } else if followDriver {
                    let camera = GMSCameraPosition.camera(
                        withLatitude: cameraTarget.latitude,
                        longitude: cameraTarget.longitude,
                        zoom: max(map.camera.zoom, 14)
                    )
                    map.animate(to: camera)
                }
            } else if followDriver {
                let camera = GMSCameraPosition.camera(
                    withLatitude: cameraTarget.latitude,
                    longitude: cameraTarget.longitude,
                    zoom: max(map.camera.zoom, 15)
                )
                map.animate(to: camera)
            } else if cameraFocusNonce != lastCameraFocusNonce {
                lastCameraFocusNonce = cameraFocusNonce
                let camera = GMSCameraPosition.camera(
                    withLatitude: cameraTarget.latitude,
                    longitude: cameraTarget.longitude,
                    zoom: zoom
                )
                map.animate(to: camera)
            } else if !didInitialCamera {
                didInitialCamera = true
                let camera = GMSCameraPosition.camera(
                    withLatitude: cameraTarget.latitude,
                    longitude: cameraTarget.longitude,
                    zoom: zoom
                )
                map.animate(to: camera)
            }
        }

        private func icon(for pin: MapPin) -> UIImage {
            switch pin.kind {
            case .pickup:
                return circleIcon(color: UIColor.systemGreen, diameter: 18)
            case .stop:
                return circleIcon(color: UIColor(red: 245 / 255, green: 165 / 255, blue: 36 / 255, alpha: 1), diameter: 16)
            case .dropoff:
                return circleIcon(color: UIColor(red: 15 / 255, green: 20 / 255, blue: 25 / 255, alpha: 1), diameter: 18)
            case .driver:
                return vehicleIcon(
                    color: UIColor(red: 245 / 255, green: 165 / 255, blue: 36 / 255, alpha: 1),
                    size: 34,
                    vehicleClass: pin.vehicleClass ?? .standard
                )
            case .nearby:
                return vehicleIcon(
                    color: UIColor.darkGray,
                    size: 26,
                    vehicleClass: pin.vehicleClass ?? .standard
                )
            }
        }

        private func circleIcon(color: UIColor, diameter: CGFloat) -> UIImage {
            let size = CGSize(width: diameter, height: diameter)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
                UIColor.white.setFill()
                UIBezierPath(ovalIn: CGRect(origin: .zero, size: size)).fill()
                color.setFill()
                UIBezierPath(ovalIn: rect).fill()
            }
        }

        private func vehicleIcon(color: UIColor, size: CGFloat, vehicleClass: VehicleClass) -> UIImage {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
            return renderer.image { _ in
                color.setFill()
                switch vehicleClass {
                case .bike:
                    let body = UIBezierPath(
                        roundedRect: CGRect(x: size * 0.28, y: size * 0.36, width: size * 0.44, height: size * 0.22),
                        cornerRadius: 3
                    )
                    body.fill()
                    UIBezierPath(ovalIn: CGRect(x: size * 0.18, y: size * 0.52, width: size * 0.22, height: size * 0.22)).fill()
                    UIBezierPath(ovalIn: CGRect(x: size * 0.60, y: size * 0.52, width: size * 0.22, height: size * 0.22)).fill()
                case .large:
                    let rect = CGRect(x: size * 0.12, y: size * 0.30, width: size * 0.76, height: size * 0.40)
                    UIBezierPath(roundedRect: rect, cornerRadius: 5).fill()
                    UIColor.white.setFill()
                    UIBezierPath(ovalIn: CGRect(x: size * 0.22, y: size * 0.40, width: size * 0.14, height: size * 0.14)).fill()
                    UIBezierPath(ovalIn: CGRect(x: size * 0.64, y: size * 0.40, width: size * 0.14, height: size * 0.14)).fill()
                case .standard:
                    let rect = CGRect(x: size * 0.2, y: size * 0.28, width: size * 0.6, height: size * 0.44)
                    UIBezierPath(roundedRect: rect, cornerRadius: 4).fill()
                    UIColor.white.setFill()
                    UIBezierPath(ovalIn: CGRect(x: size * 0.28, y: size * 0.38, width: size * 0.16, height: size * 0.16)).fill()
                    UIBezierPath(ovalIn: CGRect(x: size * 0.56, y: size * 0.38, width: size * 0.16, height: size * 0.16)).fill()
                }
            }
        }
        #endif
    }
}

/// Shown when Maps SDK is not configured (missing API key or package).
private final class MapPlaceholderView: UIView {
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.93, green: 0.94, blue: 0.95, alpha: 1)

        titleLabel.text = "Map unavailable"
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = UIColor(white: 0.25, alpha: 1)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        subtitleLabel.text = "Add Maps API key"
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .medium)
        subtitleLabel.textColor = UIColor(white: 0.45, alpha: 1)
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false

        addSubview(titleLabel)
        addSubview(subtitleLabel)
        NSLayoutConstraint.activate([
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -10),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            subtitleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            subtitleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
