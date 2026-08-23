# Places implementation decision — Vuum iOS

**Date:** 2026-08-23  
**Audit:** §36–§37 ([Maps audit gap status](MAPS_AUDIT_GAP_STATUS.md))

## Decision

**Use Places API (New) over HTTPS** in `PlacesSearchService` (Autocomplete + Place Details, session tokens, field masks).  
**Do not add** SPM `ios-places-sdk` / `GooglePlaces` / `GooglePlacesSwift` unless a future audit finds HTTPS insufficient.

## Why HTTPS (not native Places SDK)

| Factor | HTTPS (current) | Native Places SPM |
|--------|-----------------|-------------------|
| Coverage needed | Autocomplete + Details only | Same + UI Kit / extras unused |
| Session billing | UUID session token already wired | Available, but migration cost |
| Fallback | Local `MockPlaces` catalog on fail / no key | Still need catalog path |
| Binary / SPM surface | Maps SDK only | Second Google package |
| UI | Custom Vuum search sheets | Places UI Kit would fight brand |

Existing implementation is stable, covers the rider booking path, and matches Cloud key scope (**Places API (New)**). Migrating for fashion or preview Swift SDK features is not justified.

## When to reconsider native SDK

Revisit only if an audit requires it, for example:

- HTTPS cannot meet a required Places capability the product must ship
- Google deprecates the REST New endpoints we call
- We need SDK-only session / attribution behavior we cannot replicate safely

Until then: keep **Places UI Kit** off the product and off the iOS key.

## Related: Maps SDK SPM pin (§36)

| Package | URL | Rule | Product |
|---------|-----|------|---------|
| Maps SDK for iOS | `https://github.com/googlemaps/ios-maps-sdk` | `upToNextMajorVersion` from **10.0.0** | `GoogleMaps` |

- **Floor raised** from 9.0.0 → **10.0.0** (current 10.x line; product already uses the single `GoogleMaps` product).
- **11.x not forced** — Google has published 11.0.0; major migration stays opt-in after release-notes review (no blind upgrade).
- No CocoaPods. No `Package.resolved` in repo yet; first Mac/Codemagic resolve may commit one.

See also [`GOOGLE_MAPS_SETUP.md`](GOOGLE_MAPS_SETUP.md).
