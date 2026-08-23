# Vuum iOS — Final Engineering Completion Report (§88)

**Product:** Vuum rider iOS client (`com.vuum.app`)  
**RFQ:** VUUM-RFQ-2026-UNI (Congo Mobility / VUUM Ride)  
**Date:** 2026-08-23  
**Scope:** Presentation-ready **rider** client — not driver, admin, or dispatcher backends  
**Companion status:** [`DIRECTIVE_GAP_STATUS.md`](DIRECTIVE_GAP_STATUS.md) · Maps checkpoint: [`GOOGLE_MAPS_SETUP.md`](GOOGLE_MAPS_SETUP.md)

---

## 1. What already existed

At program start the repo already had a runnable SwiftUI rider shell under `ios/Vuum/`:

- Splash → auth OTP path → Keychain session → signed-in tab shell
- Map-first home and a linear book → match → trip → complete path driven by `TripSession`
- Local/mock places, drivers, and fares (Lubumbashi / Kolwezi)
- Google Maps SPM wiring and map fallback without a key
- Codemagic unsigned IPA → Sideloadly delivery path
- ComponentsKit theme bootstrap and Vuum brand chrome

Infrastructure patterns (Xcode layout, Codemagic unsigned build) came from an earlier scaffold; **product screens and branding are Vuum-specific**.

---

## 2. What was improved

- **Single ride path** — pickup ETA, map motion, chat gating, and driver card all driven from `TripSession` + `VehiclePickupETA` / `TripMotionTiming` (no parallel clocks in SwiftUI)
- **Trip phases** — full machine: `idle → selectingDestination → choosingRide → searching → matched → driverEnRoute → driverArrived → inTrip → completed`
- **Maps stack** — `MapBootstrap`, `VuumMapView`, Places (New) HTTPS, Routes + Directions fallback, reverse geocode (Google when keyed / `CLGeocoder` otherwise)
- **Money / FX** — dual-currency display (USD + CDF), market-aware configuration
- **Safety surface** — SOS, share, trusted contacts, boarding PIN, incident report, on-device trip audio flag
- **Account / Services / Activity** — payments history, corporate / executive / field-sales shells, schedule, multi-stop, book-for-someone-else
- **Offline / status UI** — reachability banner, empty and loading states
- **Copy rules** — no user-visible “demo” / “placeholder” language
- **CI docs** — SETUP, GOOGLE_MAPS, CODEMAGIC, TESTING, NO_SNYK aligned with credential-only Maps activation

---

## 3. What was added

| Area | Deliverables |
|------|----------------|
| Trip realism | PIN boarding, in-trip destination change, cancel fees, surge, promo math |
| Products | Ride, 2-Wheels, rental, courier, group, schedule, airport / executive sheets |
| Safety | SOS → safety notified, trip share, trusted contacts, audio / incident flows |
| Chat | In-trip chat when `TripSession.isChatAvailable` (`matched` … `inTrip`) |
| Payments | Local provider adapters + payment history |
| Geo / zones | Service zones, airport / demand helpers, zone-gated availability |
| Locale | L10n architecture (EN / FR primary; LN / SW scaffolding) |
| Diagnostics | Hidden developer diagnostics (not shown in normal rider UI) |
| Tests | `VuumTests`: phase machine, VehiclePickupETA (2 / 5 / 10), fare/promo math |
| Docs | Architecture, RFQ scope extract, gap status, this report |

---

## 4. What was removed / kept out

- **Firebase** — not part of Vuum product scope
- **BLE** — not part of Vuum product scope
- **Navigation SDK** — rider map + polyline only; no turn-by-turn SDK
- **Snyk / Synk / Sync scan tooling** — disabled for this workspace (see §7)
- **Production backends** — no live SMS OTP, card/mobile-money settlement, push provider, or dispatch server

---

## 5. What packages were installed (SPM)

Declared on `ios/Vuum.xcodeproj` · deployment **iOS 17+**:

