# Maps post-key QA — presenter checklist

**When:** After Sideloadly (or TestFlight) install of a build that includes a real `VUUM_GOOGLE_MAPS_API_KEY`.  
**Goal:** Confirm live Maps / Places / Routes behavior on a physical iPhone before a client presentation.  
**Not this doc:** Credential creation (see [`GOOGLE_MAPS_SETUP.md`](GOOGLE_MAPS_SETUP.md)); full product walk ([`DEVICE_QA_EVIDENCE.md`](DEVICE_QA_EVIDENCE.md)); unit tests ([`TESTING.md`](TESTING.md)).

**Snyk:** Out of scope for this workspace — do not run or wait on Snyk for Maps QA.

---

## Prerequisites (gate)

Complete before scoring the checklist below. If any gate fails, stop and fix credentials / rebuild — do not mark live-map rows Pass.

| # | Gate | ☐ |
|---|------|---|
| G1 | Google Cloud billing on; **Maps SDK for iOS**, **Places API (New)**, **Routes API** (and/or **Directions**) enabled | ☐ |
| G2 | Key restricted to iOS + bundle `com.vuum.app` | ☐ |
| G3 | Key injected via Codemagic secure env **or** gitignored `ios/Secrets.xcconfig` **or** scheme env — **not** committed | ☐ |
| G4 | Fresh IPA rebuilt **after** key injection; Sideloadly install succeeded | ☐ |
| G5 | Location permission **Allow While Using** (needed for blue-dot / pickup) | ☐ |
| G6 | Device online (Wi‑Fi or cellular) for first tile / Places / Routes fetch | ☐ |

**Do not paste the API key into this file or into git.**

| Run metadata | Value |
|--------------|--------|
| Tester | |
| Date | |
| Build / CI # | |
| Device / iOS | |
| Appearance exercised | ☐ Light · ☐ Dark · ☐ Both |

---

## 1. Tiles

Home and trip maps show **live Google basemap tiles**, not the map-unavailable / placeholder surface.

| # | Check | How | Pass |
|---|-------|-----|------|
| T1 | Home map tiles | Sign in → Home; pan / zoom; streets and labels load | ☐ |
| T2 | No “Map unavailable” | Placeholder / non-GMS surface must **not** appear when key is valid | ☐ |
| T3 | Blue-dot / my location | With Location allowed, rider position appears on the map | ☐ |
| T4 | Trip map tiles | Confirm a ride → searching / matched / en route; map still shows live tiles under chrome | ☐ |
| T5 | Camera / chrome | Bottom sheets do not permanently hide the map; recenter / follow still usable | ☐ |

**Related audit / matrix (mark after T1–T5 Pass):**

| Source | Item | Prior status | After this run |
|--------|------|--------------|----------------|
| [`TESTING_MATRIX.md`](TESTING_MATRIX.md) §3 | API key present | Blocked on Maps key | ☐ → Pass |
| [`TESTING_MATRIX.md`](TESTING_MATRIX.md) §3 | Live map tiles + blue-dot | Blocked on Maps key | ☐ → Pass |
| [`TESTING_MATRIX.md`](TESTING_MATRIX.md) §4 | Home map realism | Blocked on Maps key | ☐ → Pass |
| Directive §74 Maps | API key present | Blocked until credential checkpoint | ☐ → Pass |
| [`DEVICE_QA_EVIDENCE.md`](DEVICE_QA_EVIDENCE.md) §3.3 #9 | Home / trip map renders | Template | ☐ P |
| Agent 38 credential list | Live map tiles; blue-dot | Open | ☐ Done |

---

## 2. Search (Places)

Destination search should prefer **Google Places (New)** for arbitrary queries; local catalog remains the failure fallback (see §6).

| # | Check | How | Pass |
|---|-------|-----|------|
| S1 | Arbitrary address | Where to? → type a real street / POI **not** only in the local Lubumbashi / Nairobi catalog | ☐ |
| S2 | Suggestions appear | Autocomplete list updates while typing (session token path) | ☐ |
| S3 | Select → book | Pick a suggestion → choose-ride opens with that dropoff | ☐ |
| S4 | Pickup adjust | Adjust pickup / pin; reverse geocode label updates (Google when keyed) | ☐ |
| S5 | Recents / saved still work | Recents and saved places still set destination | ☐ |

**Related audit / matrix:**

