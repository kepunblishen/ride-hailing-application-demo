# Google Maps / Places / Routes — Vuum iOS

**GOOGLE MAPS / PLACES / ROUTES CREDENTIAL CHECKPOINT**

Software wiring is in place. The **only remaining step** is a Google Cloud API key (plus enabling the three APIs below). Do not commit real keys.

| Layer | Implementation | SPM? |
|-------|----------------|------|
| **Maps SDK for iOS** | `MapBootstrap` + `VuumMapView` (`GMSServices.provideAPIKey`) | Yes — `https://github.com/googlemaps/ios-maps-sdk` product `GoogleMaps` |
| **Places API (New)** | `PlacesSearchService` (Autocomplete + Details, session tokens) | No — HTTPS |
| **Routes API** | `RoutesAPIService` (`computeRoutes`, traffic-aware, polyline decode) | No — HTTPS |
| **Directions API** | `DirectionsRouteService` (legacy JSON fallback when Routes fails) | No — HTTPS |
| **Reverse geocode** | `ReverseGeocodingService` — **Apple `CLGeocoder` first**; Google Geocoding REST only if Apple fails | No — Apple / optional HTTPS |

Shared key name: **`VUUM_GOOGLE_MAPS_API_KEY`**  
Bundle ID (restrict the key to this): **`com.vuum.app`**

Without a usable key the app still launches: map placeholder, **local catalog autocomplete** (Lubumbashi / Nairobi), `TripGeo` local polylines, Core Location GPS + `CLGeocoder` reverse-geocode, synthetic routes/ETAs, and full trip UI (matching → PIN → SOS → rate).

**Still requires a live key for presenter-visible map realism:** map tiles, blue-dot, Google Places for arbitrary addresses, live Directions polylines on the map, on-map driver/vehicle motion.

---

## 1. Google Cloud Console (exact steps)

