# UI Components — Vuum

## Stack (same framework idea as Wells)

| Layer | What | Notes |
|-------|------|--------|
| **SwiftUI** | All screens / layout | Built into iOS — no extra package |
| **UIKit** | Maps + system share sheet | Via `UIViewRepresentable` / `UIViewControllerRepresentable` |
| **ComponentsKit** (SPM) | Optional accent theming + reference | Linked like Wells; primary UI is still native SwiftUI |
| **Explore SwiftUI** | Copy-paste patterns | Not a package — [exploreswiftui.com/latest](https://exploreswiftui.com/latest) |
| **Google Maps** (SPM) | Map surface | Vuum-specific (not in Wells) |

SwiftUI and UIKit ship with the iOS SDK. You do **not** install them separately.

---

## In-house Vuum design system

| File | Role |
|------|------|
| `UI/Theme/VuumTheme.swift` | Colors, page helpers, ComponentsKit accent bootstrap |
| `UI/Components/VuumGlass.swift` | Liquid Glass / material surfaces (`VuumGlassSurface`) |
| `UI/Components/VuumChrome.swift` | Primary buttons + bottom sheet chrome |
| `UI/Components/VuumUIKitBridge.swift` | Share sheet bridge |
| `Maps/VuumMapView.swift` | Google Maps `UIViewRepresentable` |

---

## ComponentsKit

**Repo:** [github.com/componentskit/ComponentsKit](https://github.com/componentskit/ComponentsKit)

- Resolved in `Vuum.xcodeproj` (same as Wells)
- `VuumTheme.configureComponentsKit()` runs at app launch
- Prefer **native SwiftUI + Vuum\* components** for screens; use ComponentsKit only when a control is genuinely useful

---

## Explore SwiftUI

Not compiled in. When you want a Liquid Glass / sheet / list pattern:

1. Grab the snippet from Explore SwiftUI
2. Drop it into `UI/Flow/` or `UI/Components/`
3. Register the file in `project.pbxproj`