| Package | URL | Role |
|---------|-----|------|
| **ComponentsKit** | `https://github.com/componentskit/ComponentsKit` (≥ 1.7.0) | Shared controls / accent |
| **Google Maps SDK** | `https://github.com/googlemaps/ios-maps-sdk` (≥ 10.0.0, `< 11`), product `GoogleMaps` | Live map surface |
| **KeychainSwift** | `https://github.com/evgenyneu/keychain-swift` (≥ 24.0.0, `< 25`) | Rider session persistence |

**System frameworks:** SwiftUI, UIKit (maps / share bridges).

**Credential-gated HTTPS (no extra SPM):** Places API (New) via `PlacesSearchService`; Routes API via `RoutesAPIService`; Directions JSON fallback via `DirectionsRouteService`. Same key: `VUUM_GOOGLE_MAPS_API_KEY`.

---

## 6. What packages were removed

No required SPM products were removed mid-program for Vuum. Intentionally **not** added:

- Firebase / GoogleService-Info stack
- `ios-places-sdk` (Places used over HTTPS — [`PLACES_SDK_DECISION.md`](PLACES_SDK_DECISION.md))
- `ios-navigation-sdk`
- KeychainAccess (avoided — ships SPM `unsafeFlags`)

---

## 7. What happened to Synk / Snyk / Sync

Snyk is **disabled** for this workspace. Agents and CI must not invoke Snyk MCP tools or block on scans.

| Enforcement | Location |
|-------------|----------|
| Cursor rule | `.cursor/rules/no-snyk.mdc` |
| Extension deny-list | `.vscode/extensions.json` → `unwantedRecommendations` |
| Policy doc | [`docs/NO_SNYK.md`](NO_SNYK.md) |

Codemagic `ios-release` has **no** Snyk step. Security review is manual / on request only.

---

## 8. Current Google integration state

| Layer | Software | Live behavior |
|-------|----------|----------------|
| Maps SDK for iOS | `MapBootstrap` + `VuumMapView` | Needs key → tiles, markers, polylines |
| Places API (New) | `PlacesSearchService` + `PlacesSearchController` (session tokens, debounce, field masks) | Needs key → else local `MockPlaces` catalog; UI error/searching states |
| Routes API | `RoutesAPIService` (`computeRoutes`) | Needs key → else `TripGeo` local geometry |
| Directions API | `DirectionsRouteService` | Fallback when Routes fails / keyed |
| Reverse geocode | `ReverseGeocodingService` | Google when keyed; else `CLGeocoder` |

Without a key the app **builds and runs**: map unavailable surface, local autocomplete, synthetic routes/ETAs, full trip UI (matching → PIN → SOS → rate).

**Status:** software ready for the **GOOGLE MAPS / PLACES / ROUTES CREDENTIAL CHECKPOINT**. No architectural rewrite expected when the key is supplied.

---

## 9. Remaining credential-only steps

1. Google Cloud **billing** linked  
2. Enable **Maps SDK for iOS**, **Places API (New)**, **Routes API** (and Directions if using fallback)  
3. Create API key restricted to iOS bundle ID **`com.vuum.app`**  
4. Inject **`VUUM_GOOGLE_MAPS_API_KEY`** via Codemagic secure env **or** Xcode scheme env **or** gitignored `ios/Secrets.xcconfig`  
5. Rebuild IPA / Run and confirm tiles, autocomplete, and route polyline  

Full checklist: [`GOOGLE_MAPS_SETUP.md`](GOOGLE_MAPS_SETUP.md). **Never commit a real key.**

---

## 10. Remaining backend-only requirements

Out of scope for this presentation build (RFQ Modules 1–4 talk-track / later delivery):

- Production DB, dispatch matching, driver accept/reject server
- Real SMS OTP / OAuth / Apple Sign In verification
- Mobile money / card settlement gateways
- Push notification provider
- Driver app, admin panel, dispatcher console, corporate portal
- Cloud trip-audio retention / safety console
- Full field-sales commission engine

Rider UI shells exist where useful for story; they do not invent fake production backends.

---

## 11. RFQ rider-side coverage