1. Open [Google Cloud Console](https://console.cloud.google.com/) → create or select a project.
2. **Billing** — link a billing account (Maps Platform requires billing; free monthly credit applies to many SKUs).
3. **APIs & Services → Library** — enable all of:
   - **Maps SDK for iOS**
   - **Routes API** (preferred road polylines)
   - **Directions API** (fallback used by `DirectionsRouteService`)
   - **Places API (New)** (autocomplete + details)
   - **Geocoding API** — **optional**; only if you want Google as a secondary reverse-geocode after Apple fails (not required for pickup labels)
4. **APIs & Services → Credentials → Create credentials → API key**.
5. Restrict the key (audit §5 / §71 — secure working map, not an open key):
   - **Application restrictions:** **iOS apps** → bundle ID **`com.vuum.app`** (exact match)
   - **API restrictions:** only what the rider app calls — **Maps SDK for iOS**, **Places API (New)**, **Routes API**, **Directions API** (fallback). Add **Geocoding API** only if enabling the optional Google reverse-geocode fallback.
   - Project may have extra APIs enabled (Distance Matrix, Places Aggregate, Route Optimization, etc.) — **do not** add those to this iOS key
6. Copy the key. Paste only into Codemagic group **`vuum_secrets`**, Xcode scheme env, or local `Secrets.xcconfig` — **never into git**.

Official docs:

- [Maps SDK setup](https://developers.google.com/maps/documentation/ios-sdk/config)
- [Get an API key](https://developers.google.com/maps/documentation/ios-sdk/get-api-key)
- [Places API (New)](https://developers.google.com/maps/documentation/places/web-service/op-overview)
- [Routes API](https://developers.google.com/maps/documentation/routes)

---

## 2. How Vuum loads the key

`MapBootstrap` resolves the first **usable** (non-empty, non-placeholder) value from:

| Order | Source | Typical use |
|------|--------|-------------|
| 1 | Process env `VUUM_GOOGLE_MAPS_API_KEY` | Xcode scheme Run → Environment Variables (**disabled by default** in the shared scheme; enable only with a real key) |
| 2 | Info.plist `VUUM_GOOGLE_MAPS_API_KEY` | `ios/Secrets.xcconfig` via `Vuum.xcconfig` `#include?`, or Codemagic `xcodebuild` |
| 3 | Info.plist `GMSApiKey` | Same build setting (legacy / Maps alias) |

Placeholders and unsubstituted macros are **skipped** so a scheme stub cannot block Secrets / Info.plist:

- `YOUR_GOOGLE_MAPS_API_KEY`
- empty / whitespace
- any value containing `$(` (e.g. `$(VUUM_GOOGLE_MAPS_API_KEY)`)
- `REPLACE_ME`, `CHANGEME`, etc.

The same resolved key is used for:

1. `GMSServices.provideAPIKey` (map tiles / markers / polylines)
2. Places HTTPS (`X-Goog-Api-Key` + `X-Ios-Bundle-Identifier`)
3. Routes HTTPS (`X-Goog-Api-Key` + `X-Ios-Bundle-Identifier`)
4. Directions HTTPS (query `key` + `X-Ios-Bundle-Identifier`)
5. Optional Geocoding HTTPS fallback (query `key` + `X-Ios-Bundle-Identifier`)

### SDK vs REST — one key for now (audit §45)

| Path | Credential | Notes |
|------|------------|--------|
| **Maps SDK for iOS** | Same `VUUM_GOOGLE_MAPS_API_KEY` via `GMSServices.provideAPIKey` | Native; iOS bundle restriction applies |
| **Client REST** (Places New, Routes, Directions, optional Geocoding) | Same key | Every REST call sends **`X-Ios-Bundle-Identifier: com.vuum.app`** (`MapBootstrap.applyIOSBundleIdentifierHeader` / `GoogleMapsREST`) so an iOS-restricted key works from `URLSession` |

**Same key is OK for the presentation / Sideload build.** Google prefers separate credentials when platform usage differs (native SDK vs web services vs backend). Defer a split until you introduce a backend proxy or dedicated REST key:

- **Key A** — Maps SDK only (iOS restriction)
- **Key B** — unavoidable client REST (still iOS-restricted + bundle header), or move REST behind a Vuum server
- **Backend keys** — server-side only when a backend exists

Do not put Distance Matrix / Route Optimization / Places Aggregate on the rider iOS key either way.

### Reverse geocode — Apple-first (audit §44)

`ReverseGeocodingService` order:

1. **`CLGeocoder`** (preferred — no Google Geocoding bill for the common path)
2. **Google Geocoding API** only if Apple returns nothing and a usable key is present
3. Coordinate subtitle fallback (`Current location` + lat/lon)

Pickup labeling works without enabling Geocoding API on the key. "Current location" is only the unresolved GPS placeholder — market centers use real street names.


**App Transport Security:** default ATS (no `NSAppTransportSecurity` override / no `NSAllowsArbitraryLoads`). HTTPS-only Maps / Places / Routes calls are fine.

### Info.plist software audit (repo — no secrets)

| Item | Status |
|------|--------|
| Bundle ID via `$(PRODUCT_BUNDLE_IDENTIFIER)` → **`com.vuum.app`** | [x] |
| `NSLocationWhenInUseUsageDescription` | [x] |
| `NSLocationAlwaysAndWhenInUseUsageDescription` | [x] |
| `LSApplicationQueriesSchemes` → `comgooglemaps`, `googlechromes` | [x] |
| `VUUM_GOOGLE_MAPS_API_KEY` = `$(VUUM_GOOGLE_MAPS_API_KEY)` | [x] |
| `GMSApiKey` = `$(VUUM_GOOGLE_MAPS_API_KEY)` (legacy alias slot) | [x] |
| ATS default (no arbitrary loads) | [x] |
| No real API key in git-tracked plist / xcconfig / scheme | [x] |
| Placeholder detection + fallthrough in `MapBootstrap` | [x] |
| Shared scheme env disabled by default | [x] |
| REST `X-Ios-Bundle-Identifier: com.vuum.app` | [x] |
| Reverse geocode Google when keyed -> CLGeocoder | [x] |

`ios/Vuum/Config/Vuum.xcconfig` defaults `VUUM_GOOGLE_MAPS_API_KEY` to the non-functional placeholder `YOUR_GOOGLE_MAPS_API_KEY` (ignored by `MapBootstrap`) and optionally `#include?`s gitignored `ios/Secrets.xcconfig` (`../../Secrets.xcconfig` from Config/).

---

## 3. Local Mac / Xcode

**Option A — Scheme env (simulator / Run from Xcode)**

1. Scheme **Vuum** → Run → Arguments → Environment Variables  
2. **Enable** `VUUM_GOOGLE_MAPS_API_KEY` and set it to your real key (shared scheme ships disabled with a placeholder so it cannot shadow Secrets/Info.plist)

**Option B — Secrets.xcconfig (device / IPA-like builds)**

```bash
cp ios/Secrets.example.xcconfig ios/Secrets.xcconfig
# Edit ios/Secrets.xcconfig — set VUUM_GOOGLE_MAPS_API_KEY to the real key
# File is gitignored — do not commit it
```

---

## 4. Codemagic (Windows → Sideloadly path)

Exact pre-build checklist: [CODEMAGIC_SETUP.md](CODEMAGIC_SETUP.md#exact-codemagic-checklist-before-you-start-a-build).

1. Codemagic → Application → **Environment variables** → group named exactly **`vuum_secrets`** (must match `codemagic.yaml` `environment.groups`). Create the empty group before the first build if the key is not ready; a missing **group** fails CI, a missing **key** does not.
2. Inside that group, add:

   | Group | Name | Value | Secure |
   |-------|------|--------|--------|
   | `vuum_secrets` | `VUUM_GOOGLE_MAPS_API_KEY` | your key | Yes |

3. Workflow `ios-release` then:
   - Writes gitignored `ios/Secrets.xcconfig` when the secure env is set (consumed by `Vuum.xcconfig` `#include?`)
   - Passes `VUUM_GOOGLE_MAPS_API_KEY=…` to `xcodebuild` **only when set** (empty CLI override would wipe xcconfig)

4. Rebuild → download `build/Vuum.ipa` → Sideloadly.

Without the env **value** the IPA still builds; map uses placeholders, Places falls back to the local catalog, Routes stay offline-safe. Without group `vuum_secrets`, Codemagic fails before scripts run.

---

## 5. Places session architecture

Implemented in `PlacesSearchService` + `PlacesSearchController`:

- [x] One UUID **session token** per typing session (`beginSession` / auto-create on first request)
- [x] Autocomplete requests reuse that token
- [x] Place Details sends the same token, then clears the session (`endSession` / after successful `resolve`)
- [x] Abandoned searches / dismiss call `abandonSession` / `tearDown`
- [x] UI debounce ~300 ms + generation / query-string stale-response ignore
- [x] Field mask on Autocomplete + Details (`types` / `primaryType` for icons; no photos/reviews)
- [x] Bounded place-details cache via `MapsRequestCache`
- [x] Rider-facing error / searching states (no “demo” / catalog / credential wording)
- [x] **Fallback:** if the key is missing or the Places request fails, fuzzy-match the local market catalog (`MockPlaces`) so booking always has results

Native Places SPM is **not** used — see [`PLACES_SDK_DECISION.md`](PLACES_SDK_DECISION.md). HTTPS Places (New) is sufficient for credential activation.

---

## 6. Routes architecture

Implemented in `RoutesAPIService`:

- `POST https://routes.googleapis.com/directions/v2:computeRoutes`
- Traffic-aware (`TRAFFIC_AWARE`), optional intermediates + alternatives
- Decodes `encodedPolyline` → `[GeoPoint]`
- Returns `nil` without a key so `TripSession` / `TripGeo` keep working

---

## 7. Post-key checklist (operator — after you have a key)

Software is ready. Complete these **outside the repo** before expecting live tiles / Places / Routes. Aligns with audit §4–§5 / §71 and [`PRE_BUILD_MAPS_GATE.md`](PRE_BUILD_MAPS_GATE.md).

### A. APIs enabled (Google Cloud → Library)

- [ ] Billing linked on the Maps project
- [ ] **Maps SDK for iOS** enabled
- [ ] **Places API (New)** enabled
- [ ] **Routes API** enabled
- [ ] **Directions API** enabled (fallback used by `DirectionsRouteService`)

### B. iOS application restriction

- [ ] Application restriction: **iOS apps**
- [ ] Bundle ID exactly **`com.vuum.app`** (wrong ID → tiles fail on device even with a baked key)

### C. API restrictions on the key

- [ ] Key allows only: **Maps SDK for iOS**, **Places API (New)**, **Routes API**, **Directions API**
- [ ] **Geocoding API** on the key only if you want the optional Google reverse-geocode fallback (Apple `CLGeocoder` is primary)
- [ ] Unused project APIs (Distance Matrix, Places Aggregate, Route Optimization, Places UI Kit, etc.) are **not** on this iOS key

### D. Codemagic `vuum_secrets`

- [ ] Group **`vuum_secrets`** exists and matches `codemagic.yaml` `environment.groups`
- [ ] Secure env **`VUUM_GOOGLE_MAPS_API_KEY`** is in that group (real key, not `YOUR_GOOGLE_MAPS_API_KEY` / empty)
- [ ] **Or** local Mac: scheme env / gitignored `ios/Secrets.xcconfig` — still **never commit** the key

### E. Rotate if the key leaked

- [ ] If the key was pasted into chat, a ticket, a committed file, a screenshot, or a public CI log: **regenerate** in Google Cloud → Credentials → rotate / create a new key
- [ ] Apply the same iOS + API restrictions to the new key
- [ ] Update Codemagic `vuum_secrets` (or local Secrets) with the new value; delete/disable the old key
- [ ] Rebuild IPA so Info.plist does not keep the leaked value

### F. Verify on device

- [ ] Fresh `ios-release` build after the key is set; Sideload `build/Vuum.ipa`
- [ ] Live map tiles (not map-unavailable)
- [ ] Places autocomplete beyond the local catalog (optional smoke)
- [ ] Road polyline / ETA when Routes is used (optional smoke)
- [ ] Location permission accepted when testing blue-dot / my-location

Presenter device QA after a keyed Sideload: [`MAPS_POST_KEY_QA.md`](MAPS_POST_KEY_QA.md).

---

## 8. Blank / white map triage

| What you see | Likely cause | Fix |
|--------------|--------------|-----|
| Light/dark **grid** + map icon + “unavailable” copy | **No usable API key** in the build (`MapBootstrap` rejected placeholder / missing Secrets) | Inject a real `VUUM_GOOGLE_MAPS_API_KEY` (§3 or §4) and rebuild |
| **Empty white/gray plane** + Google logo (no roads) | Key present but **tiles denied** — billing off, Maps SDK for iOS not enabled, or bundle ID ≠ `com.vuum.app` | Complete §7 A–B; watch Xcode console for “API key may be invalid for your bundle ID” |
| White/blank plane **above** the destination / choose-ride sheet (no Google logo, no grid) | **Layout / wrong host** — destination phase was a list-only screen (`DestinationSearchView`) or map `UIViewRepresentable` collapsed under a tall sheet / NavigationStack | Fixed: `DestinationScaffoldView` → `PlanYourRideView` (full-bleed `TripMapLayer` + capped sheet); choose/confirm use `GeometryReader` + sheet max height; `VuumMapView` uses `GMSMapViewOptions` + `sizeThatFits` |
| Dark UI + washed **light** basemap | Was a code issue (lite style forced in dark); night style should apply now | Rebuild with current `VuumMapView` styles |
| Idle Home tab has **no map** | **By design** — content-first `HomeHubView`; map appears after **Where to?** | Opens `PlanYourRideView` via `DestinationScaffoldView` (`TripMapLayer` full-bleed behind sheet) |

**If still blank after a build that includes the layout fix:** this is almost certainly credentials, not embedding. Set Codemagic secure group **`vuum_secrets`** → env **`VUUM_GOOGLE_MAPS_API_KEY`** (or local gitignored `ios/Secrets.xcconfig` / scheme env), enable **Maps SDK for iOS**, restrict to bundle **`com.vuum.app`**, then rebuild the IPA. Do not invent or commit keys.

Account → Diagnostics (DEBUG builds) shows key Present/Absent and “Maps SDK configured” without exposing the key.

---

## 9. Explicitly out of scope

- Firebase / GoogleService-Info.plist
- BLE
- Snyk
- Navigation SDK (turn-by-turn)
- Committing real API keys
- Broadening the iOS key to “all Maps Platform APIs”
