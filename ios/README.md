# iOS source — Vuum

SwiftUI target under `ios/Vuum/`.

## Open on a Mac

1. Open `ios/Vuum.xcodeproj`
2. Resolve SPM packages (ComponentsKit, Google Maps SDK, KeychainSwift)
3. Set Maps key (never commit a real key):
   - Copy `Secrets.example.xcconfig` → `Secrets.xcconfig` (gitignored), **or**
   - Xcode scheme **Vuum** → Run → Environment Variables → enable `VUUM_GOOGLE_MAPS_API_KEY` with a real key (shared scheme entry is disabled by default so the placeholder cannot shadow Secrets)
4. Run on simulator or device

Details: [docs/GOOGLE_MAPS_SETUP.md](../docs/GOOGLE_MAPS_SETUP.md)

## Codemagic / Sideloadly (no local Mac)

CI workflow **`ios-release`** in repo-root [`codemagic.yaml`](../codemagic.yaml) builds an unsigned `build/Vuum.ipa`.

1. Create Codemagic group **`vuum_secrets`**, then set Secure `VUUM_GOOGLE_MAPS_API_KEY` inside it (credential-only)
2. Run workflow **`ios-release`** → download IPA → install with Sideloadly

Setup: [docs/CODEMAGIC_SETUP.md](../docs/CODEMAGIC_SETUP.md)

Without the env var, CI still produces a valid IPA; the map surface stays unavailable until a key is injected.

## Secrets.example.xcconfig

| File | Tracked? | Role |
|------|----------|------|
| `ios/Secrets.example.xcconfig` | Yes | Template only (`YOUR_GOOGLE_MAPS_API_KEY`) |
| `ios/Secrets.xcconfig` | No (gitignored) | Local or CI-generated real key |
| `ios/Vuum/Config/Vuum.xcconfig` | Yes | `#include?` optional Secrets |

## Module map

| Folder | Role |
|--------|------|
| App/ | Entry + root navigation |
| Models/ | Trip domain types |
| Services/ | `TripSession` state machine |
| Mock/ | Sample places, drivers, fares |
| Maps/ | Google Maps bootstrap + UIKit map view |
| UI/ | Theme, glass, chrome, UIKit bridges, flow scaffolds |

See [docs/UI_COMPONENTS.md](../docs/UI_COMPONENTS.md) for SwiftUI / UIKit / ComponentsKit / Explore SwiftUI.

New `.swift` files must be registered in `Vuum.xcodeproj/project.pbxproj`.
