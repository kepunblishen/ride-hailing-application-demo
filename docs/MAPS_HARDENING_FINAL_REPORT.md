# Maps hardening — final report (audit §78 A–T)

**Product:** Vuum rider iOS (`com.vuum.app`)  
**Audit source:** [`VUUM — Post-Implementation Google Maps-API Architecture Audit & Final Product Hardening.md`](../VUUM%20—%20Post-Implementation%20Google%20Maps-API%20Architecture%20Audit%20%26%20Final%20Product%20Hardening.md)  
**Reconcile date:** 2026-08-23  
**Honesty rule:** Only claims verified in repo / CI docs are stated as done. Cloud Console and physical-device QA stay open unless evidenced.  
**Companions:** [`MAPS_AUDIT_GAP_STATUS.md`](./MAPS_AUDIT_GAP_STATUS.md) · [`MAPS_CAPABILITY_MATRIX.md`](./MAPS_CAPABILITY_MATRIX.md) · [`GOOGLE_MAPS_SETUP.md`](./GOOGLE_MAPS_SETUP.md) · [`GOOGLE_API_MATRIX.md`](./GOOGLE_API_MATRIX.md) · [`GOOGLE_MAPS_ARCHITECTURE.md`](./GOOGLE_MAPS_ARCHITECTURE.md) · [`GOOGLE_INTEGRATION_TEST_PLAN.md`](./GOOGLE_INTEGRATION_TEST_PLAN.md) · [`PLACES_SDK_DECISION.md`](./PLACES_SDK_DECISION.md)  
**Snyk:** Not used (workspace policy).

---

## Verdict (one line)

Software Maps wiring and audit docs (§69 / §73 / §74 / §78) are largely in place for a keyed presentation build; **Cloud restriction enforcement and device E2E evidence remain open** — do not treat “key exists” as acceptance closure.

---

## A. Google APIs actually used

| API | How | Owning code |
|-----|-----|-------------|
| **Maps SDK for iOS** | SPM `GoogleMaps`; `GMSServices.provideAPIKey` | `MapBootstrap`, `VuumMapView` |
| **Places API (New)** | HTTPS Autocomplete + Place Details | `PlacesSearchService` |
| **Routes API** | HTTPS `computeRoutes` (traffic-aware, field mask, polyline) | `RoutesAPIService` via `RouteEngine` |
| **Directions API** | HTTPS JSON fallback when Routes fails | `DirectionsRouteService` |
| **Geocoding API** | HTTPS reverse geocode when keyed | `ReverseGeocodingService` (then `CLGeocoder`, then coord label) |

Shared credential: `VUUM_GOOGLE_MAPS_API_KEY` via `MapBootstrap.resolvedAPIKey()`.

---

## B. Google APIs enabled but not used

**Not verifiable from git** which APIs are enabled on the Cloud project. From **client code**, these are **not called** and must not stay on the iOS key if ever allowed:

| Service | Client status |
|---------|---------------|
| Distance Matrix API | No calls |
| Route Optimization API | No calls |
| Places Aggregate API | No calls |
| Places UI Kit | Not integrated |
| Places API (legacy) / Places SDK SPM | Not in project |
| Navigation SDK | Not in project |

Project may keep unused APIs **enabled** for future backend use; they must still be **off the iOS key**.

---

## C. APIs removed from the iOS API key restriction

**Operator action — not completed in-repo.** Recommended restriction set for the current iOS key:

| Keep on iOS key | Drop from iOS key (if present) |
|-----------------|--------------------------------|
| Maps SDK for iOS | Distance Matrix |
| Places API (New) | Places Aggregate |
| Routes API | Places UI Kit |
| Directions API *(until code removes fallback)* | Route Optimization |
| Geocoding API *(only while client reverse-geocode uses Google)* | Legacy Places (unless native SDK added later) |

Application restriction: iOS apps → bundle **`com.vuum.app`**.

---

