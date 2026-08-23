# VUUM — POST-IMPLEMENTATION GOOGLE MAPS/API ARCHITECTURE AUDIT + FINAL PRODUCT HARDENING

## STATUS TRACKER (verified in repo — 2026-08-23)

Gap matrix: [`docs/MAPS_AUDIT_GAP_STATUS.md`](docs/MAPS_AUDIT_GAP_STATUS.md).  
**Rule:** only items confirmed in source/CI are checked. Unverified Cloud Console, device QA, and missing docs stay unchecked.

### Verified done

- [x] §1 — Maps stack inventory completed (see gap status)
- [x] §3 — Google Maps via SPM only; no CocoaPods / Podfile
- [x] §4 — Centralized key load (`MapBootstrap`; no hard-coded secrets in Swift)
- [x] §7 — Routes stack: `RouteProvider` / `GoogleRouteProvider` → `RoutesAPIService` (`TRAFFIC_AWARE`) → `DirectionsRouteService` fallback → synthetic; domain `RouteEngine.Route` (legs, traffic/static duration, waypoints)
- [x] §8 — Route polyline from Routes/Directions response when keyed (else synthetic)
- [x] §9 — Traffic-aware ETA when keyed: assign/approach uses Routes/Directions duration; in-trip uses booked/live route baseline (`routeDurationSeconds` + `displayedETAMinutes`); synthetic uses fixed-speed last
- [x] §10 — Places autocomplete session tokens + UI debounce (~280 ms)
- [x] §11 — Place Details field mask (`id,displayName,formattedAddress,location,types,primaryType`)
- [x] §12–§13 — `PlaceCategory` taxonomy + type icons + compact subtitle (address · category · distance)
- [x] §14 — permission-map: auth → blue-dot (`showsUserLocation`); denied/unavailable/approximate banners; precise upgrade; stale/accuracy gate on pickup GPS
- [x] §15 — Reverse geocode Apple-first → Google when keyed → coords; throttle 45 m / 18 s (`TripSession` + `ReverseGeocodingService`)
- [x] §15 / pickup naming — “Current location” only for unresolved GPS (`id == current`); hardened 2026-08-23
- [x] §16 — Bounded caches: `MapsRequestCache` over `BoundedTTLCache` (places / routes / geocode)
- [x] §22 — Autocomplete generation + query-string stale-response ignore (`PlacesSearchController`)
- [x] §44 — Geocoding Apple-first + Google fallback; bundle header on REST (`GOOGLE_MAPS_SETUP.md`)
- [x] §45 — Same key OK for presentation (SDK + REST); REST bundle header; Key A/B split deferred until backend
- [x] §23 — Driver marker follows route geometry with heading
- [x] §24 — Trip route reuse: assign stores pickup + trip polylines; in-trip legs via `subpath`/`pathBetween`; keyed early-leg RouteEngine refine
- [x] §25 — Route-deviation corridor monitor (`RouteDeviationMonitor`)
- [x] §25 — Deviation banner still evaluates against live `ActiveTrip.tripRoute` (Routes/Directions when keyed); in-trip legs reuse that polyline via `TripGeo.pathBetween`/`subpath`
- [x] Airport / downtown / demand zones — `ServiceZoneCatalog` geofences + Home/Services surcharge banners (`zoneContext`)
- [x] Zone map visualization — **not required** for rider UX (no geofence circle overlays on `VuumMapView`; messaging via banners / product gating)
- [x] §26 — Multi-stop on map: Routes `intermediates` / Directions waypoints; stop pins + fit; preview/assign/`through:`; in-trip legs via `subpath` + keyed live leg refine
- [x] §27 — Fare/pricing separate from Google (`PricingEngine` / `MockFares`) — airport toll / surge consume zone helpers, not Google
- [x] §27 pricing-map — Choose-ride high-demand/surge banner over map; fares reprice from live preview polyline; pickup/stop/destination rebuild clears stale geography
- [x] §30 — Pickup / dropoff / stop / driver / nearby markers in `VuumMapView`
- [x] §29 — Camera: fit bounds (edge insets), recenter (`cameraFocusNonce`), gesture lock, throttled follow
- [x] §29 / §30 — Blue-dot my-location only when Core Location authorized (`showsUserLocation`)
- [x] §33 — Optional brand map styles (day / lite / night) when Maps key present
- [x] §31 — Nearby fleet seeded relative to pickup coordinate
- [x] §38 — Places UI Kit **not** integrated (correct for custom booking UI)
- [x] §40 — Directions kept as **justified fallback** only (`GoogleRouteProvider` / `RouteEngine`: Routes → Directions → synthetic); locked in [`docs/GOOGLE_MAPS_ARCHITECTURE.md`](docs/GOOGLE_MAPS_ARCHITECTURE.md)
- [x] §46 — Formal `RouteProvider` + `GoogleRouteProvider`; `RouteEngine.Route` has legs / traffic / static duration / waypoints
- [x] §41 — Distance Matrix **not** called from iOS
- [x] §42 — Route Optimization API **not** called from iOS
- [x] §43 — Places Aggregate **not** called from iOS
- [x] §47 — SwiftUI views do not own raw Google HTTP / keys
- [x] §55 — No Snyk/Synk in Codemagic; workspace no-Snyk rule
- [x] Codemagic inject — `VUUM_GOOGLE_MAPS_API_KEY` → `ios/Secrets.xcconfig` + xcodebuild
- [x] §36 — GoogleMaps SPM pin `upToNextMajorVersion` from **10.0.0** (11.x not forced)
- [x] §37 — Places via HTTPS decision: [`docs/PLACES_SDK_DECISION.md`](docs/PLACES_SDK_DECISION.md)
- [x] Map unavailable UX — polished rider plane (`MapPlaceholderView`); **no** “Add Maps API key” / demo language (`L10n` `map.unavailable_*`)
- [x] Placeholder ↔ live switch — `MapBootstrap.surface` / `isConfigured` at launch; usable key → `GMSMapView`, else unavailable plane (rebuild/relaunch after key inject)
- [x] Network offline banner — `VuumOfflineBanner` + Places/Routes silent local/synthetic fallback (no raw Google errors)
- [x] L10n maps/places/route errors — EN/FR/LN/SW via `L10n.Maps` / `L10n.Places` / `L10n.Route` + `GoogleAPIError.riderMessage` keys (`maps.error_*`); route deviation copy localized; no demo wording
- [x] §69 — Uber/Bolt capability matrix → [`docs/MAPS_CAPABILITY_MATRIX.md`](docs/MAPS_CAPABILITY_MATRIX.md)
- [x] §78 — Final report A–T → [`docs/MAPS_HARDENING_FINAL_REPORT.md`](docs/MAPS_HARDENING_FINAL_REPORT.md)
- [x] §73 / §74 — [`docs/GOOGLE_MAPS_ARCHITECTURE.md`](docs/GOOGLE_MAPS_ARCHITECTURE.md); [`docs/GOOGLE_API_MATRIX.md`](docs/GOOGLE_API_MATRIX.md); [`docs/GOOGLE_INTEGRATION_TEST_PLAN.md`](docs/GOOGLE_INTEGRATION_TEST_PLAN.md)
- [x] Home / Services booking map — `HomeHubView` `TripMapLayer` + Services `ProductBookingForm` map preview (pins; no billable Routes on form open)
- [x] Where-to / destination search — `DestinationScaffoldView` + `PlacesSearchController` (session, debounce, live Places when keyed)
- [x] Place pickers — `PlaceSearchPickerSheet` / Adjust pickup / product pickup·drop-off use Places when keyed (GPS/pickup bias; catalog fallback)
- [x] §12–§13 (software) — Place type icons + distance chrome on pickers; `includedTypes` filtering still optional
- [x] REST `X-Ios-Bundle-Identifier: com.vuum.app` — `GoogleMapsREST` / `MapBootstrap.applyIOSBundleIdentifierHeader`
- [x] §52 / §54 — Background/resume: no duplicate Google route/Places calls; cancel in-flight on trip cancel (`TripSession.cancelInFlightGoogleWork`, preview waypoint dedupe, `GoogleRouteProvider` cancel between hops, Places background cancel). Units in `TripSessionLifecyclePhaseTests`. Device resume under live key still in F-plan.
- [x] **safety-map** — Share-trip / SOS include live GPS when `RiderLocationManager.latestLocation` is available (`TripShare.message` / `sosDetailBody` + Maps deep link); omit coords when unavailable
- [x] **safety-map** — Active-trip / Safety toolkit / Safety settings / driver share bars pass live coordinate into share + `requestSOS(coordinate:)`
- [x] **safety-map** — Map hardening: `TripMapLayer` enables blue-dot only when authorized and starts updates on appear (`showsUserLocation: location.isAuthorized`)


