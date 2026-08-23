import SwiftUI
import UIKit

#if canImport(GoogleMaps)
import GoogleMaps
#endif

/// Map surface for the demo. Shows Google Maps when configured; otherwise a branded placeholder.
struct RaideMapView: UIViewRepresentable {
    var cameraTarget: GeoPoint
    var zoom: Float = 14

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
            return map
        }
        #endif
        return MapPlaceholderView(frame: .zero)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        #if canImport(GoogleMaps)
        guard let map = uiView as? GMSMapView else { return }
        let camera = GMSCameraPosition.camera(
            withLatitude: cameraTarget.latitude,
            longitude: cameraTarget.longitude,
            zoom: zoom
        )
        map.animate(to: camera)
        #endif
    }
}

private final class MapPlaceholderView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.09, green: 0.11, blue: 0.13, alpha: 1)
        let label = UILabel()
        label.text = "Map placeholder\nAdd Google Maps key to go live"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.textColor = UIColor(white: 0.75, alpha: 1)
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
}