| Module | This build |
|--------|------------|
| **1. Core ride-hailing** | Rider UX largely covered on-device (book, track, fare, chat/call shells, PIN, schedule, multi-stop, dual currency, surge/promo) |
| **2. Corporate** | Business profile / executive meet-and-greet shells — not portal backend |
| **3. Trust & Safety** | Rider SOS, share, trusted contacts, audio flag, incidents — not safety console |
| **4. Field sales** | Referral / eligibility UI — not commission ledger |

**204-ref status matrix (§77):** delivered in [`RFQ_204_MATRIX.md`](RFQ_204_MATRIX.md). Scope narrative: [`RFQ_REQUIREMENTS_AND_DEMO_SCOPE.md`](RFQ_REQUIREMENTS_AND_DEMO_SCOPE.md).

---

## 12. Known limitations

- Live map tiles / Google Places / road polylines require credentials (§9)
- Trip match, fares, payments, OTP verify are **local/mock**
- L10n: core chrome localized; many flow strings still English literals
- Scheduled rides: reserve + list/cancel; edit/reminders thinner than Uber-class
- Account / support / lost-item: flows present; not full backend ticket SM
- Trip audio: on-device only; no cloud retention
- Unit tests cover phases / ETA / promo — not full async driver lifecycle
- Physical device QA log (§72) not filled in-repo; testing matrix (§74) delivered at [`TESTING_MATRIX.md`](TESTING_MATRIX.md)
- This report’s authors did not claim a fresh Xcode green build in every reconcile pass — pipeline is documented; run Mac or Codemagic to confirm

| Kind | Status |
|------|--------|
| Unit — `TripSessionPhaseTests` | Present under `ios/VuumTests/` |
| Unit — `VehiclePickupETATests` (2 / 5 / 10 min) | Present |
| Unit — `FarePromoMathTests` | Present |
| How to run | Mac / Codemagic — [`TESTING.md`](TESTING.md) |
| Default Codemagic IPA workflow | Does **not** run tests (speed for Sideloadly) |
| Physical device evidence log | Still open (§72) |

---

## 14. Build result

| Path | Expected result |
|------|-----------------|
| **Mac** | Open `ios/Vuum.xcodeproj` → resolve SPM → set key (optional) → scheme **Vuum** → Run |
| **Codemagic** | Workflow `ios-release` → resolve SPM → unsigned `build/Vuum.ipa` |
| **Without Maps key** | Build succeeds; map placeholder; trip flow intact |
| **With Maps key** | Same build; Info.plist / Secrets inject key for live tiles |

See [`SETUP.md`](SETUP.md) and [`CODEMAGIC_SETUP.md`](CODEMAGIC_SETUP.md).

---

## 15. Sideload readiness

Ready for presenter devices:

1. Push repo → Codemagic **ios-release**  
2. Download `build/Vuum.ipa`  
3. Install with **Sideloadly** (free Apple ID; no paid Developer Program required for this path)  
4. For live maps on the IPA, set Codemagic secure env `VUUM_GOOGLE_MAPS_API_KEY` before rebuild  

Bundle ID: **`com.vuum.app`**.

---

## Architecture (shipped)

```
Splash (ContentView)
  → AuthFlowView          if not signed in
  → MainTabView           if SessionStore.isSignedIn
       Home     → RootFlowView (TripSession.phase)
       Services → Ride / 2-Wheels / Rental / Courier / Group / Schedule
       Activity → Past & upcoming trips, receipts, help
       Account  → Profile, wallet, payments, safety, business, settings, support
```

| Folder | Role |
|--------|------|
| `App/` | Splash gate, `RootFlowView` phase router |
| `Models/` | Trip, money, zones, payments, corporate, field-sales |
| `Services/` | `TripSession`, locale, location, payments, Places/Routes, diagnostics |
| `Maps/` | Bootstrap, GMS view + fallback, Directions, RouteEngine |
| `Mock/` | Places, drivers, fares, surge, corporate |
| `UI/Auth/` · `UI/Flow/` · `UI/Main/` | Rider surfaces |
| `UI/Theme/` · `UI/Components/` | Brand + glass/chrome |

Trip logic stays in **`TripSession`** — not in SwiftUI views.

---

## How to run

### Mac / simulator

