# Maps audit gap status - Post-Implementation Google Maps audit

**Source audit:** [`VUUM - Post-Implementation Google Maps-API Architecture Audit & Final Product Hardening.md`](../VUUM%20-%20Post-Implementation%20Google%20Maps-API%20Architecture%20Audit%20%26%20Final%20Product%20Hardening.md) (repo root)  
**Rescan date:** 2026-08-23  
**Method:** Code + docs + CI wiring only (no live Google Cloud console, no physical device in this environment).  
**Snyk:** Out of scope ([`NO_SNYK.md`](NO_SNYK.md)).

**Companions:** [`GOOGLE_MAPS_SETUP.md`](GOOGLE_MAPS_SETUP.md) · [`GOOGLE_API_MATRIX.md`](GOOGLE_API_MATRIX.md) · [`GOOGLE_MAPS_ARCHITECTURE.md`](GOOGLE_MAPS_ARCHITECTURE.md) · [`GOOGLE_INTEGRATION_TEST_PLAN.md`](GOOGLE_INTEGRATION_TEST_PLAN.md) · [`MAPS_CAPABILITY_MATRIX.md`](MAPS_CAPABILITY_MATRIX.md) · [`MAPS_HARDENING_FINAL_REPORT.md`](MAPS_HARDENING_FINAL_REPORT.md) · [`PLACES_SDK_DECISION.md`](PLACES_SDK_DECISION.md) · [`PRE_BUILD_MAPS_GATE.md`](PRE_BUILD_MAPS_GATE.md) · [`MAPS_POST_KEY_QA.md`](MAPS_POST_KEY_QA.md) · [`DEVICE_QA_EVIDENCE.md`](DEVICE_QA_EVIDENCE.md) · [`CODEMAGIC_SETUP.md`](CODEMAGIC_SETUP.md)

---

## Verdict

| Lane | Status |
|------|--------|
| **In-repo Maps software** | Largely complete - SPM Maps, bootstrap, Places (New) HTTPS + session/debounce controller, Routes -> Directions -> synthetic, reverse geocode throttle, camera gesture respect, multi-stop, deviation, GPS-relative nearby fleet, Codemagic inject |
| **Operator / credentials** | Open - keyed Codemagic build + Cloud restrictions |
| **Device evidence** | Open - templates only (`MAPS_POST_KEY_QA`, `DEVICE_QA_EVIDENCE`) |

**Blocking unfinished before live-Maps presentation: 2**

1. Codemagic `ios-release` with `VUUM_GOOGLE_MAPS_API_KEY` in group `vuum_secrets` (+ Cloud APIs / iOS restriction `com.vuum.app`)
2. Physical device verify (fill [`MAPS_POST_KEY_QA.md`](MAPS_POST_KEY_QA.md) / [`DEVICE_QA_EVIDENCE.md`](DEVICE_QA_EVIDENCE.md))

Residual audit niceties (not blocking Codemagic): optional Places `includedTypes` filter; Package.resolved pin note on CI; Uber/Bolt matrix polish if desired.

---

## Counts (sections 1–78)

| State | Count | Meaning |
|-------|------:|---------|
| `[x]` done | 61 | Implemented or explicit keep/skip decision verified in repo |
| `[~]` partial | 10 | Present but incomplete vs audit ideal |
| `[ ]` open | 7 | Not done / not verifiable here (mostly operator + device + final report) |

Legend: `[x]` done · `[~]` partial · `[ ]` unfinished

---

## Section tracker

### Inventory & architecture