### Explicitly not verified / open (do not check until proven)

- [x] §2 / §39 — Written Google API keep/remove matrix → [`docs/GOOGLE_API_MATRIX.md`](docs/GOOGLE_API_MATRIX.md)
- [ ] §70 — Cloud Console key restrictions **applied** (recommended set in matrix; operator)
- [ ] §5 — Live API key restricted to `com.vuum.app` + minimal API set (Console)
- [ ] §12–§13 (optional) — Places `includedTypes` filtering for airport/hotel modes
- [x] §16 / §18–§19 / §35 / §49 — Caching (`MapsRequestCache` / place TTL), `GoogleAPIError`, `GoogleAPIHTTP` retry, `GoogleMapsDiagnostics` telemetry
- [x] §17 — Rider-safe Maps errors via `L10n.Maps` / `maps.error.*` (no raw Google JSON)
- [x] §34 — Maps credential diagnostics panel (`DiagnosticsToolsView` → Maps credentials)
- [ ] §56–§60 / §77 — Xcode warning pass, sideload + Kenya/DRC device E2E
- [ ] Device F1–F7 (`docs/MAPS_POST_KEY_QA.md`) — offline / invalid-key / Places fail on keyed Sideload build; background→foreground smoke

---

## CONTEXT

We have now completed the previous VUUM development directive.

The application has already been substantially implemented.

We have now also:

- created the Google Cloud project
- configured billing
- enabled the required Google Maps Platform services
- added the Google credentials/API key
- integrated Google Maps into the application
- moved beyond the placeholder-map stage
- built and sideloaded the application to a physical iPhone

DO NOT assume this means the Google integration is correct.

This phase is an **engineering audit and hardening pass**.

Your job now is to inspect the actual repository and verify that the implementation follows Google's current recommended iOS architecture, API usage patterns, security guidance, request patterns, SDK versions, field-selection practices, billing-conscious behavior, error handling and credential restrictions.

Do not simply check:

"Does the map appear?"

That is not enough.

We need to establish:

**Does VUUM use Google Maps Platform correctly?**

---

# 1. FIRST: AUDIT WHAT ACTUALLY EXISTS

Before making modifications, inspect:

- Xcode project
- Swift Package dependencies
- GoogleMaps imports
- GooglePlaces imports
- GooglePlacesSwift imports if present
- Maps initialization
- Places initialization
- API key loading
- Info.plist
- build settings
- environment configuration
- Codemagic configuration
- route service
- autocomplete implementation
- geocoding implementation
- reverse geocoding
- distance calculations
- ETA calculations
- polyline rendering
- driver marker movement
- location services
- network layer
- all Google API calls
- all Google HTTP endpoints
- all API error handling
- caching
- retries
- logging

Create an internal dependency graph showing:

USER ACTION
→ VUUM SERVICE
→ GOOGLE SDK / API
→ RESPONSE
→ VUUM DOMAIN MODEL
→ UI

Do this before refactoring.

---

# 2. GOOGLE API INVENTORY

Our Google Cloud project currently has these enabled:

- Directions API
- Distance Matrix API
- Geocoding API
- Maps SDK for iOS
- Places Aggregate API
- Places API
- Places API (New)
- Places UI Kit
- Route Optimization API
- Routes API

Do NOT assume all of these are required.

Determine which ones the VUUM iOS application is ACTUALLY using.

Produce an internal table:

| Google Service | Actually Used? | Where | Why | Needed for Rider App? | Remove/Keep |
|---|---|---|---|---|---|

Important:

Do not make API calls simply because an API is enabled.

Do not add unnecessary services just because they appear in Google Cloud.

Do not preserve legacy services merely because they were initially enabled.

---

# 3. USE GOOGLE'S CURRENT IOS SDK ARCHITECTURE

Audit the application against Google's current documentation.

Google currently recommends native iOS SDKs where available.

Maps SDK for iOS supports Swift Package Manager.

Places SDK for iOS also supports Swift Package Manager.

Google's current Places Swift SDK is the Swift-native implementation for the newer Places APIs and currently provides capabilities including:

- Autocomplete
- Place Details
- Photos
- Text Search
- Nearby Search
- Places UI Kit

The current Places Swift SDK is in preview, while the underlying Places SDK for iOS remains available and can be migrated incrementally.

Source:
Google's current Maps/Places iOS documentation.

DO NOT blindly migrate the project just because a newer SDK exists.

Instead:

1. determine which Google packages are currently installed
2. determine their exact versions
3. determine whether the implementation is using the legacy or current APIs
4. determine whether migration provides actual value
5. migrate only if it improves correctness, maintainability or future compatibility
6. ensure the application still builds on the project's existing Xcode/iOS target

Google's current documentation says Maps/Places SDK 11.0.0 is available and CocoaPods is deprecated in version 11.0.0.

Therefore:

**Prefer Swift Package Manager.**

Do not introduce CocoaPods.

If CocoaPods exists unnecessarily, remove it carefully after verifying the project does not depend on it.

---

# 4. GOOGLE API KEY ARCHITECTURE

Audit how the API key gets into the app.

It must NOT be:

- hard-coded in multiple Swift files
- committed into source
- copied into random views
- duplicated across configuration files
- printed to logs
- stored in a random constant

Use one centralized configuration strategy.

The current intended architecture is:

development environment
→ build configuration/environment secret
→ application configuration
→ Google initialization

The source code should not contain the actual secret.

### §4 Audit checklist (API key architecture)

