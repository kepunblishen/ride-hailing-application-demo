# Vuum — Rider iOS Client

## Purpose

Impress Congo Mobility / **VUUM Ride** (Lubumbashi & Kolwezi, DRC) with a polished **rider iOS client** that feels like a real Uber/Bolt-class product — so they want us to build the full platform from their RFQ (`VUUM Ride Universal Vendor RFQ.docx`, ref **VUUM-RFQ-2026-UNI**).

This is a **presentation-ready rider build**: trip matching, fares, drivers, payments, and most account data are **local / mock** (no production database or dispatch backend). Real device services carry the product story — especially **Google Maps**, **Core Location**, and iOS permission prompts.

**Kenya + DRC reality:** sponsor and typical presentation room are **Kenya** (+254). Product markets on the map and in copy are **DRC** (Lubumbashi & Kolwezi, USD + CDF), with locale-aware currency display. Rider walkthrough only — not driver or admin apps.

Full RFQ extraction + coverage map: [docs/RFQ_REQUIREMENTS_AND_DEMO_SCOPE.md](docs/RFQ_REQUIREMENTS_AND_DEMO_SCOPE.md)

## Client context (from RFQ)

| | |
|--|--|
| **Operator** | Congo Mobility SARL — VUUM Ride |
| **Markets (product)** | Lubumbashi & Kolwezi, DRC |
| **Sponsor / presentation** | Evans Otieno Okoth — Kenya (+254) · okoth59@gmail.com · +254 725 145 760 |
| **Ambition** | Consumer rides + corporate (mining / 30k+ workers) + Trust & Safety + field sales |
| **Scale target** | Toward ~200 vehicles; multi-city; dual currency USD + CDF |

RFQ totals **204** requirements across **4 modules** (140 MUST / 52 HIGH / 12 MEDIUM).

## Product (this iOS build)

- **Platform:** iOS 17+ (SwiftUI; UIKit for Maps + share bridges)
- **Brand:** Vuum
- **In scope:** Full **rider** client — splash → auth → signed-in tabs → book → live trip → rate → account / safety / payments / activity
- **Out of scope:** Driver app, admin panel, dispatcher console, corporate portal backends (roadmap / talk-track only)
- **Build / CI:** Codemagic → unsigned IPA → Sideloadly

## Architecture (real layout)

```
Splash (ContentView)
  → AuthFlowView          if not signed in
  → MainTabView           if SessionStore.isSignedIn
       Home     → RootFlowView (TripSession.phase)
       Services → Ride / 2-Wheels / Rental / Courier / Group / Schedule
       Activity → Past & upcoming trips, receipts, help
       Account  → Profile, wallet, payments, safety, business, settings, support
```

### Trip state machine

`TripSession` owns `TripPhase`:

`idle → selectingDestination → choosingRide → searching → matched → driverEnRoute → driverArrived → inTrip → completed`

Pickup ETA, map car animation, chat availability, and the driver card are driven from one ride path in `TripSession` + `VehiclePickupETA` / `TripMotionTiming` (not from SwiftUI views).

### Code modules (`ios/Vuum/`)

| Folder | Role |
|--------|------|
| `App/` | `VuumApp`, splash gate (`ContentView`), `RootFlowView` phase router |
| `Models/` | `TripPhase`, places, tiers, driver, receipt, chat types |
| `Services/` | `TripSession`, `SessionStore`, `AuthFlowController`, location, permissions, locale, payments, notifications, saved places, trusted contacts, trip audio |
| `Mock/` | Sample places, drivers, fares (Lubumbashi / Kolwezi) |
| `Maps/` | `MapBootstrap` + `VuumMapView` (Google Maps UIKit bridge) |
| `UI/Auth/` | Get started → OTP → terms → confirm info → welcome |
| `UI/Main/` | Tab shell, home, services products, activity, account, payments, corporate, referrals, support |
| `UI/Flow/` | Destination / ride options / searching / active trip / complete scaffolds + incident report |
| `UI/Theme/` · `UI/Components/` | Brand colors, ComponentsKit accent, glass / chrome |
| `Resources/` | `L10n` (EN / FR) |