| Source | Item | Prior status | After this run |
|--------|------|--------------|----------------|
| [`TESTING_MATRIX.md`](TESTING_MATRIX.md) §3 | Places autocomplete (Google) | Blocked on Maps key | ☐ → Pass |
| [`TESTING_MATRIX.md`](TESTING_MATRIX.md) §3 | Reverse geocode (live Google) | Blocked on Maps key | ☐ → Pass |
| Directive §74 Maps | Places available (live Google) | Blocked on Maps key | ☐ → Pass |
| QA Pass B | Places available | Architecturally ready | ☐ Live confirmed |
| [`DEVICE_QA_EVIDENCE.md`](DEVICE_QA_EVIDENCE.md) §3.3 #10 | Destination search | Template | ☐ P |
| Agent 38 | Google Places autocomplete | Open | ☐ Done |

---

## 3. Route

Confirm ride should draw a **road-following** polyline (Routes API → Directions fallback), not only the synthetic straight / approximate path.

| # | Check | How | Pass |
|---|-------|-----|------|
| R1 | Choose-ride preview | Set pickup + dropoff → open choose-ride; preview path follows roads when APIs succeed | ☐ |
| R2 | Confirm → active path | Confirm request; remaining path updates through matched / en route / in trip | ☐ |
| R3 | ETA / distance coherent | Fare / ETA panel matches a plausible road distance (not zero / nonsense) | ☐ |
| R4 | Multi-stop (if used) | Add a stop; path includes intermediate; still books | ☐ |
| R5 | In-trip destination change | Change destination; path refreshes without stuck UI | ☐ |
| R6 | High-demand / surge banner | Book from a demand/airport zone; choose-ride shows surge banner + multiplier; tier prices and fare breakdown include surge; adjust pickup → banner/fares follow new pin | ☐ |

**Related audit / matrix:**

| Source | Item | Prior status | After this run |
|--------|------|--------------|----------------|
| [`TESTING_MATRIX.md`](TESTING_MATRIX.md) §3 | Routes / Directions live polyline | Blocked on Maps key | ☐ → Pass |
| [`TESTING_MATRIX.md`](TESTING_MATRIX.md) §5 | Preview route on choose-ride (live) | Blocked on Maps key | ☐ → Pass |
| Directive §74 Maps | Routes available (live road path) | Blocked on Maps key | ☐ → Pass |
| QA Pass B | Live Google Directions | PARTIAL (synthetic without key) | ☐ Live confirmed |
| [`DEVICE_QA_EVIDENCE.md`](DEVICE_QA_EVIDENCE.md) §3.3 #12 | Active trip pins / route / follow | Template | ☐ P |
| Agent 38 | Live Directions polyline on map | Open | ☐ Done |

---

## 4. Car motion

On-map **vehicle / driver** should move along the route over time (approach + in-trip), with camera follow where the product enables it.

| # | Check | How | Pass |
|---|-------|-----|------|
| M1 | Nearby / approach pin | After match → driverEnRoute: vehicle pin moves toward pickup (not teleport-only) | ☐ |
| M2 | Remaining path shrinks | Path ahead of the driver shortens as progress advances | ☐ |
| M3 | Follow driver | Camera tracks driver during matched / en route / arrived / in trip as designed | ☐ |
| M4 | In-trip motion | After boarding PIN: vehicle continues along trip route toward dropoff | ☐ |
| M5 | Tier glyph | Bike / car / XL (as selected) reads correctly on the map pin | ☐ |

**Related audit / matrix:**

| Source | Item | Prior status | After this run |
|--------|------|--------------|----------------|
| [`TESTING_MATRIX.md`](TESTING_MATRIX.md) §6 | Approaching / en route (map motion realism) | Blocked on Maps key | ☐ → Pass |
| QA Pass B Map hooks | Follow driver; live remaining path | PASS (wiring) | ☐ Live on device |
| [`DEVICE_QA_EVIDENCE.md`](DEVICE_QA_EVIDENCE.md) §3.4 #14 | Full trip lifecycle | Template | ☐ P (map motion noted) |
| Agent 38 | On-map driver approach / in-trip vehicle animation | Open | ☐ Done |
| Acceptance walk §85 #17 | Watch vehicle approach | Motion without key; on-map needs key | ☐ Live Pass |

---

## 5. Night style

Exercise **Dark Mode** with a live map. Optional brand JSON (`VuumMapStyle.json` / `VuumMapStyleLite.json`) applies only if bundled; otherwise default Google basemap in dark UI is acceptable.

| # | Check | How | Pass |
|---|-------|-----|------|
| N1 | System Dark | Settings → Display → Dark (or Control Center); relaunch or switch while on Home | ☐ |
| N2 | Map readable | Tiles + route polyline + pins remain visible; chrome contrast OK | ☐ |
| N3 | Light ↔ Dark | Toggle appearance mid-home and mid-trip; no crash / blank map | ☐ |
| N4 | Brand style (if present) | If `VuumMapStyle*.json` is in the bundle, styled basemap loads; if absent, default Google style is OK | ☐ / N/A |
| N5 | Low-data (if exposed) | If low-data mode is on, lite style / thinner polyline still readable at night | ☐ / N/A |

