# Pre-build Maps gate — Codemagic go / no-go

**Date:** 2026-08-23  
**Product:** Vuum rider iOS (`ios/Vuum/`, bundle `com.vuum.app`)  
**Workflow:** `ios-release` in root `codemagic.yaml`  
**Audit basis:** [`DIRECTIVE_GAP_STATUS.md`](DIRECTIVE_GAP_STATUS.md) · [`READINESS_BEFORE_MAPS_UI.md`](READINESS_BEFORE_MAPS_UI.md) · [`GOOGLE_MAPS_SETUP.md`](GOOGLE_MAPS_SETUP.md) · [`CODEMAGIC_SETUP.md`](CODEMAGIC_SETUP.md) · [`ENGINEERING_COMPLETION_REPORT.md`](ENGINEERING_COMPLETION_REPORT.md)

**No Snyk** — intentionally omitted from CI and this gate. See [`NO_SNYK.md`](NO_SNYK.md).

---

## Verdict (how to use this page)

| Decision | When |
|----------|------|
| **GO — live Maps IPA** | All **User must-have** rows below are checked. Then start `ios-release`. |
| **GO — build-only IPA** | Software checklist is green; Maps key / Cloud APIs may still be missing. IPA builds; map stays on the unavailable / local-fallback surface. |
| **NO-GO — live Maps** | Any **User must-have** item is unchecked. Do **not** expect tiles, Google Places, or road polylines on device. |

Software is **not** the blocker for live maps. Credentials and Cloud console are.

---

## Software done (repo / CI wiring — audit)

These are complete in-tree. No code change is required before a Codemagic run.

| Item | Evidence |
|------|----------|
| Google Maps SPM | `ios-maps-sdk` ≥ 10.0.0 (`< 11`), product `GoogleMaps` on `Vuum` target |
| Map bootstrap | `MapBootstrap` → `GMSServices.provideAPIKey`; ignores placeholders / empty / unexpanded `$(…)` |
| Map UI | `VuumMapView` (+ optional `VuumMapStyle.json` / lite hook) |
| Places (New) HTTPS | `PlacesSearchService` (session tokens; local catalog fallback) |
| Routes HTTPS | `RoutesAPIService` (`computeRoutes`, traffic-aware) |
| Directions fallback | `DirectionsRouteService` when Routes fails / offline-safe path |
| Reverse geocode | `ReverseGeocodingService` (Apple `CLGeocoder` first; optional Google Geocoding if Apple fails) |
| Key build settings | `Vuum.xcconfig` + `#include?` `Secrets.xcconfig`; Info.plist `$(VUUM_GOOGLE_MAPS_API_KEY)` |
| Codemagic inject | Env group **`vuum_secrets`** → write `ios/Secrets.xcconfig` + pass key on `xcodebuild` |
| Unsigned IPA path | Debug `iphoneos`, no signing certs; artifact `build/Vuum.ipa` for Sideloadly |
| Trip / product shell | Auth → tabs → trip phases; safety / payments / product sheets present without a Maps key |
| Fallback without key | Placeholder map, `MockPlaces` autocomplete, `TripGeo` / synthetic routes — app still launches |
| No Snyk in workflow | `codemagic.yaml` has no security-scan steps |

Companions for depth: [`GOOGLE_MAPS_SETUP.md`](GOOGLE_MAPS_SETUP.md), [`CODEMAGIC_SETUP.md`](CODEMAGIC_SETUP.md).

---

## User must-have (credential / console — before live Maps)

Do these outside the repo. **Do not** commit real keys.

### 1. Codemagic — key in `vuum_secrets`

- [ ] In Codemagic → Application → **Environment variables**, group name exactly **`vuum_secrets`** (matches `codemagic.yaml` `environment.groups`)
- [ ] Secure variable **`VUUM_GOOGLE_MAPS_API_KEY`** = real Google Maps Platform key (not `YOUR_GOOGLE_MAPS_API_KEY`)
- [ ] Group is attached to workflow **`ios-release`** (already declared in YAML; confirm UI still lists the group)

Without this, the inject script logs `VUUM_GOOGLE_MAPS_API_KEY unset` and the IPA still builds with no live key.

### 2. Google Cloud — APIs on

Billing linked on the project, then enable:

- [ ] **Maps SDK for iOS** (tiles / markers / polylines)
- [ ] **Places API (New)** (autocomplete + details)
- [ ] **Routes API** (preferred road polylines / ETA)
- [ ] **Directions API** (fallback used by `DirectionsRouteService`)

### 3. Key restriction — bundle ID

- [ ] Application restriction: **iOS apps** → bundle ID **`com.vuum.app`**
- [ ] API restriction: at least **Maps SDK for iOS**, **Places API (New)**, **Routes API** (add **Directions API** if using the fallback path)

Wrong bundle ID → tiles fail on device even when the env var is set.

### 4. Post-build smoke (operator)

- [ ] Rebuild `ios-release` → download `build/Vuum.ipa` → Sideloadly
- [ ] Confirm live map tiles (not map-unavailable)
- [ ] Optional: Places suggestions beyond local catalog; route polyline when Routes is used

Device evidence template (separate from this gate): [`DEVICE_QA_EVIDENCE.md`](DEVICE_QA_EVIDENCE.md).

---

## Quick decision matrix

| Software wiring | Key in `vuum_secrets` | APIs on | Bundle `com.vuum.app` | Start Codemagic? | Live maps on IPA? |
|-----------------|----------------------|---------|------------------------|------------------|-------------------|
| Done | Yes | Yes | Yes | **GO** | **Yes** |
| Done | No | — | — | **GO** (build-only) | No |
| Done | Yes | No / partial | Yes | **GO** (build) | **NO-GO** for tiles/Places/Routes |
| Done | Yes | Yes | Wrong / unrestricted only | **GO** (build) | **NO-GO** / flaky on device |

---

## Explicitly out of scope for this gate

- Apple Developer Program / App Store signing (Sideloadly path)
- Filling §72 device QA rows (do after a keyed IPA)
- L10n completeness, marketplace depth, backend settlement
- Firebase, Navigation SDK, committing `Secrets.xcconfig`
- Snyk or any CI security scanner

---

## One-line summary

**Software: GO.** **Live Maps Codemagic IPA: GO only after `VUUM_GOOGLE_MAPS_API_KEY` is in group `vuum_secrets`, Maps/Places/Routes(/Directions) are enabled, and the key is restricted to `com.vuum.app`.**