Folder conventions: [`.cursor/rules/project-structure.mdc`](.cursor/rules/project-structure.mdc). Deeper notes: [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

### Packages (SPM)

| Package | Role |
|---------|------|
| [ComponentsKit](https://github.com/componentskit/ComponentsKit) (≥1.7) | Shared UI controls / accent bootstrap |
| [Google Maps iOS SDK](https://github.com/googlemaps/ios-maps-sdk) (≥9.0) | Live map surface (`GoogleMaps`) |
| [KeychainSwift](https://github.com/evgenyneu/keychain-swift) (≥9.0) | Persisted rider session |

**Credential-gated (no extra SPM):** Places API (New) via `PlacesSearchService`, Routes API via `RoutesAPIService` — same `VUUM_GOOGLE_MAPS_API_KEY`.

SwiftUI + UIKit are system frameworks. **No Firebase, no BLE, no Snyk, no Navigation SDK.**

## Rider capabilities (what ships in the app)

1. **Splash** — branded light/dark backgrounds (`SplashBackground`); SF Symbol map mark if asset missing
2. **Auth** — mobile OTP path (local verify); Apple / Google / Email controls visible but inert (SF Symbol fallbacks when catalog icons empty); session in Keychain until sign-out
3. **Home** — map-first “Where to?”, nearby vehicles, location permission
4. **Book** — pickup / drop-off / stops, fare estimate, ride tiers, promo, payment method, book-for-someone-else, schedule
5. **Products** — Ride, 2-Wheels, hourly rental, courier, group ride (Services tab)
6. **Match → trip** — searching, driver card, live marker, ETA, chat / call shells, boarding PIN, SOS, share, in-trip audio flag / incident report
7. **Complete** — fare breakdown, dual-currency style display, ratings, receipt into Activity
8. **Account** — profile, wallet & payment methods (local), saved places, trusted contacts, safety settings, business profile, referrals / rewards UI, preferences (language & market), support, about / legal
9. **Locale** — EN / FR strings; market-aware currency (DRC USD+CDF / Kenya presentation)

## Credentials — Google Maps key only

| Item | Required? | Notes |
|------|-----------|--------|
| **`VUUM_GOOGLE_MAPS_API_KEY`** | For live Maps + Places + Routes | Only remaining **external** credential. Enable Maps SDK for iOS, Places API (New), and Routes API on the key. Scheme env, `ios/Secrets.xcconfig` (from `Secrets.example.xcconfig`), Info.plist `$(VUUM_GOOGLE_MAPS_API_KEY)`, or Codemagic secure env. Guide: [docs/GOOGLE_MAPS_SETUP.md](docs/GOOGLE_MAPS_SETUP.md) |
| Apple Developer certs | No (Codemagic unsigned + Sideloadly) | Free Apple ID signs on device via Sideloadly |
| SMS / OAuth / payments APIs | No | Auth social buttons inert; OTP and payments are local |

Without a Maps key the app still runs; the map shows an unavailable placeholder (“Add Maps API key”); Places/Routes stay offline-safe.

## How to run

**Mac / simulator**

1. Open `ios/Vuum.xcodeproj`
2. Resolve SPM (ComponentsKit, Google Maps, KeychainSwift)
3. Copy `ios/Secrets.example.xcconfig` → `ios/Secrets.xcconfig` and set `VUUM_GOOGLE_MAPS_API_KEY`, **or** set the same variable on the Vuum scheme
4. Run the **Vuum** scheme on a simulator or device

**Windows → physical iPhone**

1. Edit in Cursor → push to GitHub
2. Codemagic workflow `ios-release` builds unsigned `build/Vuum.ipa` ([docs/CODEMAGIC_SETUP.md](docs/CODEMAGIC_SETUP.md))
3. Install with Sideloadly ([docs/SETUP.md](docs/SETUP.md))

Walkthrough: Home → destination → ride tier → searching → assigned → trip → complete; explore Services, Activity, and Account for the wider product surface.

## Explicitly not production backends

No production DB, real SMS OTP gateway, mobile-money/card settlement, push provider, driver app, or admin/dispatcher servers. Places/Routes HTTPS clients activate when `VUUM_GOOGLE_MAPS_API_KEY` is set and those APIs are enabled; otherwise search/route use local catalog / `TripGeo`. Internal mock catalog and local stores power the presentation.

## Success criteria (client meeting)

- Walk splash → auth → book → trip → rate without explaining mock internals
- Map looks product-grade with a valid Maps key (cars, route, moving driver, permission prompts)
- Dual-currency and safety affordances visibly present
- Tabs and account surface read as a full rider product, not a single linear script
- Client leaves wanting Modules 1–4 delivered for real; clear that this build is the **rider** client, not driver/admin

## Copy rules

Never use the word “demo” (or “placeholder”) in **user-visible** UI strings. Docs may describe local/mock trip logic and presentation builds. See [`.cursor/rules/no-demo-language.mdc`](.cursor/rules/no-demo-language.mdc).