**Related audit / matrix:**

| Source | Item | Prior status | After this run |
|--------|------|--------------|----------------|
| [`DEVICE_QA_EVIDENCE.md`](DEVICE_QA_EVIDENCE.md) §1 Appearance | Dark exercised | Template | ☐ Both |
| Visual consistency audit (directive §38) | Map + chrome in dark | Manual | ☐ Spot-checked |
| [`READINESS_BEFORE_MAPS_UI.md`](READINESS_BEFORE_MAPS_UI.md) | Optional style JSON after tiles work | Pointer only | ☐ Noted |

---

## 6. Fail cases

With a **keyed** build, prove graceful degradation. Do **not** show raw errors or “demo” copy to the rider.

| # | Check | How | Pass |
|---|-------|-----|------|
| F1 | Airplane / offline | Enable Airplane Mode on Home with key present | ☐ |
| F2 | Offline tiles | Cached tiles may show; otherwise degraded map — **no crash**; offline banner if applicable | ☐ |
| F3 | Places failure | Disable Places API in Cloud (or block network for Places only) → search still returns **local catalog**; no hard crash | ☐ |
| F4 | Routes failure | Disable Routes/Directions (or force network fail on confirm) → **synthetic** path / ETA retained; booking continues | ☐ |
| F5 | Reconnect | Restore network; tiles / Places / Routes recover without reinstall | ☐ |
| F6 | Location denied | Deny Location; app still opens; pickup adjust / search still usable; no infinite spinner | ☐ |
| F7 | Bad / revoked key (optional) | Build with invalid key → map unavailable / fallback; trip UI still completes | ☐ / N/A |

**Related audit / matrix:**

| Source | Item | Prior status | After this run |
|--------|------|--------------|----------------|
| [`TESTING_MATRIX.md`](TESTING_MATRIX.md) §3 | Places failure | Pass (architecture) | ☐ Device confirmed |
| [`TESTING_MATRIX.md`](TESTING_MATRIX.md) §3 | Routes failure / no key | Pass | ☐ Device confirmed (keyed fail) |
| [`TESTING_MATRIX.md`](TESTING_MATRIX.md) §15 | Offline Maps tiles | Blocked on Maps key | ☐ Manual Pass / noted |
| [`TESTING_MATRIX.md`](TESTING_MATRIX.md) §15 | Offline banner / reconnect | Manual on device | ☐ |
| Directive §51 | Google service fails | Open *(requires live key)* | ☐ Pass when F3–F5 done |
| Directive §74 Maps | Places failure / Routes failure | Pass (fallback) | ☐ Reconfirmed live |
| QA Pass B | API key absent | PASS (placeholder) | Keep as regression; optional F7 |

---

## Sign-off

| Area | Result | Notes |
|------|--------|-------|
| Tiles | ☐ Pass · ☐ Fail | |
| Search | ☐ Pass · ☐ Fail | |
| Route | ☐ Pass · ☐ Fail | |
| Car motion | ☐ Pass · ☐ Fail | |
| Night style | ☐ Pass · ☐ Fail · ☐ N/A | |
| Fail cases | ☐ Pass · ☐ Fail | |

**Presenter-ready for live maps?** ☐ Yes · ☐ No — blockers: _______________________

After Pass on §§1–4 (and night + fail as time allows):

1. Update [`TESTING_MATRIX.md`](TESTING_MATRIX.md) §3 (and live notes in §§4–6, §15) from **Blocked on Maps key** → **Pass**.
2. Fill [`DEVICE_QA_EVIDENCE.md`](DEVICE_QA_EVIDENCE.md) map rows (#9–#12, #14) and Appearance.
3. Tick Directive §74 Maps live rows + §51 “Google service fails” when F3–F5 are done.
4. Optionally note Agent 38 credential items closed in the directive / gap status.

---

## Companions

| Doc | Role |
|-----|------|
| [`GOOGLE_MAPS_SETUP.md`](GOOGLE_MAPS_SETUP.md) | Key, APIs, injection |
| [`CODEMAGIC_SETUP.md`](CODEMAGIC_SETUP.md) | CI → Sideloadly |
| [`TESTING_MATRIX.md`](TESTING_MATRIX.md) | §74 full matrix |
| [`DEVICE_QA_EVIDENCE.md`](DEVICE_QA_EVIDENCE.md) | §72 physical evidence log |
| [`QA_PASS_B.md`](QA_PASS_B.md) | Trip / Maps wiring (pre-key) |
| [`READINESS_BEFORE_MAPS_UI.md`](READINESS_BEFORE_MAPS_UI.md) | Post-tile UI polish order |
| [`NO_SNYK.md`](NO_SNYK.md) | Snyk disabled for this repo |
