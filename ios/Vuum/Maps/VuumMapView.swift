import SwiftUI
import UIKit

#if canImport(GoogleMaps)
import GoogleMaps
#endif

struct VuumMapView: UIViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme

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
    /// Blue-dot user location — enable only when Core Location is authorized.
    var showsUserLocation: Bool = false
    /// Extra map padding so markers/routes stay above bottom sheets.
    var contentPadding: EdgeInsets = EdgeInsets(top: 24, leading: 16, bottom: 220, trailing: 16)
    var showsTraffic: Bool = false
    /// Lite / low-data: prefer simpler basemap styling and thinner polylines.
    var lowDataMode: Bool = false

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIView {
        // Ensure key resolution ran even if this representable is created before `VuumApp.init`.
        MapBootstrap.configureIfNeeded()
        #if canImport(GoogleMaps)
        if MapBootstrap.isConfigured {
            // Google docs: configure via GMSMapViewOptions (frame/camera/backgroundColor),
            // then GMSMapView(options:). CGRectZero is OK when the map is the VC's only
            // view; under SwiftUI UIViewRepresentable a non-zero initial frame + flexible
            // autoresizing avoids a blank Metal/tile surface until the first layout pass.
            let options = GMSMapViewOptions()
            options.camera = GMSCameraPosition.camera(
                withLatitude: cameraTarget.latitude,
                longitude: cameraTarget.longitude,
                zoom: zoom
            )
            let screenBounds = UIScreen.main.bounds
            options.frame = CGRect(origin: .zero, size: screenBounds.size)
            options.backgroundColor = UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(red: 0.11, green: 0.13, blue: 0.16, alpha: 1)
                    : UIColor(red: 0.90, green: 0.91, blue: 0.93, alpha: 1)
            }

            let map = GMSMapView(options: options)
            map.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            map.isMyLocationEnabled = showsUserLocation
            map.settings.myLocationButton = showsMyLocationButton
            map.settings.compassButton = false
            map.isTrafficEnabled = showsTraffic
            map.mapType = .normal
            map.padding = uiEdgeInsets(from: contentPadding)
            map.delegate = context.coordinator
            map.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light
            context.coordinator.applyBrandMapStyleIfNeeded(
                to: map,
                lowDataMode: lowDataMode,
                colorScheme: colorScheme,
                force: true
            )
            context.coordinator.mapView = map
            return map
        }
        #endif
        let placeholder = MapPlaceholderView(frame: UIScreen.main.bounds)
        placeholder.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return placeholder
    }

    /// Expand to the proposed container so ZStack + sheet scaffolds never leave the map at 0×0.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UIView, context: Context) -> CGSize? {
        let fallback = UIScreen.main.bounds.size
        return proposal.replacingUnspecifiedDimensions(by: fallback)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let placeholder = uiView as? MapPlaceholderView {
            placeholder.refreshCopy()
            return
        }
        #if canImport(GoogleMaps)
        guard let map = uiView as? GMSMapView else { return }
        map.isMyLocationEnabled = showsUserLocation
        map.settings.myLocationButton = showsMyLocationButton
        map.padding = uiEdgeInsets(from: contentPadding)
        map.isTrafficEnabled = showsTraffic
        context.coordinator.applyBrandMapStyleIfNeeded(
            to: map,
            lowDataMode: lowDataMode,
            colorScheme: colorScheme,
            force: false
        )
        context.coordinator.sync(
            map: map,
            pins: pins,
            route: route,
            fitCoordinates: fitCoordinates,
            cameraTarget: cameraTarget,
            zoom: zoom,
            followDriver: followDriver,
            cameraFocusNonce: cameraFocusNonce,
            contentPadding: uiEdgeInsets(from: contentPadding),
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

    final class Coordinator: NSObject {
        #if canImport(GoogleMaps)
        weak var mapView: GMSMapView?
        private var markers: [String: GMSMarker] = [:]
        private var polyline: GMSPolyline?
        private var lastFitSignature: String = ""
        private var lastRouteSignature: String = ""
        private var didInitialCamera = false
        private var lastCameraFocusNonce: Int = 0
        private var lastFollowSampleAt: CFTimeInterval = 0
        private var lastAppliedStyleResource: String?
        private var renderedHeadings: [String: Double] = [:]
        private var iconCache: [String: UIImage] = [:]
        /// True after the rider pans/zooms; cleared on programmatic recenter / fit.
        fileprivate var userAdjustedCamera = false

        /// Quiet POI / day–night basemap styles from bundle JSON. Requires a configured Maps key.
        func applyBrandMapStyleIfNeeded(
            to map: GMSMapView,
            lowDataMode: Bool,
            colorScheme: ColorScheme,
            force: Bool
        ) {
            guard MapBootstrap.isConfigured, MapBootstrap.hasAPIKey else { return }
            map.overrideUserInterfaceStyle = colorScheme == .dark ? .dark : .light

            let resource = Self.styleResourceName(lowDataMode: lowDataMode, colorScheme: colorScheme)
            guard force || resource != lastAppliedStyleResource else { return }

            guard let url = Self.resolveStyleURL(named: resource) else {
                #if DEBUG
                print("[Vuum] Map style resource missing: \(resource).json — using default tiles.")
                #endif
                map.mapStyle = nil
                // Do not cache failure — allow retry once the bundle resource is available.
                return
            }
            do {
                map.mapStyle = try GMSMapStyle(contentsOfFileURL: url)
                lastAppliedStyleResource = resource
            } catch {
                #if DEBUG
                print("[Vuum] Map style failed (\(resource)): \(error.localizedDescription) — using default tiles.")
                #endif
                map.mapStyle = nil
            }
        }

        private static func styleResourceName(lowDataMode: Bool, colorScheme: ColorScheme) -> String {
            // Never apply light day/lite JSON under dark appearance — those sheets paint
            // roads `#ffffff` and read as a blank white map against dark chrome.
            switch (colorScheme, lowDataMode) {
            case (.dark, true): return "VuumMapStyleNightLite"
            case (.dark, false): return "VuumMapStyleNight"
            case (_, true): return "VuumMapStyleLite"
            case (_, false): return "VuumMapStyle"
            }
        }

        /// Resolve style JSON. Night styles must never fall back to the light day sheet.
        private static func resolveStyleURL(named resource: String) -> URL? {
            if let url = Bundle.main.url(forResource: resource, withExtension: "json") {
                return url
            }
            switch resource {
            case "VuumMapStyleNightLite":
                return Bundle.main.url(forResource: "VuumMapStyleNight", withExtension: "json")
            case "VuumMapStyleLite":
                return Bundle.main.url(forResource: "VuumMapStyle", withExtension: "json")
            default:
                return nil
            }
        }

        func sync(
            map: GMSMapView,
            pins: [MapPin],
            route: [GeoPoint],
            fitCoordinates: [GeoPoint],
            cameraTarget: GeoPoint,
            zoom: Float,
            followDriver: Bool,
            cameraFocusNonce: Int,
            contentPadding: UIEdgeInsets,
            lowDataMode: Bool = false
        ) {
            let followPin = pins.first(where: { $0.kind == .driver })
            syncPinLayers(map: map, pins: pins, animateVehicle: followDriver && followPin != nil)
            syncRoute(map: map, route: route, lowDataMode: lowDataMode)
            syncCamera(
                map: map,
                fitCoordinates: fitCoordinates,
                cameraTarget: cameraTarget,
                zoom: zoom,
                followDriver: followDriver,
                followHeading: followPin.map { renderedHeadings[$0.id] ?? $0.heading },
                cameraFocusNonce: cameraFocusNonce,
                contentPadding: contentPadding
            )
        }

        // MARK: - Pin layers

        private func syncPinLayers(map: GMSMapView, pins: [MapPin], animateVehicle: Bool) {
            let ids = Set(pins.map(\.id))
            for key in markers.keys where !ids.contains(key) {
                markers[key]?.map = nil
                markers.removeValue(forKey: key)
                renderedHeadings.removeValue(forKey: key)
            }

            // Draw order: nearby → stop → pickup/dropoff → driver (zIndex).
            let ordered = pins.sorted { lhs, rhs in
                pinZIndex(lhs.kind) < pinZIndex(rhs.kind)
            }

            CATransaction.begin()
            CATransaction.setDisableActions(!animateVehicle)
            if animateVehicle {
                // Match TripSession's ~80 ms motion tick so the marker eases along the polyline.
                CATransaction.setAnimationDuration(0.085)
                CATransaction.setAnimationTimingFunction(
                    CAMediaTimingFunction(name: .linear)
                )
            }

            for pin in ordered {
                let isVehicle = pin.kind == .driver || pin.kind == .nearby
                let marker = markers[pin.id] ?? GMSMarker()
                let isNew = markers[pin.id] == nil
                marker.position = pin.coordinate.coordinate
                marker.groundAnchor = groundAnchor(for: pin.kind)
                marker.icon = icon(for: pin)
                marker.zIndex = pinZIndex(pin.kind)
                marker.title = pinTitle(for: pin)
                // Static UIImage icons — avoid per-frame iconView re-rasterization.
                marker.tracksViewChanges = false
                if isVehicle {
                    let previous = renderedHeadings[pin.id] ?? pin.heading
                    let smoothed = isNew
                        ? pin.heading
                        : TripGeo.lerpHeading(from: previous, to: pin.heading, fraction: 0.55)
                    renderedHeadings[pin.id] = smoothed
                    // Flat + center anchor: rotation is degrees clockwise from north (Maps SDK).
                    marker.rotation = smoothed
                    marker.isFlat = true
                    marker.opacity = pin.kind == .nearby ? 0.94 : 1.0
                } else {
                    marker.rotation = 0
                    marker.isFlat = false
                    marker.opacity = 1.0
                }
                marker.map = map
                markers[pin.id] = marker
            }

            CATransaction.commit()
        }

        private func pinZIndex(_ kind: MapPinKind) -> Int32 {
            // Nearby under stops/anchors; assigned driver above route + place pins.
            switch kind {
            case .nearby: return 12
            case .stop: return 20
            case .pickup: return 30
            case .dropoff: return 40
            case .driver: return 60
            }
        }

        private func groundAnchor(for kind: MapPinKind) -> CGPoint {
            switch kind {
            case .pickup, .dropoff, .stop:
                return CGPoint(x: 0.5, y: 1.0)
            case .driver, .nearby:
                return CGPoint(x: 0.5, y: 0.5)
            }
        }

        private func pinTitle(for pin: MapPin) -> String {
            switch pin.kind {
            case .pickup: return "Pickup"
            case .dropoff: return "Drop-off"
            case .stop: return "Stop"
            case .driver: return "Your driver"
            case .nearby: return "Nearby vehicle"
            }
        }

        // MARK: - Route

        private func syncRoute(map: GMSMapView, route: [GeoPoint], lowDataMode: Bool) {
            let signature: String
            if route.count >= 2 {
                // Coarse signature so micro progress updates don't rebuild the GMS path every frame.
                let head = route[0]
                let mid = route[route.count / 2]
                let tail = route[route.count - 1]
                signature = String(
                    format: "%d|%.5f,%.5f|%.5f,%.5f|%.5f,%.5f|%@",
                    route.count,
                    head.latitude, head.longitude,
                    mid.latitude, mid.longitude,
                    tail.latitude, tail.longitude,
                    lowDataMode ? "lite" : "full"
                )
            } else {
                signature = lowDataMode ? "empty|lite" : "empty"
            }

            if signature == lastRouteSignature, polyline != nil || route.count < 2 {
                if let line = polyline {
                    line.strokeWidth = lowDataMode ? 3.5 : 5
                }
                return
            }
            lastRouteSignature = signature

            polyline?.map = nil
            if route.count >= 2 {
                let path = GMSMutablePath()
                for point in route {
                    path.add(point.coordinate)
                }
                let line = GMSPolyline(path: path)
                line.strokeColor = UIColor(red: 245 / 255, green: 165 / 255, blue: 36 / 255, alpha: 1)
                line.strokeWidth = lowDataMode ? 3.5 : 5
                line.zIndex = 5
                line.map = map
                polyline = line
            } else {
                polyline = nil
            }
        }

        // MARK: - Camera

        private func syncCamera(
            map: GMSMapView,
            fitCoordinates: [GeoPoint],
            cameraTarget: GeoPoint,
            zoom: Float,
            followDriver: Bool,
            followHeading: Double?,
            cameraFocusNonce: Int,
            contentPadding: UIEdgeInsets
        ) {
            let focusRequested = cameraFocusNonce != lastCameraFocusNonce
            if focusRequested {
                lastCameraFocusNonce = cameraFocusNonce
                userAdjustedCamera = false
            }

            if fitCoordinates.count >= 2 {
                let signature = fitCoordinates
                    .map { String(format: "%.5f,%.5f", $0.latitude, $0.longitude) }
                    .joined(separator: "|")

                if signature != lastFitSignature || focusRequested {
                    lastFitSignature = signature
                    userAdjustedCamera = false
                    var bounds = GMSCoordinateBounds()
                    for point in fitCoordinates {
                        bounds = bounds.includingCoordinate(point.coordinate)
                    }
                    // Edge insets keep pins clear of sheet chrome (map.padding alone is not enough for fit).
                    let insets = UIEdgeInsets(
                        top: max(contentPadding.top, 48) + 24,
                        left: max(contentPadding.left, 24) + 16,
                        bottom: max(contentPadding.bottom, 48) + 24,
                        right: max(contentPadding.right, 24) + 16
                    )
                    let update = GMSCameraUpdate.fit(bounds, with: insets)
                    map.animate(with: update)
                } else if followDriver, !userAdjustedCamera {
                    animateFollow(
                        to: cameraTarget,
                        zoom: max(map.camera.zoom, 14),
                        bearing: followHeading,
                        on: map
                    )
                }
            } else {
                if !lastFitSignature.isEmpty {
                    lastFitSignature = ""
                }

                if followDriver, !userAdjustedCamera {
                    animateFollow(
                        to: cameraTarget,
                        zoom: max(map.camera.zoom, 15),
                        bearing: followHeading,
                        on: map
                    )
                } else if focusRequested {
                    animateTo(cameraTarget, zoom: zoom, on: map)
                } else if !didInitialCamera {
                    didInitialCamera = true
                    animateTo(cameraTarget, zoom: zoom, on: map)
                }
            }
        }

        private func animateFollow(
            to target: GeoPoint,
            zoom: Float,
            bearing: Double?,
            on map: GMSMapView
        ) {
            let now = CACurrentMediaTime()
            guard now - lastFollowSampleAt >= 0.12 else { return }
            lastFollowSampleAt = now
            let camera = GMSCameraPosition.camera(
                withLatitude: target.latitude,
                longitude: target.longitude,
                zoom: zoom,
                bearing: bearing ?? map.camera.bearing,
                viewingAngle: 0
            )
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.2)
            map.animate(to: camera)
            CATransaction.commit()
        }

        private func animateTo(_ target: GeoPoint, zoom: Float, on map: GMSMapView) {
            let camera = GMSCameraPosition.camera(
                withLatitude: target.latitude,
                longitude: target.longitude,
                zoom: zoom
            )
            map.animate(to: camera)
        }

        // MARK: - Icons

        private func icon(for pin: MapPin) -> UIImage {
            let cacheKey: String
            switch pin.kind {
            case .pickup:
                cacheKey = "pickup"
            case .stop:
                cacheKey = "stop"
            case .dropoff:
                cacheKey = "dropoff"
            case .driver:
                cacheKey = "driver-\(pin.vehicleClass ?? .standard)"
            case .nearby:
                cacheKey = "nearby-\(pin.vehicleClass ?? .standard)"
            }
            if let cached = iconCache[cacheKey] { return cached }

            let image: UIImage
            switch pin.kind {
            case .pickup:
                image = teardropIcon(
                    fill: UIColor(red: 34 / 255, green: 160 / 255, blue: 90 / 255, alpha: 1),
                    diameter: 22
                )
            case .stop:
                image = teardropIcon(
                    fill: UIColor(red: 245 / 255, green: 165 / 255, blue: 36 / 255, alpha: 1),
                    diameter: 18
                )
            case .dropoff:
                image = teardropIcon(
                    fill: UIColor(red: 15 / 255, green: 20 / 255, blue: 25 / 255, alpha: 1),
                    diameter: 22
                )
            case .driver:
                // Top-down fleet glyph (nose = north). Flat + rotation apply heading.
                image = VehicleMapMarkerIcon.image(
                    vehicleClass: pin.vehicleClass ?? .standard,
                    role: .assigned,
                    pointSize: 44
                )
            case .nearby:
                image = VehicleMapMarkerIcon.image(
                    vehicleClass: pin.vehicleClass ?? .standard,
                    role: .nearby,
                    pointSize: 34
                )
            }
            iconCache[cacheKey] = image
            return image
        }

        /// Pointed marker so the tip sits on the coordinate (Uber-style pickup / drop-off).
        private func teardropIcon(fill: UIColor, diameter: CGFloat) -> UIImage {
            let stem: CGFloat = diameter * 0.55
            let size = CGSize(width: diameter, height: diameter + stem)
            let renderer = UIGraphicsImageRenderer(size: size)
            return renderer.image { _ in
                let circle = CGRect(x: 0, y: 0, width: diameter, height: diameter).insetBy(dx: 1, dy: 1)
                let tip = CGPoint(x: diameter / 2, y: size.height - 1)

                let path = UIBezierPath()
                path.move(to: tip)
                path.addLine(to: CGPoint(x: diameter * 0.22, y: diameter * 0.72))
                path.addArc(
                    withCenter: CGPoint(x: diameter / 2, y: diameter / 2),
                    radius: diameter / 2 - 1,
                    startAngle: .pi * 0.85,
                    endAngle: .pi * 0.15,
                    clockwise: true
                )
                path.close()

                UIColor.white.setFill()
                path.fill()

                fill.setFill()
                UIBezierPath(ovalIn: circle).fill()

                UIColor.white.setFill()
                let inner = circle.insetBy(dx: diameter * 0.28, dy: diameter * 0.28)
                UIBezierPath(ovalIn: inner).fill()
            }
        }
        #endif
    }
}

