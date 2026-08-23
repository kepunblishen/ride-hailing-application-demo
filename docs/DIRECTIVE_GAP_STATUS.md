# VUUM iOS — Directive Gap Status

**Reconciler:** Agent 30 (late-wave checkbox reconcile)  
**Date:** 2026-08-23  
**Directive:** `VUUM iOS — FULL PRODUCT REALISM, FEATURE EXPANSION, QA & PRODUCTION-READY PRESENTATION BUILD DIRECTIVE.md`  
**Prior map:** Agent 00 (superseded — many “missing” items were implemented by later waves)

## Executive summary

Rider presentation software is largely in place under `ios/Vuum/`. Live Google Maps / Places / Routes behavior is **credential-gated** (key + Cloud APIs). Remaining unfinished work is a short list: credentials and device QA evidence — not a broad feature hole. Pre-Maps-UI checkpoint: [`READINESS_BEFORE_MAPS_UI.md`](READINESS_BEFORE_MAPS_UI.md). **§88** final report: [`ENGINEERING_COMPLETION_REPORT.md`](ENGINEERING_COMPLETION_REPORT.md).

| Bucket | Count |
|--------|------:|
| **Done (buildable product)** | 74+ (Convenience / Alcohol / Health product sheets wired) |
| **Partial (usable; polish/depth remains)** | 8 |
| **Template-ready / awaiting external run** | **1** (§72) |
| **Unfinished (honest remaining)** | **3** (credential steps only) |
| Process-only (§1–§4, §76, §78–§79, §83–§84, §86) | excluded |

---

## Remaining unfinished (3 + §72 awaiting device)

### Credential-only (blocked on key / Cloud — software ready)

1. **Google Cloud billing + enable APIs** — **Maps SDK for iOS**, **Places API (New)**, **Routes API** (and/or Directions).
2. **API key restricted** to iOS bundle ID `com.vuum.app`.
3. **Inject `VUUM_GOOGLE_MAPS_API_KEY`** via Codemagic secure env / Xcode scheme / `Secrets.xcconfig`, then rebuild. See `docs/GOOGLE_MAPS_SETUP.md`.

### Template ready — awaiting physical device run

