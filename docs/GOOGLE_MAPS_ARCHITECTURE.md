# Google Maps Architecture — Vuum iOS

**Reconcile date:** 2026-08-23  
**Companion docs:** [`GOOGLE_MAPS_SETUP.md`](./GOOGLE_MAPS_SETUP.md) · [`GOOGLE_API_MATRIX.md`](./GOOGLE_API_MATRIX.md) · [`GOOGLE_INTEGRATION_TEST_PLAN.md`](./GOOGLE_INTEGRATION_TEST_PLAN.md) · [`CODEMAGIC_SETUP.md`](./CODEMAGIC_SETUP.md)

Closes audit **§40**, **§46**, **§73** (architecture write-up). Describes the live stack: **MapBootstrap → VuumMapView → RouteProvider / RouteEngine → Places → TripSession**.

---

## 1. Design principles

| Principle | Practice in Vuum |
|-----------|------------------|
| One key loader | `MapBootstrap` only; SwiftUI never holds raw keys |
| SDK where tiles matter | Maps SDK for iOS via SPM |
| Web APIs for search/route | Places (New), Routes, Directions, Geocoding over HTTPS |
| Domain models at the boundary | `Place`, `GeoPoint`, `RouteEngine.Route` — not raw Google JSON in views |
| Swappable routing | `RouteProvider` → `GoogleRouteProvider` (future `RemoteVuumRouteProvider`) |
| Always bookable offline | Catalog / synthetic / `CLGeocoder` fallbacks; no “demo” copy in UI |
| Fare ≠ Google | `PricingEngine` / `MockFares` |

---

## 2. Packages & versions

| Package | Source | In project? |
|---------|--------|-------------|
| **GoogleMaps** | SPM `https://github.com/googlemaps/ios-maps-sdk` (min **10.0.0**, `upToNextMajor`) | Yes |
| GooglePlaces / PlacesSwift | — | **No** (Places via HTTPS New) |
| Places UI Kit | — | **No** (intentional) |
| CocoaPods / Podfile | — | **No** |

Exact resolved SPM revision may vary; see Xcode / `Package.resolved` when present. Prefer SPM; do not add CocoaPods. Places decision: [`PLACES_SDK_DECISION.md`](./PLACES_SDK_DECISION.md).

---

## 3. Locked decision: Routes primary, Directions fallback (§40)

| Role | API | Code |
|------|-----|------|
| **Primary** | Routes API `computeRoutes` (`TRAFFIC_AWARE`) | `RoutesAPIService` |
| **Fallback** | Directions API JSON (`departure_time=now`) | `DirectionsRouteService` |
| **Last resort** | Local geometry + fixed-speed ETA | `RouteEngine.synthetic` / `TripGeo` |

**Why both stay in tree**

- Routes is Google’s current recommendation for traffic-aware driving routes, field masks, and intermediates.
- Directions remains only when Routes returns nil (key restriction, billing, outage, or empty response) so the rider still gets a road polyline when Directions is enabled on the same iOS key.
- They are **not** parallel primaries. `GoogleRouteProvider` always tries Routes first.

**Do not**

- Call Directions when Routes already succeeded.
- Add Distance Matrix / Route Optimization on the rider iOS key for this presentation build.
- Pass raw Google JSON into SwiftUI — map into `RouteEngine.Route`.

---

## 4. RouteProvider (§46)

```
RouteProvider
  └── GoogleRouteProvider   // Routes → Directions → synthetic
  └── (future) RemoteVuumRouteProvider
```

- Protocol: `ios/Vuum/Maps/RouteProvider.swift`
- Facade used by `TripSession`: `RouteEngine` (`provider` injectable for tests / server routing later)
- Domain model: `RouteEngine.Route` with coordinates, distance, preferred duration, `trafficDurationSeconds`, `staticDurationSeconds`, `legs`, `waypoints`, `source`

### ETA rules

