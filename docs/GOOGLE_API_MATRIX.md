# Google Maps Platform — API matrix (VUUM iOS)

**Date:** 2026-08-23  
**Bundle:** `com.vuum.app`  
**Code sources of truth:** `MapBootstrap`, `PlacesSearchService`, `RoutesAPIService`, `DirectionsRouteService`, `ReverseGeocodingService`, `GoogleRouteProvider`

## Client usage vs Cloud enablement

| Google service | Used by iOS client? | Where | Rider need? | Key restriction |
|----------------|---------------------|-------|-------------|-----------------|
| Maps SDK for iOS | **Yes** | `MapBootstrap` → `GMSMapView` | Required for live tiles | **KEEP** |
| Places API (New) | **Yes** | `PlacesSearchService` HTTPS autocomplete + details | Required for live search | **KEEP** |
| Routes API | **Yes** (primary) | `RoutesAPIService` via `GoogleRouteProvider` | Preferred road polyline / ETA | **KEEP** |
| Directions API | **Yes** (fallback only) | `DirectionsRouteService` if Routes fails | Temporary fallback | **KEEP until Routes proven on device**, then drop from key |
| Geocoding API | **Optional secondary** | `ReverseGeocodingService` after Apple `CLGeocoder` | Nice-to-have pickup labels | **KEEP or remove** if Apple-only is enough |
| Places API (legacy) | No | — | No | **REMOVE FROM KEY** |
| Places UI Kit | No | — | No | **REMOVE FROM KEY** |
| Places Aggregate | No | — | No | **REMOVE FROM KEY** |
| Distance Matrix | No | — | No | **REMOVE FROM KEY** |
| Route Optimization | No | — | Future backend only | **REMOVE FROM KEY** |

## Architecture decisions (locked for this build)

1. **Routes primary, Directions fallback** — not two parallel primaries (`GoogleRouteProvider`).
2. **Places via HTTPS (New)** — no Places SDK / PlacesSwift SPM until a clear product need; avoids CocoaPods and extra package risk.
3. **Apple-first reverse geocode** — Google Geocoding only if Apple returns nothing useful.
4. **Single presentation key** — Maps SDK + client REST share `VUUM_GOOGLE_MAPS_API_KEY` with `X-Ios-Bundle-Identifier: com.vuum.app`. Split SDK vs REST keys later if a backend proxy lands.
5. **No Distance Matrix / Route Optimization / Aggregate / UI Kit** on the rider client.

## Operator Cloud checklist (not software)

- [ ] Restrict key: iOS apps → `com.vuum.app`
- [ ] API allow-list: Maps SDK for iOS, Places API (New), Routes API, Directions (optional), Geocoding (optional)
- [ ] Codemagic group `vuum_secrets` → `VUUM_GOOGLE_MAPS_API_KEY`
- [ ] Regenerate key if it was ever pasted into chat / screenshots

See also: [`GOOGLE_MAPS_SETUP.md`](./GOOGLE_MAPS_SETUP.md) · [`GOOGLE_MAPS_ARCHITECTURE.md`](./GOOGLE_MAPS_ARCHITECTURE.md) · [`PRE_BUILD_MAPS_GATE.md`](./PRE_BUILD_MAPS_GATE.md)