- [x] Centralized loader only (`MapBootstrap`) — no hard-coded keys in views/services
- [x] Resolution order: scheme/process env → Info.plist `VUUM_GOOGLE_MAPS_API_KEY` → Info.plist `GMSApiKey`
- [x] Placeholder / unsubstituted-macro detection skips bad values and continues to next source
- [x] `Vuum.xcconfig` default placeholder + optional `#include? ../../Secrets.xcconfig`
- [x] `Secrets.example.xcconfig` template only; `Secrets.xcconfig` gitignored
- [x] Info.plist substitutes `$(VUUM_GOOGLE_MAPS_API_KEY)` for both `VUUM_GOOGLE_MAPS_API_KEY` and `GMSApiKey`
- [x] Shared scheme env entry present but **disabled** by default (placeholder cannot shadow Secrets)
- [x] Codemagic: secure env → write `ios/Secrets.xcconfig` + pass key to `xcodebuild` only when set
- [x] Bundle ID consistent: `PRODUCT_BUNDLE_IDENTIFIER = com.vuum.app`
- [x] No real API keys in committed files
- [x] Credential-doc: post-key operator checklist in `docs/GOOGLE_MAPS_SETUP.md` §7 (APIs, `com.vuum.app`, `vuum_secrets`, rotate-if-leaked)
- [ ] Operator: restrict Google Cloud key to iOS + `com.vuum.app` (console — not code)
- [ ] Operator: set Codemagic group `vuum_secrets` / local Secrets with real key and verify live tiles

---

# 5. API KEY RESTRICTIONS

Google's current security guidance recommends:

- application restrictions
- API restrictions
- separate keys for different applications/platforms where appropriate

For iOS applications, the recommended application restriction is:

**iOS apps**

using the application's **bundle identifier**.

The API key should also be restricted to only the APIs that the application actually uses.

Audit the current Google key.

Determine:

- Is it restricted to iOS?
- Does the bundle identifier exactly match the VUUM app?
- Are unnecessary APIs permitted?
- Are there services enabled in the key that VUUM never uses?
- Are there web-service APIs being called directly from the iPhone?
- Is the current key being used for both SDKs and REST calls?
- Should the architecture use separate keys?

DO NOT change the Google Cloud configuration automatically if doing so could break the currently functioning application.

Instead:

1. inspect actual usage
2. determine the correct restriction set
3. modify safely
4. test after restrictions are applied

### §5 Credential-doc checklist (recommended restriction set)

Documented for operators in `docs/GOOGLE_MAPS_SETUP.md` (Cloud steps + §7 post-key checklist). Console confirmation remains operator-owned.

- [x] Documented application restriction: **iOS apps** + bundle **`com.vuum.app`**
- [x] Documented API restriction set for the rider iOS key: **Maps SDK for iOS**, **Places API (New)**, **Routes API**, **Directions API** (fallback)
- [x] Documented: project-enabled extras (Distance Matrix, Places Aggregate, Route Optimization, etc.) must **not** be added to this iOS key
- [x] Documented Codemagic group **`vuum_secrets`** + `VUUM_GOOGLE_MAPS_API_KEY`
- [x] Documented rotate / regenerate if the key leaked (chat, commit, screenshot, public CI log)
- [ ] Operator: confirm Google Cloud key matches the documented set
- [ ] Operator: remove unused APIs from the key after a live verify (if currently over-broad)

---

# 6. VERY IMPORTANT — SDK VS WEB-SERVICE USAGE

Determine which Google capabilities are being accessed through:

### Native iOS SDK

Examples:

- Maps SDK for iOS
- Places SDK for iOS

versus:

### HTTP / REST APIs

Examples:

- Routes API
- Geocoding API
- Directions API
- Distance Matrix API
- other web services

Do not mix these casually.

For every HTTP API call, document:

- endpoint
- method
- authentication
- API key used
- request headers
- request body
- response model
- timeout
- retry
- error mapping
- logging behavior
- whether it belongs on the client or server

Google explicitly warns that web-service keys are sensitive and should generally be protected server-side. For direct mobile web-service usage, Google provides additional controls such as iOS bundle identification headers where supported, but a backend proxy is preferred where appropriate.

Therefore:

### DO NOT

Create a giant generic:

`GoogleAPIService.request(endpoint:)`

that lets the iPhone call arbitrary Google endpoints with the key.

Instead, use typed domain-specific services.

For example:

`RouteService`

`PlaceSearchService`

`GeocodingService`

`DistanceService`

etc.

---

# 7. ROUTES API AUDIT

Inspect the actual implementation of routing.

Determine whether VUUM is using:

- Routes API
- Directions API
- a third-party routing API
- locally calculated distances
- fake route geometry

If both Routes API and Directions API are being used for the same job, determine why.

Do not maintain two different routing systems unless there is a justified fallback strategy.

Prefer the current routing architecture where appropriate.

The route service must return a coherent domain model containing at minimum:

- route
- distance
- duration
- ETA
- polyline
- legs
- waypoints/stops
- route metadata

Do not pass raw Google JSON throughout the SwiftUI application.

Create VUUM domain models.

---

# 8. ROUTE POLYLINE

Verify that the route polyline actually comes from the route response.

Do not draw a fake straight line between pickup and destination.

Do not use arbitrary interpolation when a real route exists.

The map should:

1. receive pickup
2. receive destination
3. request route
4. receive route geometry
5. draw the correct route
6. fit camera bounds
7. calculate/display distance
8. calculate/display ETA

---

# 9. ETA

### Traffic layer / ETA refresh (battery-conscious)

- [x] Optional traffic layer on `GMSMapView` (`isTrafficEnabled`) � **off by default**
- [x] Traffic only when Maps API key present + rider opt-in + not low-data (`MapTrafficSettings`)
- [x] Optional live ETA refresh via `RouteEngine` during approach / in-trip � **off by default**
- [x] ETA refresh gated on API key + opt-in; 90s interval to limit battery/billing
- [x] Settings toggles under Maps; low-data forces both off
- [x] �9 ETA: prefer traffic-aware duration when live refresh returns Routes/Directions result

Do not calculate ETA using:

`distance / fixedSpeed`

when Google's route/traffic result is available.

Use the route response appropriately.

Keep these concepts separate:

- route duration
- traffic-aware duration where available
- arrival estimate
- driver arrival ETA

For the simulated driver:

use the real route geometry and the simulated vehicle's current position to derive progress.

---

# 10. AUTOCOMPLETE AUDIT

**Status: done (software)** — `PlacesSearchService` + `PlacesSearchController`.

Inspect the current destination search.

Google Places billing and performance guidance makes session handling important.

Autocomplete should use a proper session lifecycle rather than treating every keystroke as an isolated unrelated session.

Audit:

- [x] session token creation
- [x] session token reuse
- [x] session termination
- [x] selected place
- [x] place details fetch
- [x] cancellation
- [x] debouncing (~300 ms)
- [x] request cancellation
- [x] stale responses (generation + Task cancel)

Do not send:

`A`
`AB`
`ABC`
`ABCD`

as a giant uncontrolled stream of independent requests.