## D. APIs that should eventually be backend-only

| Service | Why |
|---------|-----|
| Geocoding (forward/reverse at volume) | Protect web credentials; prefer Apple/`CLGeocoder` or server proxy |
| Directions / Routes for server-side dispatch | Driver assignment, fleet ETA, multi-rider optimization |
| Route Optimization | Dispatch / logistics — never on rider key |
| Distance Matrix | Batch ETA / matching — backend |
| Places Details at high fan-out | Sessionized client OK; bulk enrichment → backend |
| Any unrestricted server key | Never ship in IPA |

---

## E. Google SDK versions

| Package | Declared requirement | Resolved version in repo |
|---------|----------------------|---------------------------|
| `ios-maps-sdk` / product `GoogleMaps` | SPM `upToNextMajorVersion` from **10.0.0** | **No `Package.resolved` committed** — exact resolved patch unknown until Mac resolve |
| Places / Routes / Directions / Geocoding | N/A (HTTPS) | — |
| GooglePlaces / PlacesSwift SPM | **Not added** | REST New — see `PLACES_SDK_DECISION.md` |

11.x not forced. Do not blind-upgrade without a Mac resolve + smoke build.

---

## F. Maps implementation

| Item | Status |
|------|--------|
| SPM-only Maps (no CocoaPods) | **Done** |
| Central key bootstrap | **Done** (`MapBootstrap`) |
| `GMSMapView` wrapper + pins / polyline | **Done** (`VuumMapView`) |
| Graceful no-key placeholder | **Done** |
| Custom map style JSON | **Partial** — style assets / hooks exist; presentation polish unproven |
| Gesture-safe camera / follow | **Partial** — code present; device fight unproven |
| Maps credential DEBUG panel | **Missing / partial** — generic diagnostics, not full Maps matrix |
| Live tiles on physical device | **Open** — needs keyed IPA + evidence |

---

## G. Places implementation

| Item | Status |
|------|--------|
| Autocomplete + Details (New) | **Done** over HTTPS |
| Session UUID + UI debounce (~280 ms) | **Done** |
| Details field mask | **Done** (`id,displayName,formattedAddress,location`) |
| Local catalog fallback without key | **Done** |
| `includedTypes` / type icons | **Missing** |
| Rich distance / category chrome | **Partial** |
| Native Places SDK / UI Kit | **Correctly not used**; decision: `PLACES_SDK_DECISION.md` |
| Stale-response generation | **Done / partial** — `PlacesSearchController` cancel + generation guard |
| Bounded place-details cache | **Missing** |

---

## H. Routes implementation

| Item | Status |
|------|--------|
| Routes API primary | **Done** |
| Directions JSON fallback | **Done** (justified resilience; may drop from key after Routes device proof) |
| Synthetic geometry without key | **Done** (`TripGeo`) |
| Polyline decode → map | **Done** |
| Multi-stop intermediates | **Done** |
| Domain `Route` richness (legs, traffic vs static) | **Partial** |
| `RouteProvider` swappable protocol | **Done** — `GoogleRouteProvider` (Routes → Directions → synthetic + cache) |
| In-trip remaining duration from Google | **Partial** — often `TripGeo.etaMinutes(speedKmh:)` |
| Route deviation monitor | **Done** |
| Duplicate fetch on resume | **Unproven** |

---

## I. Geocoding implementation

| Item | Status |
|------|--------|
| Google reverse geocode when keyed | **Done** |
| Fallback `CLGeocoder` | **Done** |
| Throttle (distance / time) | **Done** (~45 m / 18 s in `TripSession`) |
| Forward geocode | Not a primary path (Places Details supplies coords) |
| Prefer Apple-first or backend-only architecture | **Open decision** (§44) |
| `X-Ios-Bundle-Identifier` on REST | **Missing** |

---

## J. API-key / security findings

