# iOS source — Raide

SwiftUI target under `ios/Raide/`.

## Open on a Mac / Codemagic

1. Open `ios/Raide.xcodeproj`
2. Resolve SPM packages (ComponentsKit + Google Maps SDK)
3. Set `RAIDE_GOOGLE_MAPS_API_KEY` in the Raide scheme (optional for placeholder map)
4. Run on simulator or device

## Module map

| Folder | Role |
|--------|------|
| App/ | Entry + root navigation |
| Models/ | Trip domain types |
| Services/ | `TripSession` state machine |
| Mock/ | Demo places, drivers, fares |
| Maps/ | Google Maps bootstrap + UIKit map view |
| UI/ | Theme, glass, chrome, UIKit bridges, flow scaffolds |

See [docs/UI_COMPONENTS.md](../docs/UI_COMPONENTS.md) for SwiftUI / UIKit / ComponentsKit / Explore SwiftUI.

New `.swift` files must be registered in `Raide.xcodeproj/project.pbxproj`.