Implement appropriate debouncing/cancellation.

Google specifically recommends session tokens for Autocomplete and field selection for cost control.

---

# 11. PLACE DATA FIELD MASKING

**Status: done (software)** — Autocomplete + Details field masks in `PlacesSearchService`.

Audit every Places request.

Do NOT request:

`ALL`

unless there is a genuine reason.

Request only what VUUM needs.

For a destination suggestion we generally need things like:

- place ID / identifier
- display name
- formatted address
- coordinates

Do not retrieve:

- unnecessary photos
- reviews
- contact information
- atmosphere
- price information

unless the screen actually needs them.

Google's Places iOS documentation explicitly requires/selects fields and notes that requested fields affect billing.

This is both an engineering and cost audit.

---

# 12. PLACE TYPES

Determine whether search can intelligently differentiate:

- addresses
- businesses
- airports
- hotels
- restaurants
- landmarks
- offices
- hospitals
- universities
- mines / industrial areas
- transport hubs

Use Google Place Types appropriately where helpful.

Do not force all search results into a generic "address" model.

Google's current Places APIs support place-type filtering and classification.

---

# 13. SEARCH RESULT UX

When a user types a destination:

show intelligently:

- primary place name
- secondary address
- useful distance/context where applicable
- recognizable category/icon
- current/saved/recent distinction

Don't make every result look like:

`Some random text, Nairobi, Kenya`

The search experience must feel like a serious mobility application.

---

# 14. CURRENT LOCATION

Audit Core Location.

Verify:

- [x] correct authorization state handling — `RiderLocationManager` + `PermissionCenter`
- [x] denied permission — Home `PermissionDeniedBanner` → Settings
- [x] restricted permission — treated as denied; app remains bookable via Adjust / saved / catalog
- [x] approximate location — `accuracyAuthorization` + Home approximate banner → `requestPreciseLocationUpgrade`
- [x] precise location — Privacy toggle + temporary full-accuracy (`PickupAccuracy` Info.plist purpose)
- [x] location unavailable — finding-location banner + Try again
- [x] stale location — manager rejects age > 45s / bad accuracy; `TripSession.updatePickup` age ≤ 60s / ≤ 500 m
- [x] background/foreground behavior — when-in-use primary; foreground refresh in `VuumApp`
- [x] location updates — continuous when authorized; blue-dot via `showsUserLocation: isAuthorized`
- [x] battery considerations — distanceFilter 8 m (precise) / 50 m (approx); pauses updates automatically

The current GPS position must drive the pickup point.

- [x] GPS updates `TripSession` pickup when `id` is `current` or a market default center
- [x] Market catalog centers (`MockPlaces.lubumbashiCenter` / `nairobiCenter`) use real street names — **not** “Current location”
- [x] “Current location” is reserved for unresolved live GPS until reverse geocode returns a street/place label

Do not fall back to a static Nairobi/Lubumbashi coordinate unless explicitly operating in developer test mode (market default before first fix only).

---

# 15. REVERSE GEOCODING

The pickup address shown to the user must reflect the real location.

Audit:

GPS
→ reverse geocode
→ normalized address
→ pickup UI.

- [x] Path: Google Geocoding API (when `MapBootstrap` has a key) → `CLGeocoder` → coordinate fallback
- [x] Throttle: ~45 m / ~18 s in `TripSession.scheduleReverseGeocode`
- [x] Stale-result drop if GPS moved >120 m while geocoding
- [x] Do not regress a good street label to the unresolved “Current location” placeholder
- [x] Subtitle never duplicates “Current location”; uses locality or coordinate string instead
- [x] Naming tests: `ReverseGeocodingNamingTests`

Avoid continuously reverse-geocoding every location update.

Use sensible throttling and update only when the location has changed meaningfully.

---

# 16. CACHING

Introduce sensible caching where it provides value.

Potential cache targets:

- recent place searches
- place details
- reverse-geocoded pickup label
- route results for identical origin/destination combinations where safe
- static service configuration

Do NOT create unlimited caches.

Respect Google's data-storage/use requirements.

---

# 17. ERROR HANDLING

Every Google request must handle:

- no internet
- timeout
- invalid key
- restricted key
- billing disabled
- quota exceeded
- request denied
- zero results
- partial results
- malformed response
- service unavailable

The user should receive useful application-level states.

Not:

`Google API Error 403`

Instead:

"Unable to calculate the route right now."

with:

`Retry`

where appropriate.

Developer logs may contain diagnostic detail.

---

# 18. GOOGLE ERROR DIAGNOSTICS

Create centralized mapping such as:

Google error
→ VUUM service error
→ user-facing state

Do not expose raw Google error JSON to the user.

---

# 19. RETRY STRATEGY

Do not blindly retry every Google request three times.

Implement:

- request cancellation
- timeout
- bounded retry
- exponential backoff where appropriate
- no retry for invalid API key
- no retry for permission denied
- no retry for malformed requests
- controlled retry for transient network errors

Google's current web-service guidance also recommends exponential backoff and avoiding synchronized request bursts.

---

# 20. RATE / BILLING PROTECTION

Audit for accidental API abuse.

Look for:

- autocomplete per keystroke
- route requests on every map movement
- reverse geocoding every GPS update
- duplicate requests caused by SwiftUI view redraws
- repeated initialization
- multiple identical subscriptions
- retry storms
- API requests caused by scrolling
- route recalculation every animation frame

This is extremely important.

SwiftUI re-rendering must NEVER accidentally result in repeated Google network calls.

---

# 21. SWIFTUI LIFECYCLE AUDIT

Check for this class of bug:

View appears
→ creates Google service
→ view redraws
→ creates another service
→ request starts again
→ view redraws
→ another request

Ensure long-lived services are owned correctly.

Audit:

- `@State`
- `@StateObject`
- `@Environment`
- dependency injection
- actors/classes
- task cancellation
- `onAppear`
- `.task`
- `.onChange`

Make network calls idempotent where practical.

---

# 22. CONCURRENCY

Review Google-related async code.

Use modern Swift concurrency appropriately.

Do not create:

- race conditions
- duplicate route requests
- stale destination responses
- old autocomplete results overwriting newer results
- driver marker updates racing with route changes

For search:

If request A starts.

Then request B starts.

If B finishes first:

A MUST NOT overwrite B.

---

# 23. DRIVER MOVEMENT

This is a major realism checkpoint.

The driver marker should:

- follow the actual route
- move smoothly
- update at reasonable intervals
- rotate according to travel direction
- respect pickup/trip state
- pause at arrival
- continue after trip start
- stop at destination

Do not teleport the car.

Do not generate random movement unrelated to the route.

---

# 24. TRIP ROUTE REUSE

Avoid repeatedly calculating the entire route unnecessarily.

Model:

Pickup route

then:

Trip route

then:

Destination route

The driver approach route and active trip route may be different.

---

# 25. ROUTE DEVIATION

Add a route-deviation engine.

Compare:

actual/simulated driver position

against

expected route corridor.

If deviation exceeds a configurable threshold:

create a:

`RouteDeviationEvent`