| Finding | Severity | Status |
|---------|----------|--------|
| No real key committed in tracked plist/xcconfig/scheme | Good | Verified pattern in setup docs |
| Placeholder detection in `MapBootstrap` | Good | Done |
| Single universal key for SDK + all REST | Medium | Split plan missing |
| iOS bundle restriction prescribed in docs | Good guidance | **Console enforcement not verified** |
| Minimal API restriction set prescribed | Good guidance | **Operator must apply** |
| REST without iOS bundle header | Medium | Open |
| Views do not hold raw keys / HTTP | Good | Done |
| Codemagic secure group `vuum_secrets` | Good wiring | Release+key run not proven here |

---

## K. Billing / cost-control findings

| Control | Status |
|---------|--------|
| Autocomplete session tokens | **Done** |
| Places field masks | **Done** |
| Search debounce | **Done** |
| Reverse-geocode throttle | **Done** |
| Routes field mask | **Done** (service-level) |
| Bounded caches (places / identical O-D / geocode) | **Missing** |
| Request telemetry / accounting | **Missing** |
| Bounded retry (no retry on 403 / bad key) | **Missing** (single-shot) |
| Silent fallback may hide paid-path failures | Risk | Rider may not see Retry |

---

## L. Google documentation deviations discovered

1. **Web services from the device** with one shared key — Google prefers strong app restrictions and often server-side for Geocoding/Directions-class traffic; Vuum documents this but has not split keys.  
2. **Places via REST New instead of Places SDK** — intentional (`PLACES_SDK_DECISION.md`).  
3. **Directions kept as justified fallback** beside Routes — dual path locked as resilience until Routes proven on device, then may drop from key.  
4. **Geocoding REST primary when keyed** — audit prefers native-first / secured web; current order is Google → Apple → coord.  
5. **No `Package.resolved`** — exact patch vs current Google iOS guidance cannot be asserted from this Windows workspace alone.

---

## M. Changes made

This A–T / matrix pass **documents** status (no feature code in this pass). Prior Maps hardening already delivered (among others):

- `MapBootstrap` / `VuumMapView` / SPM GoogleMaps (≥ 10.0.0)  
- Places (New) HTTPS + sessions + field masks + search controller  
- `RouteEngine` (Routes → Directions → synthetic)  
- Reverse geocode throttle; driver-on-polyline; multi-stop; deviation  
- Codemagic key inject; setup / architecture / API matrix / integration test plan  
- Gap inventory: `MAPS_AUDIT_GAP_STATUS.md`  
- **This pass:** `MAPS_CAPABILITY_MATRIX.md` + this A–T report; audit tracker §69 / §78 marked  

**Not done in this pass:** cache/retry/error-map/key-split code; Cloud Console edits; device evidence fill-in.

---

## N. New features discovered and added

From §68 / product directive work (already in tree — not invented for this report):

- Trip PIN, in-trip destination change, multi-stop, reserve, ride-for-others  
- Quiet ride + accessibility notes  
- Safety toolkit, SOS UI, trusted contacts, trip share surface  
- Lost-item support UI, saved places / favorites  
- Airport / zone-aware chrome  

**Still missing vs discovery list:** favorite drivers, full pickup-note/landmark product, child-seat SKU, rider verification, suspicious-trip alerts, live safety backend.

See [`MAPS_CAPABILITY_MATRIX.md`](./MAPS_CAPABILITY_MATRIX.md).

---

## O. RFQ coverage improvements

Maps-adjacent RFQ themes covered in the **rider client presentation slice**:

- Map-centric booking, multi-stop, scheduled/reserve path, dynamic route/fare hooks when keyed  
- Kenya / DRC market configuration (locale, currency, market override) — **device proof open**  
- Safety / SOS / share surfaces for RFQ trust themes  

Gaps: production dispatch, real payments settlement, real SOS ops, driver app — explicitly out of this client’s backend scope. Cross-ref: `RFQ_204_MATRIX.md`, `DIRECTIVE_GAP_STATUS.md`.