| # | Topic | | Evidence / gap |
|---|--------|:-:|----------------|
| 1 | Audit what exists | [x] | Maps stack under `ios/Vuum/Maps/` + `Services/` (Places, Routes, ReverseGeocode, RouteDeviation, PlacesSearchController) |
| 2 | Google API inventory | [x] | [`GOOGLE_API_MATRIX.md`](GOOGLE_API_MATRIX.md) — Maps SDK, Places (New), Routes, Directions fallback; Geocoding optional after Apple-first; unused APIs REMOVE FROM KEY |
| 3 | SPM / no CocoaPods | [x] | `ios-maps-sdk` ≥ 10.0.0 (`upToNextMajor`) product `GoogleMaps`; no Podfile |
| 4 | API key architecture | [x] | `MapBootstrap` env -> Info.plist -> `GMSApiKey`; gitignored `Secrets.xcconfig`; Codemagic inject |
| 5 | API key restrictions | [ ] | **Operator** - cannot verify Cloud console from repo; matrix + setup prescribe iOS + `com.vuum.app` + Maps/Places/Routes(/Directions); Geocoding optional |
| 6 | SDK vs web-service | [x] | Maps = SDK; Places/Routes/Directions/(optional)Geocode = typed HTTPS + `X-Ios-Bundle-Identifier` (no generic Google client) |
| 7 | Routes API | [x] | `RouteProvider` / `RoutesAPIService` `TRAFFIC_AWARE`; `RouteEngine.Route` legs + traffic/static duration; TripSession assign/preview/change-dest/in-trip |
| 8 | Route polyline | [x] | Encoded polyline decode -> map path; synthetic only as fallback |
| 9 | ETA | [x] | Live duration when keyed; in-trip `routeDurationSeconds` + `displayedETAMinutes` (not fixedSpeed); fare separate |
| 10 | Autocomplete session | [x] | Session token + `PlacesSearchController` debounce (~300 ms) + cancel/stale guard |
| 11 | Place field masking | [x] | Details `id,displayName,formattedAddress,location,types,primaryType`; autocomplete includes `types` |
| 12 | Place types | [x] | Autocomplete `types` field mask + `PlaceCategory` → `PlaceSuggestion.systemImage` |
| 13 | Search result UX | [x] | Primary + `compactSubtitle` (address · category · distance); type icons on Where-to / change-dest / pickers |
| 16 | Caching | [x] | `MapsRequestCache` + `BoundedTTLCache` (places 10m / routes 2m / geocode 90s; cap 48) |
| 14 | Current location | [x] | Auth -> blue-dot; denied/unavailable/approximate banners; precise upgrade; market centers keep real names until live GPS |
| 15 | Reverse geocoding | [x] | Apple-first `CLGeocoder` → optional Google Geocoding → coords; throttle 45 m / 18 s; `ReverseGeocodingNamingTests` |
| 17 | Error handling | [x] | `GoogleAPIError` → `L10n` `maps.error_*` / Places / Route; map-unavailable plane; Places/Routes silent fallback |
| 18 | Google error diagnostics | [x] | `GoogleAPIError` + `GoogleMapsDiagnostics` (gated Diagnostics UI; never logs key) |
| 19 | Retry strategy | [x] | `GoogleAPIHTTP` exponential backoff; no retry on 401/403/invalid |
| 20 | Rate / billing protection | [x] | Debounce, session tokens, reverse-geocode throttle, route signatures, single bootstrap |
| 21 | SwiftUI lifecycle | [x] | Long-lived `TripSession` / controllers; search `.task` cancel on disappear |
| 22 | Concurrency | [x] | Query generation + query-string stale guard in `PlacesSearchController`; route builds via session lifecycle |
| 23 | Driver movement | [x] | Path-following motion + heading lerp in `TripSession` / `VuumMapView` |
| 24 | Trip route reuse | [x] | Assign stores pickup+trip; in-trip `subpath`/`pathBetween`; keyed leg refine without full rebook |
| 25 | Route deviation | [x] | `RouteDeviationMonitor` + dense live-polyline XCTest; corridor = `ActiveTrip.tripRoute`; legs via `TripGeo.pathBetween`/`subpath` |
| 25b | Airport / downtown zones | [x] | `ServiceZoneCatalog` geofences + Home/Services `zoneContext` banners; **no** map geofence overlays (rider UX - not required) |
| 26 | Multi-stop routes on map | [x] | `through:` waypoints; stop pins/fit; preview/assign/change-dest; in-trip `subpath` + keyed live leg refine |
| 27 | Fare vs Google | [x] | `PricingEngine` consumes route distance/duration only; Google is not pricing. Choose-ride high-demand/surge banner + tier quotes use `TripSession.surgeState` / zone geofences + live-or-synthetic preview length; pickup/stop/destination changes rebuild or clear preview so surge UI stays map-aligned (hardened 2026-08-23). |
| 28 | Kenya + DRC test | [ ] | **Device** - market/locale code exists; physical Kenya GPS + DRC override not evidenced |
| 29 | Map camera | [x] | Edge-inset fit; `cameraFocusNonce` re-fit/recenter; `userAdjustedCamera` gesture lock; throttled bearing follow |
| 30 | Map markers | [x] | Tip-anchored pickup/stop/dropoff teardrops; driver/nearby glyphs + zIndex; blue-dot via `showsUserLocation` when authorized |
| 31 | Nearby driver generation | [x] | Seeded around `pickup.coordinate` (GPS or market center) |
| 32 | Market-aware driver catalog | [x] | Mock drivers + tiers / ratings / vehicle class (local catalog) |
| 33 | Map style | [x] | Optional `VuumMapStyle.json` / Night / Lite; default Google if absent |
| 34 | Credential diagnostic screen | [x] | `DiagnosticsToolsView` Maps section — key present/absent (masked), SDK, bundle, last error; never raw key |
| 35 | Google usage telemetry | [x] | DEBUG ring buffer in `GoogleMapsDiagnostics` via `GoogleAPIHTTP` (api / status / duration / attempts; no key) |
| 36 | Package version audit | [x] | SPM `ios-maps-sdk` min **10.0.0** upToNextMajor; 11.x deferred; no CocoaPods - [`PLACES_SDK_DECISION.md`](PLACES_SDK_DECISION.md) |
| 37 | Places Swift SDK decision | [x] | Keep HTTPS Places (New); no `ios-places-sdk` - [`PLACES_SDK_DECISION.md`](PLACES_SDK_DECISION.md) |
| 38 | Places UI Kit | [x] | Not integrated - custom Vuum search kept |
| 39 | Unused Google APIs | [x] | [`GOOGLE_API_MATRIX.md`](GOOGLE_API_MATRIX.md) - Distance Matrix / Route Opt / Aggregate / UI Kit / legacy Places off client key |
| 40 | Directions vs Routes | [x] | Routes primary; Directions fallback; locked in [`GOOGLE_MAPS_ARCHITECTURE.md`](GOOGLE_MAPS_ARCHITECTURE.md) |
| 41 | Distance Matrix | [x] | Not called |
| 42 | Route Optimization API | [x] | Not called (backend/fleet later) |
| 43 | Places Aggregate | [x] | Not called |
| 44 | Geocoding | [x] | Apple-first policy in code + `GOOGLE_MAPS_SETUP.md`; Google Geocoding optional secondary only |
| 45 | API key splitting | [x] | Same key OK for now (documented); REST sends bundle header; split deferred until backend / Key A-B |
| 46 | Backend-ready providers | [x] | `RouteProvider` / `GoogleRouteProvider` (+ cache); domain Route has legs / traffic / static |
| 47 | No Google in views | [x] | Views call services / `TripSession` / `PlacesSearchController` |
| 48 | Google -> Vuum models | [x] | `Place`, `GeoPoint`, `RouteEngine.Route`, etc. |
| 49 | Network observability | [x] | `NetworkReachability` + DEBUG Google HTTPS request log |
| 50 | Performance | [x] | Coarse polyline rebuild signature; nearby nudge ~1.6 s; motion ~80 ms |
| 51 | Image / driver data | [x] | SF / drawn glyphs + placeholders (no huge remote photo fetch on map) |
| 52 | Background / foreground | [x] | `TripSession.handleAppWillEnterForeground/DidEnterBackground` + `VuumApp` wiring; no route re-fetch on resume |
| 53 | Active trip resilience | [x] | Lifecycle generation / cancel; synthetic path if live route fails |
| 54 | No duplicate after resume | [x] | Preview waypoint signature dedupe; `cancelInFlightGoogleWork` on trip cancel; `GoogleRouteProvider` skips Directions after cancel; Places cancels HTTP on background |
| 55 | Snyk / sync cleanup | [x] | No Snyk in CI; policy `NO_SNYK.md` |
| 56 | Xcode build audit | [x] | Classic project + SPM; unsigned Codemagic path |
| 57 | Release configuration | [~] | Codemagic builds **Debug** unsigned IPA (intentional Sideloadly path) |
| 58 | Sideload test | [ ] | **Device / operator** - evidence template empty |
| 59 | Full E2E test | [ ] | **Device** |
| 60 | Real location test | [ ] | **Device** |
| 61 | UX after Google | [x] | Software: Home map + Where-to + Services booking map preview + Places pickers (live when keyed). **Device** live-tile confirm still in `MAPS_POST_KEY_QA` |
| 62 | Realism audit | [~] | Software motion/route realism in place; live confirmation open |
| 63 | Account / settings second audit | [x] | Account shell + gated diagnostics (non-Maps) |
| 64–68 | RFQ / trust / corp / sales / discovery | [x] | Cross-covered by product directive + gap trackers; not Maps-blocking |
| 69 | Uber / Bolt capability matrix | [x] | [`MAPS_CAPABILITY_MATRIX.md`](MAPS_CAPABILITY_MATRIX.md) |
| 70 | Final Google Cloud recommendation | [x] | [`GOOGLE_API_MATRIX.md`](GOOGLE_API_MATRIX.md) recommends key set; **Console apply** still operator (§5) |
| 71 | Security principle | [x] | No committed secrets; placeholders ignored |
| 72 | Cost discipline | [x] | Field masks, sessions, debounce, throttle |
| 73 | Document Google integration | [x] | [`GOOGLE_MAPS_ARCHITECTURE.md`](GOOGLE_MAPS_ARCHITECTURE.md) + matrix + [`GOOGLE_MAPS_SETUP.md`](GOOGLE_MAPS_SETUP.md) |
| 74 | Google integration test plan | [x] | [`GOOGLE_INTEGRATION_TEST_PLAN.md`](GOOGLE_INTEGRATION_TEST_PLAN.md) (+ `MAPS_POST_KEY_QA.md`) |
| 75 | Do not stop after audit | [x] | Product directive / RFQ trackers parallel |
| 76 | Final product standard | [~] | Software bar met for presentation build; live Maps bar = §77 device |
| 77 | Final acceptance test | [ ] | **Device + keyed IPA** |
| 78 | Final report A–T | [x] | [`MAPS_HARDENING_FINAL_REPORT.md`](MAPS_HARDENING_FINAL_REPORT.md) - honest; Cloud/device acceptance still open in §T |