This prepares VUUM for the RFQ's safety/fraud requirements.

### §25 Audit checklist (zones + live routes)

- [x] `RouteDeviationMonitor` corridor + persistence (`TripGeo.distanceToPolylineMeters`)
- [x] Rider notice + share on `ActiveTripFlowView` (no “demo” wording)
- [x] Expected corridor = `ActiveTrip.tripRoute` (live Routes/Directions when keyed, else synthetic)
- [x] In-trip motion legs sliced from that same polyline (`TripGeo.pathBetween`) so live roads do not false-trigger
- [x] Airport / downtown / high-demand zones in `ServiceZoneCatalog` (circle geofences; product gating + surcharge copy)
- [x] Zone feedback on Home / Services via `zoneContext.surchargeMessage` (not map polygon overlays)
- [x] XCTest: corridor + dense live-like polyline (`RouteDeviationTests`)

---

# 26. MULTI-STOP ROUTES

Audit the multiple-stop implementation.

The route request must correctly represent:

origin
→ stop 1
→ stop 2
→ destination

Do not just display additional addresses in the UI while continuing to calculate a route only between origin and final destination.

### Verified (code review 2026-08-23)

- [x] Booking stops are included in `TripSession.tripWaypoints` (pickup → stops → dropoff)
- [x] Choose-ride preview polyline uses `RouteEngine.route(through:)` (Routes `intermediates` → Directions `waypoints` → synthetic)
- [x] Driver assign builds full trip route via `RouteEngine.route(through:)` including stops
- [x] Mid-trip destination change keeps remaining stops in remaining/fare waypoint lists and re-routes through them
- [x] Map pins render intermediate stops (`MapPinKind.stop`) in destination / choose-ride / active-trip phases
- [x] Map fit bounds include stop coordinates on choose-ride and in-trip
- [x] In-trip leg motion reuses booked `tripRoute` via `TripGeo.subpath` (same corridor as deviation monitor)
- [x] When keyed, each in-trip leg can refine early progress with live `RouteEngine.route(from:to:)` road geometry + traffic ETA
- [x] Add / remove / reorder stop triggers `refreshPreviewRoute()` so the map polyline updates
- [x] UI add-stop path (`beginAddingStop` / Destination scaffold) wired; waiting charge modeled per stop

---

# 27. FARE ENGINE VS GOOGLE

IMPORTANT:

Google calculates geography/routing.

Google should NOT become the VUUM pricing engine.

Separate:

Google:

- distance
- duration
- route
- ETA

VUUM:

- base fare
- per km
- per minute
- minimum fare
- waiting
- surge
- airport pricing
- premium pricing
- corporate pricing
- promotions
- tax
- currency conversion

The fare engine consumes geographic data.

---

# 28. KENYA + DRC TEST

Now physically test the real device.

Because this application is being developed/presented in Kenya but operates as a DRC product:

TEST:

### Physical device in Kenya

Expected:

- real Kenyan GPS
- +254 available/default according to device context
- KES formatting
- Kenya addresses available
- real Google map
- real search

Then test a VUUM DRC operating-market selection:

- Lubumbashi
- Kolwezi
- CDF
- USD secondary
- DRC service categories
- DRC pricing configuration

Do not confuse:

DEVICE LOCATION

with:

VUUM OPERATING MARKET.

---

# 29. MAP CAMERA BEHAVIOR

Audit camera behavior.

The camera should:

- [x] initially center on current location *(Home `requestMapRecenter` + `cameraFocusNonce`)*
- [x] allow user interaction *(gesture pan/zoom)*
- [x] avoid fighting user gestures *(follow paused after rider pan until recenter)*
- [x] support recenter *(Home recenter → `mapCameraFocusNonce`; re-fits when waypoints exist)*
- [x] fit route when route is calculated *(`mapFitCoordinates` + edge-inset `GMSCameraUpdate.fit`)*
- [x] preserve sensible zoom *(follow uses `max(current, 14–15)`)*
- [x] transition smoothly *(`map.animate` / `animate(with:)`)*

Do not constantly snap the camera back to the GPS location while the user is manually exploring the map.

---

# 30. MAP MARKERS

Audit:

- [x] pickup marker *(green teardrop, tip-anchored)*
- [x] destination marker *(dark teardrop)*
- [x] stop markers *(amber teardrop; max 2 via TripSession)*
- [x] driver marker *(class glyph + heading)*
- [x] nearby drivers *(fleet glyphs, lower zIndex)*
- [x] premium indicators *(vehicleClass → large / bike / standard glyphs)*
- [x] user location marker *(Google blue-dot when `showsUserLocation` / Core Location authorized)*

Driver markers should not all overlap.

Nearby driver positions should be geographically plausible.

---

# 31. NEARBY DRIVER GENERATION

When using local/mock driver data:

generate nearby drivers relative to the user's actual coordinates.

Do NOT use a fixed fleet coordinate.

That means:

device is in Nairobi

→ nearby simulated vehicles appear around Nairobi.

device is in Lubumbashi

→ vehicles appear around Lubumbashi.

device is in Kolwezi

→ vehicles appear around Kolwezi.

The simulated fleet must be seeded relative to real geographic position or to the selected operating market.

---

# 32. MARKET-AWARE DRIVER CATALOG

Driver data should support:

- city
- coordinates
- name
- photo
- vehicle
- rating
- category
- availability
- ETA
- corporate eligibility
- premium eligibility

---

# 33. MAP STYLE

Audit map styling for VUUM.

Do not over-customize the map until it becomes illegible.

Priority:

- [x] roads readable *(optional `VuumMapStyle.json` / lite; default tiles until styled)*
- [x] pickup visible
- [x] route visible *(brand amber polyline)*
- [x] driver visible *(top zIndex)*
- [x] user location visible *(blue-dot when authorized + Maps key)*
- [x] destination visible

## Implementation status

- [x] Bundle day style `ios/Vuum/Maps/VuumMapStyle.json` (quiet POIs, desaturated roads)
- [x] Bundle low-data style `VuumMapStyleLite.json`
- [x] Bundle night style `VuumMapStyleNight.json` (SwiftUI `colorScheme == .dark`)
- [x] Apply via `GMSMapView.mapStyle` only when Maps key is present (`MapBootstrap.isConfigured` / `hasAPIKey`)
- [x] Wired in `VuumMapView` (make + update; switches with low-data / day-night)
- [x] JSON resources registered in `ios/Vuum.xcodeproj/project.pbxproj` (Resources build phase)
- [x] Style keeps road geometry and trip overlays readable (POI icons/labels quieted; highways remain distinct)

---

# 34. GOOGLE MAPS CREDENTIAL CHECK

Create a developer-facing configuration diagnostic screen that can be enabled only in development.

Display:

- Maps SDK initialized
- Places initialized
- route service configured
- API key configured
- current bundle ID
- current build configuration
- current Google SDK versions
- last successful request
- last error

Do NOT expose the actual API key.

---

# 35. GOOGLE API USAGE TELEMETRY

Add local developer diagnostics for:

- request type
- duration
- success/failure
- response status
- retry count

Do not log:

- full API key
- sensitive personal information
- unnecessary raw location data
- complete API responses in production

---

# 36. PACKAGE VERSION AUDIT

Inspect all Google packages.

Report:

- package
- current version
- latest appropriate version
- whether migration is necessary
- whether current version is deprecated
- whether the project is using legacy CocoaPods
- whether the project should move to current SPM implementation

Do not upgrade blindly.

Follow Google release notes.

Google recommends maintaining SDK versions and reviewing major-version migration requirements.

---

# 37. PLACES SWIFT SDK DECISION

Explicitly evaluate whether VUUM should use:

- existing `GooglePlaces`
- `GooglePlacesSwift`
- both where needed

The current Places Swift SDK is available for the newer Places APIs and supports Swift concurrency/value types/type safety.

Do not migrate merely for fashion.

Make the decision based on:

- existing implementation
- stability
- API coverage
- project target
- migration cost
- current SDK support
- maintainability

Document the decision.

---

# 38. PLACES UI KIT

We have Places UI Kit enabled.

Determine whether VUUM actually needs it.

Do NOT integrate Places UI Kit just because it is enabled.

The VUUM search experience is already custom-designed.

Use Places UI Kit only where it genuinely improves the product.

Do not replace the carefully designed VUUM booking UI with an out-of-brand generic Google UI.

---

# 39. UNUSED GOOGLE APIS

After auditing actual usage, tell me whether these should remain enabled:

- Directions API
- Distance Matrix API
- Geocoding API
- Places Aggregate API
- Places API
- Places API (New)
- Places UI Kit
- Route Optimization API

Possible outcomes:

KEEP
REMOVE
FUTURE BACKEND ONLY
NOT REQUIRED BY CURRENT RIDER APP

Do not make assumptions.

Verify against actual source code.

---

# 40. DIRECTIONS API VS ROUTES API

If both are present in the application:

determine why.

Do not maintain a legacy Directions implementation if Routes API already provides the required functionality.

Do not migrate blindly if a legitimate requirement still depends on Directions API.

The final report must state exactly which routing service VUUM uses and why.

---

# 41. DISTANCE MATRIX

Determine whether VUUM actually needs Distance Matrix.

For a rider-side application:

we may not need it if route/ETA requirements are already fulfilled through the current Routes implementation.

If it is not actually used:

do not make requests to it.

Do not keep it in the API key restrictions merely out of fear.

---

# 42. ROUTE OPTIMIZATION API

Do NOT use Route Optimization API merely because this is a ride-hailing product.

It is primarily a fleet/optimization capability.

Determine whether it belongs to:

- future dispatcher
- driver allocation
- fleet planning
- corporate logistics
- backend optimization

It likely does NOT belong directly in the current rider application.

If not used:

remove it from the current iOS key restriction.

Leave it enabled at project level only if there is a documented future use.

---

# 43. PLACES AGGREGATE API

Determine whether the rider application actually uses Places Aggregate.

If not:

remove it from the client API restriction.

---

# 44. GEOCODING

If direct Geocoding API REST requests are being made from the iOS client:

stop and audit the architecture.

Ask:

Why are we not using the native iOS facilities where appropriate?

If a web service is genuinely required:

document why and secure it according to Google's current recommendations.

Do not casually expose a broad web-service credential from an iOS app.

**Audit finding (2026-08-23):**

- [x] Reverse only via `ReverseGeocodingService` → `maps.googleapis.com/maps/api/geocode/json` when keyed
- [x] Native fallback: `CLGeocoder.reverseGeocodeLocation` when Google fails / no key
- [x] Rationale: better street labels in DRC/Kenya when Geocoding API is enabled; Apple path always available
- [x] Same Maps key + iOS bundle header when REST is used; no separate unrestricted web key in repo
- [x] Forward geocoding not used from the rider client

---

# 45. API KEY SPLITTING

Determine whether we should have:

### Key A

Native iOS Maps/Places SDK usage.

### Key B

Any unavoidable client-side web-service usage.

### Backend keys

Server-side APIs when the backend exists.

Do not put every Google service behind one giant universal credential.

Google explicitly recommends separate keys where platform usage differs.

---

# 46. BACKEND-READY ARCHITECTURE

The current presentation build may use local data.

However, Google-related code must be replaceable.

For example:

`GoogleRouteProvider`

should satisfy:

`RouteProvider`

so later:

`RemoteVuumRouteProvider`

or server-side routing can be inserted without rewriting the booking UI.

Same principle for:

- Places
- geocoding
- ETA
- driver location
- payment
- authentication

---

# 47. NO DIRECT GOOGLE LOGIC INSIDE VIEWS

A SwiftUI screen should NOT contain:

- API keys
- raw Google HTTP requests
- JSON decoding
- Google-specific billing logic
- retry loops

Views call application/domain services.

---

# 48. GOOGLE DATA → VUUM DATA

Do not let Google types leak throughout the entire application.

For example:

Google place object
→ VUUM `Place`

Google route
→ VUUM `Route`

Google coordinate
→ VUUM `GeoPoint`

Google distance
→ VUUM `Distance`

Google duration
→ VUUM `ETA`

This keeps the architecture portable.

---

# 49. NETWORK OBSERVABILITY

Build a proper network diagnostic layer.

For development:

- request count
- request duration
- failures
- retries
- cache hit
- cache miss

This will help identify unexpected billing/network behavior.

---

# 50. PERFORMANCE

Audit:

- map rendering
- driver markers
- route drawing
- autocomplete
- image loading
- profile photos
- memory
- battery
- CPU

Ensure driver-marker animation does not run unnecessarily at 60 FPS for dozens of vehicles.

Use an appropriate update strategy.

---

# 51. IMAGE / DRIVER DATA

Audit driver image loading.

Use:

- caching
- placeholders
- graceful failure
- low-resolution thumbnails where appropriate

Do not download huge images on every screen transition.

---

# 52. BACKGROUND/FOREGROUND

Test:

app active
→ background
→ return

during:

- matching
- driver approach
- active trip
- safety workflow
- recording

The application must restore authoritative trip state.

---

# 53. ACTIVE TRIP RESILIENCE

The user must not lose their trip if:

- notification arrives
- phone locks
- application temporarily backgrounds
- network disappears
- application resumes

Persist the authoritative trip state.

---

# 54. NO DUPLICATE REQUESTS AFTER RESUME

A particularly important test:

Start trip.

Background app.

Return.

Ensure we do NOT:

- request the same route repeatedly
- duplicate driver-location subscriptions
- duplicate notifications
- start another location manager
- create multiple timers

---

# 55. GOOGLE MAPS + SENTRY/SNYK/SYNC CLEANUP

Revisit the previous unwanted "Synk/Snyk/Sync" issue.

Make sure Google integration has NOT accidentally introduced:

- a sync process
- package manager loops
- post-build sync
- dependency synchronization tooling
- unwanted Git hooks

The development workflow must remain:

OPEN
→ BUILD
→ RUN

without unrelated tools starting in the background.

---

# 56. XCODE BUILD AUDIT

Verify:

- Swift compiler warnings
- concurrency warnings
- deprecated API warnings
- package warnings
- linker warnings
- Info.plist warnings
- build scripts
- duplicate resource warnings
- duplicate package dependencies

Resolve legitimate warnings rather than hiding them.

---

# 57. RELEASE CONFIGURATION

Test both:

### Debug

and

### Release

The Google configuration must work correctly in both environments.

Codemagic must also receive the correct configuration.

Do not build something that works only when a developer's local `.env` happens to exist.

---

# 58. SIDELOAD TEST

Build a real IPA.

Install to physical iPhone.

Verify:

- map
- Places
- route
- GPS
- search
- destination
- driver simulation
- trip
- account

Do NOT treat successful compilation as successful integration.

---

# 59. FULL END-TO-END TEST

Perform this exact sequence on the real device:

1. launch
2. grant location
3. current location appears
4. map loads
5. tap destination search
6. type a real location
7. autocomplete appears
8. select location
9. place details resolve
10. route calculated
11. route drawn
12. distance shown
13. ETA shown
14. fare calculated from VUUM pricing
15. choose category
16. request ride
17. nearby driver appears
18. driver approaches
19. driver arrives
20. PIN verification
21. trip begins
22. driver route progresses
23. ETA updates
24. active trip controls work
25. safety controls work
26. trip completes
27. receipt generated
28. rating appears
29. history contains trip

If any of these fail:

FIX THEM.

---

# 60. REAL LOCATION TEST

Because we are in Kenya while developing a DRC application:

test the app physically from Kenya.

Do NOT mask this.

Expected:

The map reflects Kenya.

Then test VUUM's DRC market configuration independently.

The architecture must clearly separate:

`DeviceLocation`

from:

`OperatingMarket`.

---

# 61. UX AUDIT AFTER GOOGLE INTEGRATION

Now that Google Maps is real, inspect whether the rest of the UI actually benefits from it.

Examples:

The current location should actually appear in:

- pickup field
- map
- route
- fare
- nearby drivers
- ETA

Destination should propagate through:

- Places
- route
- pricing
- trip
- history
- receipt

No isolated feature should exist.

---

# 62. REALISM AUDIT

Look for anything that still feels fake.

Examples:

- fake map movement
- fake ETA
- impossible driver distance
- route that doesn't match shown destination
- fare not matching distance
- destination displayed differently across screens
- inconsistent address names
- fixed driver locations
- driver arriving too quickly
- route ending somewhere else
- stale UI after destination change

Fix all of them.

---

# 63. ACCOUNT / SETTINGS SECOND AUDIT

Now revisit Account/Settings after the core functionality is stable.

Ask:

"What would a real Uber/Bolt-level rider expect here that we still haven't implemented?"

Audit:

- profile
- payments
- trip history
- receipts
- scheduled rides
- saved places
- promotions
- referrals
- safety
- trusted contacts
- notifications
- language
- currency
- privacy
- security
- support
- lost item
- fare dispute
- account deletion
- corporate account
- about/legal

Add anything legitimately missing.

---

# 64. RFQ CROSS-REFERENCE

Re-open the VUUM RFQ and audit all 204 references.

Separate into:

### Implemented in current iOS rider application

### Architecturally prepared

### Backend required

### Driver application required

### Admin/dispatcher required

### Corporate portal required

### Field-sales application required

### Future phase

Do NOT falsely mark backend/admin requirements as implemented simply because the rider app has a placeholder.

---

# 65. TRUST & SAFETY CROSS-REFERENCE

Pay special attention to the RFQ's Trust & Safety requirements.

Verify:

- [x] active-trip recording only
- [x] visible recording state
- [x] permission
- [x] notification
- [x] automatic stop
- [x] incident linking
- [x] SOS — confirmation sheet + `requestSOS(coordinate:)` includes live lat/lng in safety notification when Core Location has a fix
- [x] trip sharing — `TripShare.message` appends live location + Maps link when available (Safety toolkit / settings / active trip / driver card)
- [x] route deviation
- [x] poor connectivity
- [ ] retention architecture — on-device audio retention only; no cloud safety console in this build

The RFQ explicitly prohibits covert/general-purpose recording and requires jurisdiction-specific consent and retention handling.

Do not turn audio safety into an always-on microphone.

---

# 66. CORPORATE CROSS-REFERENCE

Verify rider-side support for:

- company identity
- corporate booking
- spending limits
- cost centre
- corporate payment
- executive ride
- premium drivers
- corporate safety
- scheduled executive booking

Do not build a fake corporate "dashboard" inside the rider app merely for screenshots.

Build the rider-facing functionality correctly.

---

# 67. FIELD SALES CROSS-REFERENCE

Ensure the rider application can eventually support:

- referral code
- recruiting executive attribution
- recruit ID
- first ride completion
- commission eligibility

Do not create fake money.

---

# 68. ADDITIONAL FEATURES DISCOVERY

After completing the technical audit, search current Uber/Bolt/rider-product patterns and identify HIGH-VALUE features still missing from VUUM.

Potential examples to investigate:

- ride PIN
- trusted contacts
- favorite drivers where applicable
- scheduled rides
- destination changes
- multiple stops
- reserve
- ride-for-others
- pickup notes
- accessibility preferences
- quiet-ride preference
- child/seat requirements where appropriate
- cash handling
- receipt sharing
- fare review
- lost item
- support ticket history
- driver reporting
- safety toolkit
- nearby pickup guidance
- pickup landmarks
- airport pickup instructions
- rider verification
- suspicious trip alerts

Do not add random features simply to make the application larger.

Add features that materially improve realism or commercial credibility.

---

# 69. UBER / BOLT COMPARISON

Perform an evidence-based product comparison.

Create an internal checklist:

| Capability | Uber | Bolt | VUUM | Missing? | Priority |
|---|---|---|---|---|---|

Do not copy branding.

Use them as product benchmarks.

---

# 70. FINAL GOOGLE CLOUD RECOMMENDATION

After auditing real code usage, produce:

## CURRENT API RESTRICTION SET

Exactly which APIs the current iOS key needs.

**Documented recommendation** (operator applies in Cloud Console; see `docs/GOOGLE_MAPS_SETUP.md` §1 + §7):

| Restriction | Value |
|-------------|--------|
| Application | **iOS apps** → **`com.vuum.app`** |
| APIs on key | **Maps SDK for iOS**, **Places API (New)**, **Routes API**, **Directions API** |

- [x] Recommendation written to `docs/GOOGLE_MAPS_SETUP.md`
- [ ] Operator confirmed on live Google Cloud key

## OPTIONAL/FUTURE APIs

Which services can remain project-enabled but should NOT be exposed to the current iOS key.

Examples from the current Cloud project inventory: Distance Matrix, Places Aggregate, Route Optimization, Places UI Kit, legacy Places extras — keep project-enabled only if needed later; **omit from the iOS key**.

## REMOVE FROM KEY

Anything currently allowed but unused.

## BACKEND-ONLY

Services that should eventually move to backend infrastructure.

---

# 71. IMPORTANT GOOGLE SECURITY PRINCIPLE

Do not solve every Google problem by allowing everything.

A working map is not the goal.