1. Open `ios/Vuum.xcodeproj`  
2. Resolve SPM (ComponentsKit, Google Maps, KeychainSwift)  
3. `cp ios/Secrets.example.xcconfig ios/Secrets.xcconfig` and set `VUUM_GOOGLE_MAPS_API_KEY`, **or** set the same on scheme **Vuum** → Run → Environment Variables  
4. Run scheme **Vuum** on simulator or device  

### Windows → physical iPhone

1. Edit in Cursor → push to GitHub  
2. Codemagic `ios-release` → download `build/Vuum.ipa`  
3. Sideloadly → iPhone  

SPM cannot be resolved on Windows PowerShell; Codemagic (or a Mac) resolves packages.

---

## Presenter walkthrough

Use Home (or Services) → destination → choose ride. Pickup ETAs are **class-based** (`VehiclePickupETA` in `TripGeo.swift`), not chord distance:

| Book | Fleet class | Displayed pickup ETA | What to show |
|------|-------------|----------------------|--------------|
| **Bike / 2-Wheels** | `.bike` | **2 min** | Faster match, bike SF Symbol (`bicycle`) on map, compressed approach motion |
| **Standard car** (Vuum / Comfort / Courier) | `.standard` | **5 min** | Default car badge (`car.fill`), chat after match, PIN at arrive |
| **XXL / Large / Executive / Hourly** | `.large` | **10 min** | Larger badge (`car.2.fill`), longer baseline ETA |

### Recommended script (~8–12 minutes)

1. **Splash → Get started → OTP → enter app** (local verify; social buttons may be inert — do not apologize as “demo”).  
2. **Home** — “Where to?”, allow location if prompted; map tiles if keyed.  
3. **Book bike (2 min)** — Services → 2-Wheels or bike tier → confirm searching → matched → driver en route. Point at **~2 min** ETA.  
4. **Cancel or complete**, then **book standard car (5 min)** — show driver card, **open chat** (available from `matched` through `inTrip`), optional call shell.  
5. **Driver arrived → PIN → in trip → complete → rate** — receipt lands in Activity.  
6. **Book XXL / Executive (10 min)** — Services or large tier; call out **~10 min** pickup.  
7. **Safety** — during an active trip: **SOS** (safety team notified UI), trip **share**, Account → trusted contacts / safety settings.  
8. Optional: payments / dual currency on receipt, schedule a ride, Account business / referrals.

**Chat:** `TripSession.isChatAvailable` is true for `matched | driverEnRoute | driverArrived | inTrip` when `activeTrip != nil`.  
**Safety:** SOS sets notified state after a short delay; do not claim a live safety operations center.

Without a Maps key, walk the same script — map shows unavailable; ETAs, chat, and SOS still work.

---

## Explicit non-claims

- Not “everything is done”: credentials and device QA log (§72) remain; §74 matrix is at [`TESTING_MATRIX.md`](TESTING_MATRIX.md).  
- Not a production platform: local trip layer, no driver/admin apps.  
- Snyk was not run as part of this completion report.

---

## Doc index

| Doc | Topic |
|-----|--------|
| [`PROJECT.md`](../PROJECT.md) | Purpose, RFQ, capabilities |
| [`SETUP.md`](SETUP.md) | Windows / Sideloadly |
| [`GOOGLE_MAPS_SETUP.md`](GOOGLE_MAPS_SETUP.md) | Credential checkpoint |
| [`CODEMAGIC_SETUP.md`](CODEMAGIC_SETUP.md) | Cloud IPA |
| [`ARCHITECTURE.md`](ARCHITECTURE.md) | Module map |
| [`TESTING.md`](TESTING.md) | XCTest |
| [`TESTING_MATRIX.md`](TESTING_MATRIX.md) | §74 device/feature matrix |
| [`DIRECTIVE_GAP_STATUS.md`](DIRECTIVE_GAP_STATUS.md) | Checkbox reconcile |
| [`NO_SNYK.md`](NO_SNYK.md) | Snyk disabled |
| [`RFQ_REQUIREMENTS_AND_DEMO_SCOPE.md`](RFQ_REQUIREMENTS_AND_DEMO_SCOPE.md) | RFQ extract |