4. **§72 Physical device testing evidence** — **template-ready** in `docs/DEVICE_QA_EVIDENCE.md` (Sideloadly/TestFlight fill-in: device model, iOS, build #, pass/fail flows, screenshot placeholders, Maps-key note). **Not filled** — no real iPhone run from this environment; awaiting operator Sideloadly/TestFlight evidence.

### Docs closed this pass

- **§74 Full device/feature testing matrix** — delivered: [`docs/TESTING_MATRIX.md`](./TESTING_MATRIX.md) (auth → offline; Pass / Blocked on Maps key / Manual on device).
- **§77 Full RFQ 204-ref status matrix** — delivered: [`docs/RFQ_204_MATRIX.md`](./RFQ_204_MATRIX.md) (206 extracted Module:Ref rows; **done** / **partial** / **prepared** / **missing** / **n/a** ≡ Implemented / Partially Implemented / Architecturally Prepared / Missing / N/A). **M1:F01 Food** is **partial** (`FoodProductSheet` + Services tile; not a full marketplace). Scope narrative: [`RFQ_REQUIREMENTS_AND_DEMO_SCOPE.md`](./RFQ_REQUIREMENTS_AND_DEMO_SCOPE.md).
- **§88 Final engineering completion report** — delivered: [`ENGINEERING_COMPLETION_REPORT.md`](ENGINEERING_COMPLETION_REPORT.md) (shipped surface, architecture, SPM, run paths, credentials, limitations, presenter walkthrough).

**Note:** §75 unit tests — **partial**: `ios/VuumTests/` + `docs/TESTING.md` cover phases, ETA, fare/promo, auth/OTP gates, money formatting, payment/referral eligibility, accelerated match→arrived→inTrip. Still open: async OTP expiry/lockout, full completion/cancel-fee matrix, FieldSales settlement.

---

## Formerly “missing” — now verified done (Agent 00 → Agent 30)

| ID | Topic | Evidence |
|----|-------|----------|
| §13 / §64 / §65 / §87 software | Maps + Places + Routes stack | `MapBootstrap`, `VuumMapView`, `PlacesSearchService`, `RoutesAPIService`, `DirectionsRouteService`, `RouteEngine`, `docs/GOOGLE_MAPS_SETUP.md` |
| §14 | Map fallback | Placeholder without key |
| §18 / §20 | PIN + in-trip destination change | `TripSession.updateInTripDestination`, `ChangeDestinationSheet` |
| §24 / §25 / §68 | Payment providers + history | `PaymentProviders`, `PaymentMethodStore.transactions`, `PaymentHistoryView` |
| §32 / §45 | Cancel fee + surge | `CancellationPolicy`, `CancelTripSheet`, `MockSurge` / `surgeState` |
| §49 / §50 | Field sales / eligibility | `FieldSalesModels`, `FieldSalesStore`, referral lifecycle |
| §51 / §52 | Offline / status UI | `NetworkReachability`, `VuumOfflineBanner` on `ContentView`, `VuumStatusViews` |
| §66 | Zone availability | `ServiceZone`, `ServiceZoneCatalog` |
| §42 | Geofencing / airport / demand zones + route deviation | `TripGeo` geofence + polyline corridor helpers; `ServiceZoneCatalog`; `RouteDeviationMonitor` + in-trip notice in `TripSession` / `ActiveTripFlowView` |
| §6 | Reverse geocode path | `ReverseGeocodingService` (Google when keyed, else `CLGeocoder`) |
| §8 | Money / FX types | `Money.swift`, `ExchangeRateConfiguration` |
| §67 | Contextual FX / dual display | `ExchangeRateConfiguration`, `CurrencyConfiguration`, `MoneyPair` |
| §44 | Pricing engine | `PricingEngine.swift` + `MockFares` |
| §82 | Hidden diagnostics | `DeveloperDiagnostics`, `DiagnosticsToolsView` |
| §48 | Executive meet-and-greet | `ExecutiveProductSheet`, `TripSession.startExecutiveMeetAndGreetBooking`, Business profile book CTA |
| §74 | Full device/feature testing matrix | `docs/TESTING_MATRIX.md` (Pass / Blocked on Maps key / Manual on device) |
| §77 | RFQ 204-ref coverage matrix | `docs/RFQ_204_MATRIX.md` |
| §88 | Final engineering completion report | `docs/ENGINEERING_COMPLETION_REPORT.md` |

---

## Partial (usable; not blocking credential checkpoint)

| ID | Topic | Gap |
|----|-------|-----|
| §9 | L10n FR/EN/LN/SW | Core chrome localized; many flow strings still English literals |
| §21 | Scheduled rides | Reserve + list/cancel; edit/reminders thinner than Uber |
| §28 / §62 | Account depth | Broad hub; some settings still shallow |
| §29 / §30 | Support / lost item | Ticket + lost-item flows present; not full backend ticket SM |
| §38 | Trip audio | On-device record + mic permission; no cloud retention pipeline (by design) |
| §40 / §69 | Permissions UX | Contextual strings exist; some batching remains |
| §42 | Geo utilities depth | Geofences + service zones + persistent route-deviation corridor shipped; full city-boundary polygons still thinner than Uber |
| §61 / §71 | Premium polish / motion | Subjective; keep iterating on device |
| §85 | Acceptance walkthrough | Runnable without key (synthetic maps); live tiles need credentials |

---

## Folder map (current)

| Folder | Role |
|--------|------|
| `App/` | Splash gate, `RootFlowView` phase router, DI |
| `Models/` | Trip, money, zones, payments, corporate, field-sales types |
| `Services/` | TripSession, locale, location, payments, Places/Routes clients, diagnostics |
| `Maps/` | Bootstrap, GMS view + fallback, Directions, RouteEngine |
| `Mock/` | Places, drivers, fares, surge, corporate |
| `UI/Auth/` | Get started → OTP → terms → confirm → welcome |
| `UI/Flow/` | Destination, choose ride, search, active trip, change destination, safety, chat |
| `UI/Main/` | Tabs + account / payments / support / corporate / referrals / products |
| `docs/` | SETUP, GOOGLE_MAPS, CODEMAGIC, DEVICE_QA_EVIDENCE (§72 template), **TESTING_MATRIX (§74)**, RFQ scope, **RFQ_204_MATRIX (§77)**, ENGINEERING_COMPLETION_REPORT (§88), NO_SNYK, this gap file |

---

## Explicit non-claims

- Did **not** run Xcode build or Sideloadly install in this reconcile pass.
- Did **not** invent product features beyond tiny glue (offline banner wiring, Routes preference in `RouteEngine`, in-trip change destination affordance where missing).
- Snyk remains disabled for this workspace (`docs/NO_SNYK.md`).
- **§72** — evidence **template** landed (`docs/DEVICE_QA_EVIDENCE.md`); filled pass/fail log still **awaiting device run**.
- **§88** — completion report written; does not claim a fresh green Xcode/Sideloadly run in every reconcile pass.
- **GOOGLE MAPS / PLACES / ROUTES CREDENTIAL CHECKPOINT** — software ready; insert key + enable APIs per `docs/GOOGLE_MAPS_SETUP.md`.