---

## Dependency graph (actual)

```
USER ACTION                    VUUM SERVICE                         GOOGLE / LOCAL              DOMAIN -> UI
───────────                    ────────────                         ─────────────              ──────────
Home / GPS                     RiderLocationManager                 Core Location              pickup Place
Pickup label                   ReverseGeocodingService              CLGeocoder -> optional Geocode  name + subtitle
Where to? typing               PlacesSearchController               Places API (New) HTTPS     suggestions
Select place                   PlacesSearchService.resolve          Place Details              Place
Confirm ride                   RouteEngine                          Routes -> Directions -> TripGeo  polyline + ETA
Fare panel                     PricingEngine                        (no Google)                CDF/KES quote
Map tiles / pins               VuumMapView + MapBootstrap           Maps SDK for iOS           GMSMapView
Driver motion                  TripSession                          local along route          MapPin.driver
Off-route                      RouteDeviationMonitor                local corridor math        rider notice
```

---

## API inventory (client)

| Google service | Used? | Where | Rider need? | Key stance |
|----------------|-------|-------|-------------|------------|
| Maps SDK for iOS | Yes | `MapBootstrap`, `VuumMapView` | Yes | Keep |
| Places API (New) | Yes | `PlacesSearchService` | Yes | Keep |
| Routes API | Yes | `RoutesAPIService` | Yes | Keep |
| Directions API | Yes (fallback) | `DirectionsRouteService` | Yes | Keep on key if fallback desired |
| Geocoding API | Optional (reverse fallback) | `ReverseGeocodingService` after Apple fails | Nice-to-have | Off key OK; Apple-first |
| Places SDK / Swift / UI Kit | No | - | No | Do not add for presentation |
| Distance Matrix | No | - | No | Off iOS key |
| Route Optimization | No | - | Backend later | Off iOS key |
| Places Aggregate | No | - | No | Off iOS key |