| Phase | Source |
|-------|--------|
| Preview / assign | `Route.durationSeconds` when live (`isTrafficAware`); else class / synthetic speed |
| Approach motion | Baseline from approach route duration; tick via `TripMotionTiming.displayedETAMinutes` |
| In-trip motion | Baseline from booked / live leg duration (not `distance / fixedSpeed`); tick via same helper |
| Synthetic only | `TripGeo.etaMinutes(speedKmh:)` |

`ActiveTrip.routeDurationSeconds` stores the booked trip duration so mid-leg and destination-change ETAs can scale remaining distance against the live route clock.

---

## 5. Layer map

```
┌─────────────────────────────────────────────────────────────┐
│  SwiftUI (UI/Flow, UI/Main)                                 │
│  PlacesSearchController · ActiveTripFlowView · …            │
└────────────┬───────────────────────────────┬────────────────┘
             │                               │
             ▼                               ▼
┌────────────────────────┐    ┌──────────────────────────────┐
│ TripSession            │    │ VuumMapView (UIViewRepresent)│
│ pickup/dropoff/stops   │───▶│ pins, route polyline, camera │
│ phases, motion, fare   │    └──────────────▲───────────────┘
└───┬────────┬───────────┘                   │
    │        │                               │
    │        ▼                               │
    │  RouteEngine (RouteProvider facade)    │
    │    → GoogleRouteProvider               │
    │         → RoutesAPIService (HTTPS)     │
    │         → DirectionsRouteService       │
    │         → TripGeo synthetic            │
    │                                        │
    ▼                                        │
 PlacesSearchService ◀── PlacesSearchController
 ReverseGeocodingService                     │
 RiderLocationManager (Core Location)        │
                                             │
 MapBootstrap.configureIfNeeded() ───────────┘
   GMSServices.provideAPIKey(resolved key)
```

### Ownership

| Layer | Files | Role |
|-------|-------|------|
| Bootstrap | `Maps/MapBootstrap.swift`, `App/VuumApp.swift` | Resolve key; `provideAPIKey` once |
| Map UI | `Maps/VuumMapView.swift` + optional `VuumMapStyle*.json` | `GMSMapView` when configured; else placeholder |
| Routes | `Maps/RouteProvider.swift`, `Maps/RouteEngine.swift`, `Services/RoutesAPIService.swift`, `Maps/DirectionsRouteService.swift` | Live → fallback → synthetic |
| Places | `Services/PlacesSearchService.swift`, `PlacesSearchController.swift` | Autocomplete + Details + session token |
| Geocode | `Services/ReverseGeocodingService.swift` | Apple-first → optional Google → coord label |
| Trip | `Services/TripSession.swift`, `TripGeo.swift`, `TripMotionTiming.swift`, `RouteDeviationMonitor.swift` | Lifecycle, motion along polyline, deviation |
| Pricing | `Services/PricingEngine.swift`, `Mock/MockCatalog.swift` | Local fare from distance |

---

## 6. Request flow (user → Google → domain → UI)

### Search / destination

```
User types → PlacesSearchController (debounce ~300 ms, cancel stale)
  → PlacesSearchService.autocompleteOutcome
       [key] HTTPS Places New (session UUID)
       [no key / fail] MockPlaces fuzzy catalog
  → Suggestion → resolve (Details) → Place
  → TripSession dropoff / saved places UI
```

### Pickup from GPS

```
RiderLocationManager → TripSession.updatePickup
  → ReverseGeocodingService (throttled)
       Apple CLGeocoder first
       [key] optional Geocoding REST secondary
       else “Current location” + coordinates
  → Place label on sheet / map pin
```

### Choose ride / match / in-trip / change destination

```
TripSession builds waypoints (pickup, stops, dropoff)
  → RouteEngine.route / route(through:)  // via RouteProvider
       1. RoutesAPIService.computeRoutes (TRAFFIC_AWARE)
       2. DirectionsRouteService
       3. TripGeo synthetic samples
  → RouteEngine.Route { coordinates, distance, duration, traffic/static, legs, source }
  → TripSession polylines / ETA inputs / PricingEngine distance
  → VuumMapView.route + driver motion along geometry
```

---

## 7. API keys & environment

**Resolution order** (`MapBootstrap.resolvedAPIKey`):