---

## P. Bugs discovered and fixed

Documented in prior QA passes (not re-litigated here), including:

- In-trip destination change applying live polyline + fare (`destinationRouteGeneration` + unit tests)  
- SOS confirmation sheet wiring  
- Map key placeholder / scheme env shadowing issues addressed in `MapBootstrap` + setup docs  

**Open defect class:** silent Google failures; possible stale Places results; in-trip ETA realism; resume duplicate Google calls — **unproven / unfixed** as of this report.

---

## Q. Tests performed on physical iPhone

| Layer | Result |
|-------|--------|
| Unit / logic tests (`VuumTests`, incl. Maps-adjacent) | Present in repo (e.g. destination change, map bootstrap key, places catalog, reverse naming, pickup ETA) |
| `DEVICE_QA_EVIDENCE.md` | **Template only — awaiting device run** |
| `MAPS_POST_KEY_QA.md` | Checklist **not signed off** in repo |
| Kenya GPS + DRC `OperatingMarket` on device | **Not evidenced** |

Do **not** claim physical-device Maps acceptance from this document.

---

## R. Release build result

| Item | Status |
|------|--------|
| `codemagic.yaml` unsigned IPA workflow | Present |
| Secure env → `Secrets.xcconfig` inject | Scripted |
| Successful Release IPA with live key + Sideloadly | **Not verified in this audit pass** |
| Xcode warning audit on Maps packages | **Not run** |

---

## S. Remaining limitations

1. One client key for SDK + Places + Routes + Directions + Geocoding.  
2. No bounded Google response caches or request telemetry.  
3. No central Google→rider error map / Retry UX.  
4. Directions kept as Routes fallback (may remove from key after device proof).  
5. In-trip ETA often speed-based even when a live route exists.  
6. Mock nearby fleet / local trip motion (no live driver GPS).  
7. SOS / payments / OTP backends are presentation-local.  
8. Cloud Console state and device Maps E2E not proven in git.

---

## T. Exact remaining work before client presentation

**Must (presentation with live maps):**

1. Apply Cloud key restrictions (bundle `com.vuum.app` + minimal API set in §C / `GOOGLE_API_MATRIX.md`).  
2. Inject real key via Codemagic / gitignored Secrets — rebuild IPA — Sideloadly.  
3. Complete [`MAPS_POST_KEY_QA.md`](./MAPS_POST_KEY_QA.md) on a physical iPhone (tiles, blue-dot, Places, route, ETA, multi-stop, destination change).  
4. Fill [`DEVICE_QA_EVIDENCE.md`](./DEVICE_QA_EVIDENCE.md) for Kenya GPS and DRC market override.  
5. Confirm no user-visible “demo” copy; disclose SOS/payment backend scope if asked.

**Should (credibility / security):**

6. After Routes proven on device, drop Directions from code **or** keep as documented resilience and leave on key.  
7. Document Geocoding Apple-first / backend move; plan SDK vs web key split.  
8. Maps DEBUG diagnostics (key boolean / last Google error — never raw key).  
9. Rider-visible Retry on route/Places failure; strengthen in-trip ETA from remaining route duration where still speed-based.

**Can defer post-presentation:**

10. PlaceProvider, Places type chrome, favorite drivers, Navigation SDK, backend Geocoding proxy.

**Explicit non-goals for presentation gate:** Snyk; committing real keys; shipping driver/admin backends.

---

## Sign-off

| Role | Status |
|------|--------|
| Repo Maps inventory (§1) | Complete |
| Uber/Bolt matrix (§69) | Complete → `MAPS_CAPABILITY_MATRIX.md` |
| Architecture / API matrix / test plan (§73–§74) | Authored (separate docs) |
| Final A–T (§78) | Complete → this file |
| Cloud + device acceptance (§77 Google) | **Open** |
| Full audit / presentation closure | **Not claimed** |