---

## Blocking unfinished (2)

- [ ] **Codemagic keyed build** - `vuum_secrets` -> `VUUM_GOOGLE_MAPS_API_KEY`; enable Maps / Places (New) / Routes (/ Directions); restrict iOS `com.vuum.app`; run `ios-release`; Sideloadly IPA  
- [ ] **Device verify** - execute [`GOOGLE_INTEGRATION_TEST_PLAN.md`](GOOGLE_INTEGRATION_TEST_PLAN.md); complete [`MAPS_POST_KEY_QA.md`](MAPS_POST_KEY_QA.md) and fill [`DEVICE_QA_EVIDENCE.md`](DEVICE_QA_EVIDENCE.md); include Kenya GPS + DRC market override smoke

---

## Residual non-blocking (audit niceties)

Do **not** block Codemagic for these:

| Item | Audit # | Note |
|------|--------:|------|
| Maps credential panel in Diagnostics (no key value) | 34 | **Done** |
| Google request telemetry ring buffer | 35 / 49 | **Done** (DEBUG) |
| Shared Google→VUUM error mapper + route Retry CTA | 17 / 18 | **Done** (`GoogleAPIError` + `L10n.Maps`) |
| Map unavailable / invalid-key / network fail UX | — | **Done** rider plane + L10n; device F7 / revoked-key still open |
| Bounded Google HTTP retry / backoff | 19 | **Done** (`GoogleAPIHTTP`) |
| Place-type / category icons + distance chrome | 12 / 13 | **Done** |
| Places `includedTypes` filtering | 12 | Optional airport/hotel modes — residual |
| Place details / identical-route TTL cache | 16 | **Done** (`BoundedTTLCache` / `MapsRequestCache`) |
| Formal `RouteProvider` protocols | 46 | **Done** (`GoogleRouteProvider`) |
| Cloud restriction confirmation | 5 | Operator checklist (paired with blocking #1) |

---

## Home / booking map slice (2026-08-23)

| Surface | | Evidence |
|---------|:-:|----------|
| Home map preview | [x] | `HomeHubView` -> `TripMapLayer` / `VuumMapView` |
| Where-to | [x] | `DestinationScaffoldView` + `PlacesSearchController` |
| Services booking map preview | [x] | `ProductBookingForm` compact map (pins + straight preview; no Routes call) |
| Place pickers (live Places when keyed) | [x] | `PlaceSearchPickerSheet`, Adjust pickup search, product pickup/drop-off |
| Product sheet pickup seed | [x] | Most sheets use `tripSession.pickup` (Hotel keeps hotel-first) |

---

## Fallback / unavailable UX audit

**Focus:** maps unavailable · invalid key · network fail · placeholder↔live · no demo language  
**Date:** 2026-08-23 · **Snyk:** not used · **Commit:** none

| Item | | Evidence |
|------|:-:|----------|
| Missing / placeholder key -> no crash | [x] | `MapBootstrap.configureIfNeeded`; trip UI continues |
| Rider unavailable plane (polished) | [x] | `MapPlaceholderView` - icon, subtle grid, light/dark |
| No demo / “Add API key” in UI | [x] | `L10n` `map.unavailable_title` / `map.unavailable_detail` |
| Placeholder ↔ live switch | [x] | `MapBootstrap.surface` / `isConfigured` at `makeUIView`; live after key + relaunch |
| Reject build placeholders / macros / short keys | [x] | `MapBootstrap.isUsableAPIKey` |
| Network offline UX | [x] | `VuumOfflineBanner` + Retry |
| Places / Routes fail graceful | [x] | Local catalog / synthetic route; DEBUG logs only |
| Revoked key that still looks valid | [~] | SDK boots; Google may show its tile chrome; trip UI continues |
| L10n maps/places/route error strings (EN/FR/LN/SW) | [x] | `L10n.Maps` / `Places` / `Route` + `maps.error_*` / `places.error_*` / `route.*` |
| Central Unable-to / Retry for routes | [~] | Rider copy + `GoogleAPIError` done; in-flow Retry CTA still optional residual |

---

## Owning files (quick map)

| Owning files | Paths |
|------|--------|
| Bootstrap / key | `ios/Vuum/Maps/MapBootstrap.swift`, `ios/Secrets.example.xcconfig`, `codemagic.yaml` |
| Map UI | `ios/Vuum/Maps/VuumMapView.swift`, `VuumMapStyle*.json` |
| Home / booking | `HomeHubView.swift`, `ProductBookingForm.swift`, `FlowScaffolds.swift` (`DestinationScaffoldView`, `AdjustPickupSheet`), `SavedPlacesView.swift` (`PlaceSearchPickerSheet`) |
| Routing | `RouteProvider.swift`, `RouteEngine.swift`, `RoutesAPIService.swift`, `DirectionsRouteService.swift` |
| Places | `PlacesSearchService.swift`, `PlacesSearchController.swift` |
| Geo / location | `ReverseGeocodingService.swift`, `RiderLocationManager.swift`, `TripGeo.swift` |
| Trip / motion | `TripSession.swift`, `RouteDeviationMonitor.swift` |
| Fare | `PricingEngine.swift` |
| Tests | `MapBootstrapKeyTests`, `RouteDeviationTests`, `ReverseGeocodingNamingTests`, ... |
| Docs | `GOOGLE_API_MATRIX.md`, `GOOGLE_MAPS_ARCHITECTURE.md`, `GOOGLE_INTEGRATION_TEST_PLAN.md`, `GOOGLE_MAPS_SETUP.md`, `PLACES_SDK_DECISION.md`, `PRE_BUILD_MAPS_GATE.md`, `MAPS_POST_KEY_QA.md` |