1. Process env `VUUM_GOOGLE_MAPS_API_KEY` (scheme / CI process)
2. Info.plist `VUUM_GOOGLE_MAPS_API_KEY`
3. Info.plist `GMSApiKey`

Placeholders (`YOUR_GOOGLE_MAPS_API_KEY`, unsubstituted `$(…)`, etc.) are skipped.

| Consumer | How key is applied |
|----------|--------------------|
| Maps SDK | `GMSServices.provideAPIKey` |
| Places / Routes / Directions / Geocoding | Same string via `MapBootstrap.resolvedAPIKey()` + `X-Ios-Bundle-Identifier` on REST |

**Codemagic:** secure group `vuum_secrets` → write `ios/Secrets.xcconfig` + optional `xcodebuild` env. See setup docs.

**Restrictions (operator):** iOS + `com.vuum.app`; API allow-list per [`GOOGLE_API_MATRIX.md`](./GOOGLE_API_MATRIX.md). One universal client key today — key splitting (SDK vs web vs backend) is deferred until backend (§45).

**Security notes:**

- No real keys in git-tracked configs
- ATS default (HTTPS only)
- Do not log key values

---

## 8. Billing & cost discipline

| Control | Implementation |
|---------|----------------|
| Places session tokens | One UUID per typing session; cleared after Details / abandon |
| UI debounce | ~280–300 ms before autocomplete |
| Field masks | Details: `id,displayName,formattedAddress,location`; Routes includes duration/staticDuration/legs/polyline |
| Reverse geocode throttle | ~45 m move **or** ~18 s in `TripSession` |
| Route cascade | Single preferred Routes call; Directions only on failure |
| Unused SKUs | Not called; remove from key (matrix) |

**Gaps:** no bounded Places/route/geocode caches; no DEBUG Google request telemetry yet.

---

## 9. Error handling & caching

| Path | On failure |
|------|------------|
| Map tiles / SDK | Placeholder map; booking continues |
| Places | Local catalog; rider does not see credential messaging |
| Routes | Directions → synthetic polyline (always drawable) |
| Geocoding | `CLGeocoder` → coordinate subtitle |
| HTTP | Single-shot `URLSession` (no shared retry/backoff mapper yet) |

There is **no** central `GoogleMapsError` → L10n map yet (§17–§19). Prefer silent product continuity over exposing vendor errors; add Retry UX later where useful.

---

## 10. TripSession ↔ Maps coupling

`TripSession` owns trip state; maps/services are dependencies:

- Seeds nearby vehicles from pickup coordinate
- Builds approach + trip polylines through `RouteEngine` / `RouteProvider`
- Stores `ActiveTrip.routeDurationSeconds` for in-trip ETA scaling
- Moves driver along route geometry with heading; displayed ETA from route baseline, not fixedSpeed
- Throttles reverse geocode on GPS updates
- Mid-trip destination change invalidates in-flight route fetches and rebuilds remaining path
- Fare uses route distance, not Google pricing

Views observe `@Published` trip fields and pass coordinates into `VuumMapView` — they do not call Google HTTP directly.

---

## 11. Testing posture

| Mode | Expectation |
|------|-------------|
| No / placeholder key | Full trip UI; catalog search; synthetic routes; Apple/coord geocode |
| Valid restricted key | Live tiles, Places, Routes (Directions if Routes blocked) |
| Invalid / wrong-bundle key | Degrade like missing key or HTTP failure paths |
| Offline | Synthetic + catalog; Core Location may still work |

Executable cases: [`GOOGLE_INTEGRATION_TEST_PLAN.md`](./GOOGLE_INTEGRATION_TEST_PLAN.md). Unit tests cover trip/route math without live Google (`RouteEngineProviderTests`, `docs/TESTING.md`).

---

## 12. What this architecture deliberately excludes

- Places UI Kit / Aggregate / Distance Matrix / Route Optimization client calls  
- Firebase Maps / CocoaPods Maps  
- Hard-coded secrets  
- Explaining mock/fallback behavior in rider-facing copy
