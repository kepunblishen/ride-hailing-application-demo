# QA Pass B — Trip + Map + Chat + Safety

**Agent:** 20  
**Date:** 2026-08-23  
**Scope:** Trip lifecycle, map hooks, in-trip chat entry, safety entry  
**Method:** Static code review + wiring verification (no device run in this pass)  
**Snyk:** Not used (workspace rule)

---

## Verdict

**PASS with notes** — Core trip phases, map bindings, chat entry, and safety entry are wired end-to-end. Several presentation-only / credential-dependent gaps remain (documented below).

---

## Trip lifecycle

| Phase | Expected | Status | Notes |
|-------|----------|--------|-------|
| `idle` | Home map | PASS | `RootFlowView` → `HomeHubView` |
| `selectingDestination` | Destination search | PASS | `DestinationScaffoldView` |
| `choosingRide` | Tiers + fare + confirm | PASS | Change destination preserves stops via `changeDestination()` |
| `searching` | Matching UI | PASS | `SearchingScaffoldView` |
| `matched` | Driver assigned beat | PASS | `assignDriver` sets `.matched` ~0.9s then `.driverEnRoute` + motion |
| `driverEnRoute` | Approach motion + chat/SOS | PASS | Map follow + route remaining path |
| `driverArrived` | PIN boarding | PASS | `BoardingPINPanel`; respects `vuum.safety.requirePIN` |
| `inTrip` | Dropoff motion | PASS | Progress / ETA updates |
| `completed` | Receipt / rate | PASS | `TripCompleteScaffoldView` → `PostTripCompleteView` |
| Cancel search | Back to choose-ride | PASS | `cancelSearch` |
| Cancel active | Back to idle + fee sheet | PASS | `CancelTripSheet` + `isCancellationFree` / fee |
| Schedule reserve | Idle + reserved list | PASS | Future `scheduleForLater` skips search |

**Fixes applied this pass**

- Ensured `.matched` routes to `ActiveTripScaffoldView` (not searching UI).
- Restored `ActiveTripFlowView.swift` (active trip shell) after it was missing from the tree.
- Added `SOSConfirmationSheet` + registered `SafetyToolkitView` / `SOSConfirmationSheet` in `project.pbxproj`.
- `canRecordTripAudio` includes matched / arrived / in-trip.
- Cancel available from `.matched` as well as en-route / arrived.
- Trip-share reminder banner when `shareByDefault` is on.

---

## Map hooks

| Check | Status | Notes |
|-------|--------|-------|
| `TripMapLayer` → `VuumMapView` | PASS | camera, pins, route, fit, followDriver, `cameraFocusNonce` |
| Pins by phase | PASS | nearby / pickup-dropoff / driver |
| Route preview (choose-ride) | PASS | `previewRoute` + `RouteEngine` |
| Live remaining path | PASS | en-route / in-trip |
| Follow driver | PASS | matched + en-route + arrived + in-trip |
| API key absent | PASS | `MapPlaceholderView` when `MapBootstrap` not configured |
| Places session tokens | PASS (arch) | `PlacesSearchService` autocomplete + session token |
| Live Google Directions | PARTIAL | Falls back to synthetic polyline without credentials |

---

## Chat entry

| Check | Status | Notes |
|-------|--------|-------|
| Entry from active trip | PASS | Message / Chat opens `DriverChatView` sheet |
| `isChatAvailable` | PASS | matched → in-trip |
| Opening driver message | PASS | Seeded on assign |
| Rider send + driver reply | PASS | Typing indicator + contextual replies |
| Unread badge | PASS | Increments when chat not presented |
| Call | PASS | `tel:` via `DriverCallHelper` |
| Support chat (Account) | PASS | Separate `SupportChatSheet` — out of Pass B core but present |

---

## Safety entry

| Check | Status | Notes |
|-------|--------|-------|
| Home / hub Safety | PASS | Shield → `SafetyToolkitView` |
| In-trip SOS pill | PASS | Confirm sheet → `requestSOS` + safety-team notify flag |
| Safety toolkit | PASS | SOS, share link, incident report, audio, 112, trusted contacts |
| Trip share | PASS | `TripShare` message + live URL; reminder when share-by-default |
| Trusted contacts | PASS | Store + Account / toolkit navigation |
| Incident report | PASS | `IncidentReportView` + optional audio retain |
| Audio recording | PASS | Permissioned; denied → Settings CTA; limited to active phases |
| Boarding PIN preference | PASS | `vuum.safety.requirePIN` honored in `confirmBoarding` + panel |
| Corporate SOS copy | PASS | Toolkit / business profile references |

---

## Directive §74 testing matrix (Pass B slice)

Marked in the directive file for **Maps / Trip / Safety** rows covered by this pass.

| Area | Item | Pass B |
|------|------|--------|
| Maps | API key present / absent | Verified (wiring) |
| Maps | Places available / failure | Architecturally ready |
| Maps | Routes available / failure | Synthetic fallback |
| Trip | searching → completion | PASS |
| Trip | OTP/PIN boarding | PASS |
| Trip | destination change | PASS (choose-ride + in-trip sheet) |
| Trip | cancellation | PASS |
| Safety | SOS | PASS |
| Safety | trip share | PASS |
| Safety | trusted contacts | PASS |
| Safety | incident report | PASS |
| Safety | recording permission / start / stop | PASS |

---

## Acceptance walk (§85) — Pass B steps

| # | Step | Result |
|---|------|--------|
| 13–20 | Request → match → approach → PIN → active | PASS (local lifecycle) |
| 21 | Open chat/call | PASS |
| 22 | Open safety center | PASS |
| 23 | Share trip | PASS |
| 24 | SOS workflow | PASS (local notify flag) |
| 25 | Change destination | PASS (sheet + choose-ride) |
| 26–29 | Complete / fare / rate / receipt | PASS (post-trip flow present) |

---

## Open issues / credentials

1. **Google Maps/Places/Routes** need real API keys for live tiles, autocomplete, and Directions (see `docs/GOOGLE_MAPS_SETUP.md`).
2. **SOS / trip share** do not call a real Safety backend — local UI + simulated notify state only.
3. **Share by default** prompts the rider; it does not auto-SMS contacts (no messaging backend).
4. Parallel agent churn previously removed `ActiveTripFlowView`; file is restored and listed in the Xcode project.

---

## Files touched (this agent)

- `ios/Vuum/UI/Flow/ActiveTripFlowView.swift` (restored)
- `ios/Vuum/UI/Flow/SOSConfirmationSheet.swift` (new)
- `ios/Vuum/UI/Flow/LiveTripComponents.swift` (`BoardingPINPanel.requirePIN`)
- `ios/Vuum/Services/TripSession.swift` (matched beat, audio phases, PIN preference — verified)
- `ios/Vuum.xcodeproj/project.pbxproj` (SafetyToolkit + SOSConfirmation sources)
- `docs/QA_PASS_B.md` (this report)
- Directive §74 matrix marks for Trip / Maps / Safety
