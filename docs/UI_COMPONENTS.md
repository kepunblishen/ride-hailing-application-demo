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
| `UI/Theme/VuumTheme.swift` | `VuumColor`, `VuumLayout`, `VuumType`, page helpers, ComponentsKit accent bootstrap |
| `UI/Components/VuumGlass.swift` | Restrained material surfaces (`VuumGlassSurface` panel / quiet) |
| `UI/Components/VuumChrome.swift` | Primary/secondary buttons, sheet chrome, hub primitives |
| `UI/Components/VuumUIKitBridge.swift` | Share sheet bridge |
| `Maps/VuumMapView.swift` | Google Maps `UIViewRepresentable` |

### Shared hub primitives

Use these across Home / Services / Activity / Account / Payments so screens share one visual language:

| Component | Use |
|-----------|-----|
| `VuumSectionHeader` | Section titles on hubs |
| `VuumIconBadge` | Brand-tinted icon tiles in lists/grids |
| `VuumHubCard` | Solid grouped cards (prefer over frosted glass on hubs) |
| `VuumFilterChip` | Segmented time/product filters |
| `VuumOfferBadge` | Restrained promo pills (brand amber, not red stickers) |
| `VuumHubRowLabel` | Icon + title + subtitle rows |
| `VuumSheetHandle` / `VuumSheetChrome` | Map-overlaid trip sheets |
| `VuumPressStyle` | Shared press feedback |
| `VuumPrimaryButton` | Brand CTA (rounded rect — not giant capsules everywhere) |

### Design intent (directive §60–61 / Phase 10)

- Keep brand amber `#F5A524` — do not invent a new palette
- Map-first hierarchy; restrained sheets; solid cards on hubs
- Avoid excessive frosted glass, huge gradients, and oversized display type
- No “demo” badges in user-visible UI

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
