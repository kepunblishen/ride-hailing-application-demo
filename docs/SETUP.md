# iOS Setup — Vuum

**Typical machine:** Windows laptop  
**Target:** iPhone via Sideloadly + Codemagic (no local Mac required for IPA builds)

---

## Tools on Windows

| Tool | Why |
|------|-----|
| Git | Version control |
| Sideloadly | Install `.ipa` |
| Codemagic | Cloud Mac build + SPM resolve |
| GitHub | Host repo for Codemagic |
| Cursor | Edit Swift on Windows |

Xcode cannot run on Windows — builds and SPM resolution go through Codemagic (or a rented / CI Mac).

---

## Frameworks / packages (declared in `ios/Vuum.xcodeproj`)

| Item | How | Required? |
|------|-----|-----------|
| **SwiftUI** | Built into iOS SDK | Yes — all UI |
| **UIKit** | Built into iOS SDK | Yes — maps / share bridges |
| **ComponentsKit** | SPM `https://github.com/componentskit/ComponentsKit` (≥ 1.7.0, `< 2`) | Yes — theme / controls |
| **Google Maps SDK** | SPM `https://github.com/googlemaps/ios-maps-sdk` (≥ 10.0.0, `< 11`), product `GoogleMaps` | Yes — map surface |
| **KeychainSwift** | SPM `https://github.com/evgenyneu/keychain-swift.git` (≥ 24.0.0, `< 25`) | Yes — rider session |
| **Places API (New)** | HTTPS via `PlacesSearchService` (no extra SPM) | Credential-gated |
| **Routes API** | HTTPS via `RoutesAPIService` (no extra SPM) | Credential-gated |
| Firebase / BLE / Snyk | — | **No** — out of scope |

Deployment target: **iOS 17.0+** · Bundle ID: **`com.vuum.app`**

### Why Places / Routes are not SPM packages

- **Places:** Google offers `ios-places-sdk`, but Vuum uses Places API (New) over `URLSession` so autocomplete works once the key is set without another binary dependency. Session tokens are implemented in `PlacesSearchService`.
- **Routes:** Google Routes is a REST API only (no lightweight Routes SPM). `RoutesAPIService` calls `computeRoutes`; without a key the trip layer keeps using local `TripGeo` polylines.
- **Navigation SDK** (`ios-navigation-sdk`) is **not** linked — rider map + polyline does not need turn-by-turn navigation.

---

## Maps / Places / Routes API key

**The only remaining Google configuration step is providing an API key** (never commit a real key).

Full guide: [GOOGLE_MAPS_SETUP.md](GOOGLE_MAPS_SETUP.md)

Quick inject options:

| Where | How |
|-------|-----|
| Codemagic | Secure env `VUUM_GOOGLE_MAPS_API_KEY` (preferred for Sideloadly IPA) |
| Local Mac Xcode | Scheme Run → Environment Variables → `VUUM_GOOGLE_MAPS_API_KEY` |
| Local Mac device builds | `cp ios/Secrets.example.xcconfig ios/Secrets.xcconfig` then paste key (`Secrets.xcconfig` is gitignored) |

Without a key the app still builds and opens; map shows unavailable; Places/Routes return empty and fall back to local geometry.

---

## Resolve SPM on Codemagic (supported from Windows)

Push to GitHub → Codemagic workflow **ios-release** → script **Resolve Swift packages** runs the same `xcodebuild -resolvePackageDependencies` as below, then builds the IPA. Details: [CODEMAGIC_SETUP.md](CODEMAGIC_SETUP.md#spm-resolve-on-codemagic-required-path-from-windows).

PowerShell on Windows cannot resolve Apple SPM graphs; Codemagic (or a Mac) is required.

## Resolve SPM on a Mac (optional admin / first open)

```bash
# Xcode Command Line Tools (once; may prompt for admin password)
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch

cd "/path/to/Raide hailing application demo"
xcodebuild -resolvePackageDependencies \
  -project ios/Vuum.xcodeproj \
  -scheme Vuum
```

If Xcode asks to trust Swift packages on first open: **File → Packages → Resolve Package Versions**.

---

## Build flow

```
Edit Swift on Windows (Cursor)
        ↓
Push to GitHub
        ↓
Codemagic → resolve SPM → build/Vuum.ipa
        ↓
Sideloadly → iPhone
```

See [CODEMAGIC_SETUP.md](CODEMAGIC_SETUP.md).

Unit tests (Mac / Codemagic only): [TESTING.md](TESTING.md).
