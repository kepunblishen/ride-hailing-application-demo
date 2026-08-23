# Google Maps / Places / Routes — Vuum iOS

**GOOGLE MAPS / PLACES / ROUTES CREDENTIAL CHECKPOINT**

Software wiring is in place. The **only remaining step** is a Google Cloud API key (plus enabling the three APIs below). Do not commit real keys.

| Layer | Implementation | SPM? |
|-------|----------------|------|
| **Maps SDK for iOS** | `MapBootstrap` + `VuumMapView` (`GMSServices.provideAPIKey`) | Yes — `https://github.com/googlemaps/ios-maps-sdk` product `GoogleMaps` |
| **Places API (New)** | `PlacesSearchService` (Autocomplete + Details, session tokens) | No — HTTPS |
| **Routes API** | `RoutesAPIService` (`computeRoutes`, traffic-aware, polyline decode) | No — HTTPS |
| **Directions API** | `DirectionsRouteService` (legacy JSON fallback when Routes fails) | No — HTTPS |

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
   - **Places API (New)** (optional autocomplete)
4. **APIs & Services → Credentials → Create credentials → API key**.
5. Restrict the key:
   - **Application restrictions:** iOS apps → bundle ID `com.vuum.app`
   - **API restrictions:** restrict to **Maps SDK for iOS**, **Places API (New)**, **Routes API**
6. Copy the key. Paste only into Codemagic secure env, Xcode scheme env, or local `Secrets.xcconfig` — **never into git**.

Official docs:

- [Maps SDK setup](https://developers.google.com/maps/documentation/ios-sdk/config)
- [Get an API key](https://developers.google.com/maps/documentation/ios-sdk/get-api-key)
- [Places API (New)](https://developers.google.com/maps/documentation/places/web-service/op-overview)
- [Routes API](https://developers.google.com/maps/documentation/routes)

---

## 2. How Vuum loads the key

`MapBootstrap` resolves the first usable value from:

| Order | Source | Typical use |
|------|--------|-------------|
| 1 | Process env `VUUM_GOOGLE_MAPS_API_KEY` | Xcode scheme Run → Environment Variables |
| 2 | Info.plist `VUUM_GOOGLE_MAPS_API_KEY` | `Secrets.xcconfig` / Codemagic `xcodebuild` injection |
| 3 | Info.plist `GMSApiKey` | Legacy alias |

Placeholders (`YOUR_GOOGLE_MAPS_API_KEY`, empty, `$(VUUM_GOOGLE_MAPS_API_KEY)`, `$(GMSApiKey)`) are ignored.

The same resolved key is used for:

1. `GMSServices.provideAPIKey` (map tiles / markers / polylines)
2. Places HTTPS (`X-Goog-Api-Key`)
3. Routes HTTPS (`X-Goog-Api-Key`)

**App Transport Security:** default ATS is fine (HTTPS only).

**Info.plist already includes:**

- `NSLocationWhenInUseUsageDescription` / Always — location
- `LSApplicationQueriesSchemes` → `comgooglemaps`, `googlechromes`
- `VUUM_GOOGLE_MAPS_API_KEY` = `$(VUUM_GOOGLE_MAPS_API_KEY)`

`ios/Vuum/Config/Vuum.xcconfig` defaults the build setting to empty and optionally includes gitignored `ios/Secrets.xcconfig`.

---

## 3. Local Mac / Xcode

**Option A — Scheme env (simulator / Run from Xcode)**

1. Scheme **Vuum** → Run → Arguments → Environment Variables  
2. Set `VUUM_GOOGLE_MAPS_API_KEY` = your real key

**Option B — Secrets.xcconfig (device / IPA-like builds)**

```bash
cp ios/Secrets.example.xcconfig ios/Secrets.xcconfig
# Edit ios/Secrets.xcconfig — set VUUM_GOOGLE_MAPS_API_KEY to the real key
# File is gitignored — do not commit it
```

---

## 4. Codemagic (Windows → Sideloadly path)

1. Codemagic → Application → Environment variables:

   | Name | Value | Secure |
   |------|--------|--------|
   | `VUUM_GOOGLE_MAPS_API_KEY` | your key | Yes |

2. Workflow `ios-release` already passes:

   `VUUM_GOOGLE_MAPS_API_KEY="${VUUM_GOOGLE_MAPS_API_KEY}"`

   into `xcodebuild` so Info.plist substitution succeeds.

3. Rebuild → download `build/Vuum.ipa` → Sideloadly.

Without the env var the IPA still builds; map uses placeholders, Places falls back to the local catalog, Routes stay offline-safe.

---

## 5. Places session architecture

Implemented in `PlacesSearchService`:

- One UUID **session token** per typing session (`beginSession` / auto-create on first request)
- Autocomplete requests reuse that token
- Place Details sends the same token, then clears the session (`endSession` / after successful `resolve`)
- Abandoned searches call `abandonSession`
- Field mask on Details limited to `id,displayName,formattedAddress,location`
- **Fallback:** if the key is missing or the Places request fails, fuzzy-match the local market catalog (`MockPlaces`) so booking always has results

Optional later: add SPM `https://github.com/googlemaps/ios-places-sdk` if you prefer the native SDK over HTTPS — not required for credential activation.

---

## 6. Routes architecture

Implemented in `RoutesAPIService`:

- `POST https://routes.googleapis.com/directions/v2:computeRoutes`
- Traffic-aware (`TRAFFIC_AWARE`), optional intermediates + alternatives
- Decodes `encodedPolyline` → `[GeoPoint]`
- Returns `nil` without a key so `TripSession` / `TripGeo` keep working

---

## 7. Checklist (credentials only)

- [ ] Billing linked
- [ ] **Maps SDK for iOS** enabled
- [ ] **Places API (New)** enabled
- [ ] **Routes API** enabled
- [ ] Key restricted to iOS bundle ID `com.vuum.app`
- [ ] API restrictions include Maps + Places (New) + Routes
- [ ] Key set in Codemagic **or** scheme **or** `Secrets.xcconfig` (not git)
- [ ] Rebuild and confirm live map tiles
- [ ] Confirm autocomplete returns suggestions
- [ ] Confirm route polyline / ETA when `RoutesAPIService` is used with a key
- [ ] Location permission accepted when testing my-location

---

## 8. Explicitly out of scope

- Firebase / GoogleService-Info.plist
- BLE
- Snyk
- Navigation SDK (turn-by-turn)
- Committing real API keys
