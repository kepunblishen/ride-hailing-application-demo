# Blank white map + working polyline — triage

**Verdict:** White basemap with a visible route polyline means **`GMSMapView` is running**; overlays are local. **Tiles failed to load** → treat as **Google Cloud / API key (bucket A)**, not a missing Map View.

Full tables and Console steps: [`GOOGLE_MAPS_SETUP.md`](GOOGLE_MAPS_SETUP.md#8-blank--white-map-triage).

## A — Config / API (expected for this symptom)

| Check | Required |
|-------|----------|
| Billing on the Maps project | Yes |
| **Maps SDK for iOS** enabled | Yes (Places/Routes alone ≠ tiles) |
| Key API restriction includes Maps SDK for iOS | Yes |
| iOS apps restriction → `com.vuum.app` | Exact match |
| `VUUM_GOOGLE_MAPS_API_KEY` in this IPA | Codemagic `vuum_secrets` or local Secrets |

## B — App code (ruled out for “white + polyline”)

| Check | Status in Vuum |
|-------|----------------|
| Zero frame / collapsed representable | Mitigated (`GMSMapViewOptions` + `sizeThatFits`) |
| Broken night/day JSON wiping tiles | Styles clear to default on failure; optional Diagnostics toggle skips JSON |
| Cloud **Map ID** / no-code Console style | **Not used** — local `mapStyle` JSON only |
| Covering opaque SwiftUI layer | Would also hide the polyline |

## “No code from Google” / Map Builder

Console **cloud-based maps styling** (no-code editor + **Map ID**) does **not** explain blank tiles in this app, because the iOS client never passes a Map ID. You still must enable **Maps SDK for iOS** and inject the key.

## On-device QA (no key value shown)

1. Account → About → tap **Version** seven times → unlock Diagnostics.  
2. Confirm **API key present = Yes**, **Maps SDK = Yes**.  
3. Optional: Diagnostics → **Use default Google basemap** — if still white, style JSON is not the cause.  
4. Unlocked trip maps show a small **Maps QA** chip (key / SDK / last error).
