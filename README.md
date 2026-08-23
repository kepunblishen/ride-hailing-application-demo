# Vuum — Ride Hailing Demo (iOS)

Client demo of a rider-facing Uber/Bolt-style experience. See [PROJECT.md](PROJECT.md) for product scope.

## What’s in the repo

| Path | Purpose |
|------|---------|
| `ios/Vuum.xcodeproj` | Xcode project (iOS 17+, SwiftUI + UIKit bridges) |
| `ios/Vuum/` | App sources, mock trip layer, map shell, App Icon, design system |
| `codemagic.yaml` | Unsigned IPA build for Sideloadly |
| `docs/` | Architecture, setup, Codemagic, UI components |
| `reference/` | ComponentsKit + Explore SwiftUI lookup notes |

## UI / package framework

| Piece | Source |
|-------|--------|
| SwiftUI | System (all screens) |
| UIKit | System (maps + share sheet bridges) |
| ComponentsKit | SPM (same as Wells) |
| Google Maps | SPM (Vuum demo maps) |
| Explore SwiftUI | Snippet reference — not a package |

## Architecture note

Folder layout, classic Xcode registration, Codemagic unsigned packaging, ComponentsKit link, and glass/design-system patterns follow the Wells Gas Monitor **infrastructure**. No Wells screens, auth, BLE, or Firebase.

## Quick start

1. Open `ios/Vuum.xcodeproj` (Mac) or push to Codemagic
2. Resolve SPM (ComponentsKit + Google Maps)
3. Optionally set `VUUM_GOOGLE_MAPS_API_KEY`
4. Run: Home → destination → ride tier → searching → assigned → trip → complete

## Temporary

`Wells-Gas-Level-Monitor-main/` is a reference copy used only for scaffolding. Delete it once you’re satisfied the Vuum base is complete.
