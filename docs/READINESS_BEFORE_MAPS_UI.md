# Readiness before Google Maps UI customization

**Date:** 2026-08-23  
**Product:** Vuum rider iOS (`ios/Vuum/`, bundle `com.vuum.app`)  
**Verdict:** **YES — ready to focus on Google Maps UI step-by-step**, once a restricted API key is injected. Remaining blockers are credentials + physical-device evidence only.

Companions: [`DIRECTIVE_GAP_STATUS.md`](DIRECTIVE_GAP_STATUS.md) · [`GOOGLE_MAPS_SETUP.md`](GOOGLE_MAPS_SETUP.md) · [`ENGINEERING_COMPLETION_REPORT.md`](ENGINEERING_COMPLETION_REPORT.md)

---

## Ready to focus on Google Maps UI?

### **YES**

Rider presentation software is in place under `ios/Vuum/`. Maps / Places / Routes clients are wired; without a key the app still runs (placeholder map, local places, synthetic routes).

### Remaining blockers (not feature holes)

| Blocker | Why |
|---------|-----|
| Google Cloud billing + Maps SDK for iOS / Places API (New) / Routes API (+ Directions fallback) enabled | Live tiles / Places / road polylines |
| API key restricted to iOS bundle `com.vuum.app` | Security + App Store–ready restriction |
| Inject `VUUM_GOOGLE_MAPS_API_KEY` (Codemagic secure env / Xcode scheme / gitignored `ios/Secrets.xcconfig`) and rebuild | Activates `MapBootstrap` |
| §72 physical device QA log filled | Operator Sideloadly/TestFlight evidence — template: [`DEVICE_QA_EVIDENCE.md`](DEVICE_QA_EVIDENCE.md) |

Do **not** block Maps UI work on L10n completeness, full marketplaces, or backend settlement.

---

## Done summary

- Auth → KeychainSwift session → Home / Services / Activity / Account
- Full trip phase machine in `TripSession` (book → match → en route → PIN → in-trip → complete)
- Safety (SOS, share, trusted contacts, trip audio flag, incidents), chat gating, cancel fees, surge/promo
- Payments shells + history; corporate / executive / field-sales shells
- Product sheets: ride tiers, 2-Wheels, Hourly (also Rental tile), Airport, Executive, Hotel, Group, Courier, Food, Grocery, **Convenience, Alcohol, Health**
- Maps stack software: `MapBootstrap`, `VuumMapView` (optional `VuumMapStyle.json` / `VuumMapStyleLite.json` hook), `PlacesSearchService`, `RoutesAPIService`, `DirectionsRouteService`, reverse geocode
- Offline banner / status UI; hidden diagnostics; no user-visible “demo” copy
- Docs: SETUP, GOOGLE_MAPS_SETUP, CODEMAGIC_SETUP, TESTING_MATRIX, RFQ_204_MATRIX, ENGINEERING_COMPLETION_REPORT, DIRECTIVE_GAP_STATUS
- Unit tests under `ios/VuumTests/` (phases, ETA, fare/promo, auth, money, payment/referral — see `TESTING.md`)

### Partial (OK to leave while doing Maps UI)

- L10n FR/EN/LN/SW — many flow strings still English literals
- Scheduled rides edit/reminders thinner than Uber
- Account / support / lost-item — not full backend ticket SM
- Trip audio — on-device only
- Food / Grocery / Convenience / Alcohol / Health — booking sheets, not full marketplaces
- §75 unit tests — not full async OTP / cancel-fee matrix

---

## Still open (Maps key / device QA only, ideally)

1. Credential checkpoint — [`GOOGLE_MAPS_SETUP.md`](GOOGLE_MAPS_SETUP.md)
2. Fill [`DEVICE_QA_EVIDENCE.md`](DEVICE_QA_EVIDENCE.md) after Sideloadly/TestFlight on a real iPhone
3. (Optional polish later) expand L10n literals, deeper schedule edit UX

---

## Exact dependency list

Declared on `ios/Vuum.xcodeproj` (SPM). Xcode / Codemagic resolve on build. **No `Package.resolved` in repo yet** — first Mac/Codemagic resolve creates `ios/Vuum.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved` (safe to commit after a green resolve).

| Package | URL | Product | Role |
|---------|-----|---------|------|
| **Google Maps SDK** | `https://github.com/googlemaps/ios-maps-sdk` (≥ 9.0.0) | `GoogleMaps` | Live map tiles, markers, polylines |
| **ComponentsKit** | `https://github.com/componentskit/ComponentsKit` (≥ 1.7.0) | `ComponentsKit` | Shared controls / accent (`VuumTheme`) |
| **KeychainSwift** | `https://github.com/evgenyneu/keychain-swift.git` (≥ 9.0.0) | `KeychainSwift` | Rider session persistence |

**Not SPM (HTTPS helpers, same `VUUM_GOOGLE_MAPS_API_KEY`):**

| Client | File | API |
|--------|------|-----|
| Places (New) | `PlacesSearchService` | Autocomplete + Details |
| Routes | `RoutesAPIService` | `computeRoutes` |
| Directions fallback | `DirectionsRouteService` | Legacy JSON |
| Reverse geocode | `ReverseGeocodingService` | Google when keyed, else `CLGeocoder` |

**Intentionally not added:** Firebase, `ios-places-sdk`, Navigation SDK, Lottie / Framer-style web animation packages, KeychainAccess.

**Animation:** SwiftUI only (`withAnimation`, springs, press styles). No extra motion SPM.

**How installed:** File → Packages in Xcode (already in `project.pbxproj`), or Codemagic `xcodebuild` resolves SPM automatically.

---

## Next steps — Uber-like map styling (pointer only)

Do **not** redesign Maps until the key works and tiles load. Then, in order:

1. Confirm tiles via [`GOOGLE_MAPS_SETUP.md`](GOOGLE_MAPS_SETUP.md) (scheme env or `Secrets.xcconfig`).
2. Add Google Maps JSON style as bundle resource **`VuumMapStyle.json`** (optional lite: `VuumMapStyleLite.json`).  
   `VuumMapView.applyOptionalBrandMapStyle` already loads these if present.
3. Tune in **`ios/Vuum/Maps/VuumMapView.swift`**: polyline color/width, marker icons, padding vs bottom sheets, traffic / low-data.
4. Drive camera / fit / follow-driver from existing `TripSession` / flow scaffolds — avoid parallel clocks in SwiftUI.
5. Presenter check: Home → book → search → approach → in-trip polyline with live tiles.

Key files: `MapBootstrap.swift`, `VuumMapView.swift`, flow scaffolds, `TripSession` motion timing.
