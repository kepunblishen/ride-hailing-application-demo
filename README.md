# Vuum — Rider iOS Client

Uber/Bolt-class **rider** client for VUUM Ride (Congo Mobility). Product scope, RFQ context, and architecture: [PROJECT.md](PROJECT.md).

Trip matching, fares, and most account data are **local/mock** (no production backend). The only external credential needed for a live map is a **Google Maps API key**.

## What’s in the repo

| Path | Purpose |
|------|---------|
| `ios/Vuum.xcodeproj` | Xcode project (iOS 17+, SwiftUI + UIKit bridges) |
| `ios/Vuum/` | App sources — auth, tabs, trip flow, maps, services, mock catalog |
| `ios/VuumTests/` | XCTest unit tests (phases, lifecycle, ETA, fare/promo, auth, money, payment/referral) — see [docs/TESTING.md](docs/TESTING.md) |
| `codemagic.yaml` | Unsigned IPA build for Sideloadly |
| `docs/` | Setup, Maps key, Codemagic, architecture, RFQ coverage |
| `reference/` | ComponentsKit + Explore SwiftUI lookup notes |

## Architecture (short)

```
Splash → Auth (Keychain session) or Main tabs
  Home      TripSession phases (book → match → trip → complete)
  Services  Ride, 2-Wheels, rental, courier, group, schedule
  Activity  Past / upcoming trips & receipts
  Account   Profile, payments, safety, settings, support
```

Trip logic lives in `TripSession`; session in `SessionStore` (KeychainSwift). Details: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Packages (SPM)

| Package | Role |
|---------|------|
| SwiftUI / UIKit | Screens + Maps / share bridges |
| ComponentsKit | Shared controls / accent |
| Google Maps iOS SDK | Live map when API key is set |
| KeychainSwift | Rider session persistence |

No Firebase, BLE, or Snyk.

## Credential

**Only remaining external credential:** `VUUM_GOOGLE_MAPS_API_KEY`

- Local: `ios/Secrets.xcconfig` (from `Secrets.example.xcconfig`) or Xcode scheme env
- CI: Codemagic secure env → `xcodebuild` / Info.plist
- Full guide: [docs/GOOGLE_MAPS_SETUP.md](docs/GOOGLE_MAPS_SETUP.md)

Without a key the app runs; the map shows an unavailable placeholder.

## How to run

**Mac**

1. Open `ios/Vuum.xcodeproj`
2. Resolve SPM packages
3. Set `VUUM_GOOGLE_MAPS_API_KEY`
4. Run scheme **Vuum**

**Windows → iPhone**

1. Push to GitHub → Codemagic `ios-release` → download `Vuum.ipa`
2. Install with Sideloadly  
   See [docs/SETUP.md](docs/SETUP.md) and [docs/CODEMAGIC_SETUP.md](docs/CODEMAGIC_SETUP.md)

## Rider path to try

Home → destination → ride tier → searching → driver en route → in trip → complete. Then open **Services**, **Activity**, and **Account** for the wider product surface.

## Docs index

| Doc | Topic |
|-----|--------|
| [PROJECT.md](PROJECT.md) | Purpose, RFQ, capabilities, credentials |
| [docs/SETUP.md](docs/SETUP.md) | Windows / Sideloadly tooling |
| [docs/GOOGLE_MAPS_SETUP.md](docs/GOOGLE_MAPS_SETUP.md) | Maps API key |
| [docs/CODEMAGIC_SETUP.md](docs/CODEMAGIC_SETUP.md) | Cloud IPA builds |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Module map & flow |
| [docs/ENGINEERING_COMPLETION_REPORT.md](docs/ENGINEERING_COMPLETION_REPORT.md) | §88 final engineering completion report |
| [ios/README.md](ios/README.md) | Source tree under `ios/Vuum/` |