A secure working map is the goal.

Google recommends restricting keys by application and API, using native iOS SDKs where possible, separating keys by platform/use when appropriate, and keeping web-service credentials protected.

### §71 Credential-doc checklist

- [x] Security principle reflected in `docs/GOOGLE_MAPS_SETUP.md` (restrict by app + API; no “allow all Maps APIs”; rotate if leaked)
- [x] Companion gates: `docs/PRE_BUILD_MAPS_GATE.md`, `docs/CODEMAGIC_SETUP.md` (`vuum_secrets`)
- [ ] Operator: apply restrictions + rebuild before treating live Maps as presentation-ready

---

# 72. GOOGLE COST DISCIPLINE

Audit every Google request for unnecessary billing.

Especially:

- Autocomplete
- Place Details
- route calculations
- repeated geocoding
- repeated reverse geocoding
- retries
- map initialization
- driver refresh

Use:

- session tokens
- field masks
- caching
- debouncing
- request cancellation
- bounded retries

where appropriate.

Google's current Places documentation specifically notes that Autocomplete session handling and requested Place fields affect billing.

---

# 73. DOCUMENT THE GOOGLE INTEGRATION

Create:

`docs/GOOGLE_MAPS_ARCHITECTURE.md`

It should describe:

- Maps SDK
- Places SDK
- Routes
- geocoding
- API keys
- restrictions
- billing
- packages
- versions
- request flow
- error handling
- caching
- security
- testing
- environment configuration
- Codemagic setup

### §73 Credential-doc progress (architecture pack complete)

- [x] API keys / restrictions / Codemagic `vuum_secrets` / rotate-if-leaked → `docs/GOOGLE_MAPS_SETUP.md`
- [x] Environment / CI inject → `docs/CODEMAGIC_SETUP.md` + `docs/PRE_BUILD_MAPS_GATE.md`
- [x] Post-key device smoke → `docs/MAPS_POST_KEY_QA.md`
- [x] Full `docs/GOOGLE_MAPS_ARCHITECTURE.md` (MapBootstrap → MapView → RouteEngine → Places → TripSession)
- [x] `docs/GOOGLE_API_MATRIX.md`
- [x] `docs/GOOGLE_INTEGRATION_TEST_PLAN.md` (keyed / unkeyed simulator + device; complements `MAPS_POST_KEY_QA.md`)

Also create:

`docs/GOOGLE_API_MATRIX.md`

containing:

| Service | Used By | Client/Server | Key | Purpose | Status |

---

# 74. CREATE A GOOGLE INTEGRATION TEST PLAN

Create:

`docs/GOOGLE_INTEGRATION_TEST_PLAN.md`

Include:

- map test
- current-location test
- autocomplete test
- Place Details test
- route test
- ETA test
- API restrictions test
- missing-key test
- invalid-key test
- offline test
- quota/error test
- release-build test
- physical-device test

### §74 Progress

- [x] `docs/GOOGLE_INTEGRATION_TEST_PLAN.md` authored (S0–R1 envs; map/Places/route/key/offline/device cases)
- [ ] Device evidence filled (`MAPS_POST_KEY_QA.md` / `DEVICE_QA_EVIDENCE.md`) — operator

---

# 75. DO NOT STOP AFTER THE GOOGLE AUDIT

After the Google integration is verified:

run a second application-wide audit.

Look for:

- incomplete screens
- dead buttons
- broken navigation
- duplicate UI
- fake data
- inconsistent currency
- inconsistent language
- unrealistic trip states
- poor account experience
- weak support
- missing safety
- missing error states
- accessibility defects
- performance defects
- build problems

Fix those too.

---

# 76. FINAL PRODUCT STANDARD

At the end of this phase, I should NOT have to tell you:

"Now wire Google Maps."

That work should already be complete.

I should NOT have to tell you:

"Add autocomplete."

That should already work.

I should NOT have to tell you:

"The driver is moving unrealistically."

You should identify and fix it.

I should NOT have to tell you:

"This API is enabled but unused."

You should identify it.

I should NOT have to tell you:

"Why are we calling Google 30 times while typing?"

You should identify it.

I should NOT have to tell you:

"The API key is too broadly restricted."

You should identify and report it.

---

# 77. FINAL ACCEPTANCE TEST

The application passes only when:

### Google

- Maps works
- Places works
- search works
- Place selection works
- route works
- route polyline works
- ETA works
- real GPS works
- errors are handled
- credentials are secured
- API restrictions are appropriate

### Product

- booking works
- service selection works
- fare works
- driver matching works
- driver movement works
- PIN works
- active trip works
- completion works
- receipt works
- history works
- payments work
- account works
- support works
- safety works

### Environment

- Kenya device location works
- +254 works
- KES works
- DRC market works
- +243 works
- CDF/USD work
- Lubumbashi works
- Kolwezi works

### Architecture

- Google code is isolated
- raw Google models don't leak everywhere
- views don't make raw API calls
- services are testable
- mocks can be replaced with backend repositories
- state transitions are authoritative

### Quality

- no obvious dead buttons
- no placeholder UX
- no accidental fixed location
- no duplicate requests
- no obvious API abuse
- no unnecessary package dependency
- no unwanted Sync/Snyk/Synk process
- release build works
- IPA sideload works

---

# 78. FINAL REPORT

When finished, report:

## A. Google APIs actually used

## B. Google APIs enabled but not used

## C. APIs removed from the iOS API key restriction

## D. APIs that should eventually be backend-only

## E. Google SDK versions

## F. Maps implementation

## G. Places implementation

**Done (software):** Places API (New) HTTPS via `PlacesSearchService` when `VUUM_GOOGLE_MAPS_API_KEY` is present; local `MockPlaces` catalog on missing key or API failure. Session tokens, field masks, `PlacesSearchController` debounce/cancel/error UX. No Places SDK SPM. Live arbitrary-address results remain credential-gated.

## H. Routes implementation

## I. Geocoding implementation

## J. API-key/security findings

## K. Billing/cost-control findings

## L. Google documentation deviations discovered

## M. Changes made

## N. New features discovered and added

## O. RFQ coverage improvements

## P. Bugs discovered and fixed

## Q. Tests performed on physical iPhone

## R. Release build result

## S. Remaining limitations

## T. Exact remaining work required before client presentation

---

# FINAL INSTRUCTION

Do not treat the presence of a Google API key as proof of successful integration.

Inspect the source.

Inspect the package versions.

Inspect every API call.

Inspect every Google request.

Inspect the actual runtime behavior.

Compare it against Google's current official documentation.

Correct any architectural mistakes.

Remove unnecessary Google services from the key restriction.

Use the current native iOS SDKs where appropriate.

Avoid unnecessary REST calls from the client.

Implement proper autocomplete sessions, field masks, caching, cancellation, retries and error handling.

Then perform a complete VUUM product audit again.

Do not stop after fixing one issue.

Continue until there are no obvious gaps remaining between:

**"a nice-looking ride-hailing presentation app"**

and

**"a highly convincing, technically credible VUUM rider product prototype."**"**

and

**"a highly convincing, technically credible VUUM rider product prototype."**