#if canImport(GoogleMaps)
extension VuumMapView.Coordinator: GMSMapViewDelegate {
    func mapView(_ mapView: GMSMapView, willMove gesture: Bool) {
        if gesture {
            userAdjustedCamera = true
        }
    }
}
#endif

/// Rider-facing map plane when Maps SDK is not configured (missing/unusable key or package).
/// Product copy only — no API-key / config / “demo” language.
private final class MapPlaceholderView: UIView {
    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let stack = UIStackView()
    private let gridLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        clipsToBounds = true
        backgroundColor = UIColor { traits in
            if traits.userInterfaceStyle == .dark {
                return UIColor(red: 0.14, green: 0.16, blue: 0.18, alpha: 1)
            }
            return UIColor(red: 0.92, green: 0.93, blue: 0.94, alpha: 1)
        }

        gridLayer.fillColor = UIColor.clear.cgColor
        gridLayer.lineWidth = 1
        layer.insertSublayer(gridLayer, at: 0)
        updateGridStrokeColor()

        let symbol = UIImage(
            systemName: "map",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .semibold)
        )
        iconView.image = symbol
        iconView.tintColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.72, alpha: 1)
                : UIColor(white: 0.38, alpha: 1)
        }
        iconView.contentMode = .scaleAspectFit
        iconView.setContentHuggingPriority(.required, for: .vertical)

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.92, alpha: 1)
                : UIColor(white: 0.22, alpha: 1)
        }
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        subtitleLabel.font = .systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 0.68, alpha: 1)
                : UIColor(white: 0.42, alpha: 1)
        }
        subtitleLabel.textAlignment = .center
        subtitleLabel.numberOfLines = 0

        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(iconView)
        stack.addArrangedSubview(titleLabel)
        stack.addArrangedSubview(subtitleLabel)
        stack.setCustomSpacing(14, after: iconView)

        addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32),
            iconView.widthAnchor.constraint(equalToConstant: 36),
            iconView.heightAnchor.constraint(equalToConstant: 36),
        ])

        isAccessibilityElement = true
        accessibilityTraits = .staticText
        refreshCopy()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        gridLayer.frame = bounds
        let path = UIBezierPath()
        let step: CGFloat = 28
        var x: CGFloat = 0
        while x <= bounds.width {
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: bounds.height))
            x += step
        }
        var y: CGFloat = 0
        while y <= bounds.height {
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: bounds.width, y: y))
            y += step
        }
        gridLayer.path = path.cgPath
    }

    func refreshCopy() {
        titleLabel.text = L10n.Maps.unavailableTitle
        subtitleLabel.text = L10n.Maps.unavailableDetail
        accessibilityLabel = titleLabel.text
        accessibilityHint = subtitleLabel.text
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        updateGridStrokeColor()
    }

    private func updateGridStrokeColor() {
        let dark = traitCollection.userInterfaceStyle == .dark
        gridLayer.strokeColor = (dark ? UIColor.white.withAlphaComponent(0.06) : UIColor.black.withAlphaComponent(0.05)).cgColor
    }
}
