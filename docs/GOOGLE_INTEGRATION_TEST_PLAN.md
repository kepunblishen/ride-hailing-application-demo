# Google Maps — post-key integration test plan

**Date:** 2026-08-23  
**When:** After Codemagic IPA with `VUUM_GOOGLE_MAPS_API_KEY` + Sideload  
**Template evidence:** [`DEVICE_QA_EVIDENCE.md`](./DEVICE_QA_EVIDENCE.md) · [`MAPS_POST_KEY_QA.md`](./MAPS_POST_KEY_QA.md)

| # | Scenario | Expected | Pass? |
|---|----------|----------|-------|
| 1 | Cold launch with key | Live map tiles (not unavailable plane) | |
| 2 | Destination search | Google suggestions (not only catalog) when online | |
| 3 | Select place | Coordinates resolve; map pin moves | |
| 4 | Choose ride → match | Road polyline (not straight synthetic) when Routes OK | |
| 5 | Driver approach | Marker moves along polyline; heading rotates | |
| 6 | In-trip | ETA decreases with progress; route corridor holds | |
| 7 | Change destination | Polyline + fare refresh | |
| 8 | Airplane mode | Offline banner; no crash; local fallbacks | |
| 9 | Invalid key (optional rebuild) | Unavailable map / catalog search; no raw Google errors | |
| 10 | Diagnostics (7× Version) | Key present boolean; bundle `com.vuum.app`; last error code only | |

**Kenya GPS + DRC market override** — run rows 1–7 twice (or flip market in Diagnostics).
