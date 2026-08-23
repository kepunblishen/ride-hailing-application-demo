# UI Components — Raide

## Stack (same framework idea as Wells)

| Layer | What | Notes |
|-------|------|--------|
| **SwiftUI** | All screens / layout | Built into iOS — no extra package |
| **UIKit** | Maps + system share sheet | Via `UIViewRepresentable` / `UIViewControllerRepresentable` |
| **ComponentsKit** (SPM) | Optional accent theming + reference | Linked like Wells; primary UI is still native SwiftUI |
| **Explore SwiftUI** | Copy-paste patterns | Not a package — [exploreswiftui.com/latest](https://exploreswiftui.com/latest) |
| **Google Maps** (SPM) | Map surface | Raide-specific (not in Wells) |

SwiftUI and UIKit ship with the iOS SDK. You do **not** install them separately.

---

## In-house Raide design system

| File | Role |
|------|------|
| `UI/Theme/RaideTheme.swift` | Colors, page helpers, ComponentsKit accent bootstrap |
| `UI/Components/RaideGlass.swift` | Liquid Glass / material surfaces (`raideGlassSurface`) |
| `UI/Components/RaideChrome.swift` | Primary buttons + bottom sheet chrome |
| `UI/Components/RaideUIKitBridge.swift` | Share sheet bridge |
| `Maps/RaideMapView.swift` | Google Maps `UIViewRepresentable` |

---

## ComponentsKit

**Repo:** [github.com/componentskit/ComponentsKit](https://github.com/componentskit/ComponentsKit)

- Resolved in `Raide.xcodeproj` (same as Wells)
- `RaideTheme.configureComponentsKit()` runs at app launch
- Prefer **native SwiftUI + Raide\* components** for screens; use ComponentsKit only when a control is genuinely useful

---

## Explore SwiftUI

Not compiled in. When you want a Liquid Glass / sheet / list pattern:

1. Grab the snippet from Explore SwiftUI
2. Drop it into `UI/Flow/` or `UI/Components/`
3. Register the file in `project.pbxproj`
