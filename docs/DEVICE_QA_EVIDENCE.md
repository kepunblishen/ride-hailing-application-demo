# §72 — Physical device testing evidence

**Status:** Template ready — **awaiting device run** (Sideloadly / TestFlight).  
**Environment note:** This checklist cannot be completed from the Windows agent environment; fill it on a real iPhone after install.

Related: `docs/GOOGLE_MAPS_SETUP.md`, `docs/CODEMAGIC_SETUP.md`, `docs/QA_PASS_A.md` / `B` / `C`, `docs/TESTING.md` (unit tests ≠ device evidence).

---

## 1. Run metadata (fill in)

| Field | Value |
|-------|--------|
| **Tester name** | _TBD_ |
| **Date (local)** | _YYYY-MM-DD_ |
| **Install method** | ☐ Sideloadly IPA · ☐ TestFlight · ☐ Other: _______ |
| **IPA / build source** | ☐ Codemagic `ios-release` · ☐ Local Xcode archive · ☐ Other: _______ |
| **Artifact path / CI build #** | _e.g. `build/Vuum.ipa` / Codemagic build N_ |
| **App version** | _Marketing version_ |
| **Build number** | _CFBundleVersion_ |
| **Bundle ID** | `com.vuum.app` (confirm on device) |
| **Device model** | _e.g. iPhone 14 Pro_ |
| **iOS version** | _e.g. 17.6.1_ |
| **Appearance** | ☐ Light · ☐ Dark · ☐ Both exercised |
| **Network during run** | ☐ Wi‑Fi · ☐ Cellular · ☐ Airplane / offline drill |

---

## 2. Maps / API key note (required)

Live map tiles, Places autocomplete beyond the local catalog, and Google Routes/Directions polylines need a real **`VUUM_GOOGLE_MAPS_API_KEY`** (restricted to `com.vuum.app`) with **Maps SDK for iOS**, **Places API (New)**, and **Routes API** (and/or Directions) enabled. See `docs/GOOGLE_MAPS_SETUP.md`.

| Check | Result |
|-------|--------|
| Key present in this build? | ☐ Yes · ☐ No (placeholder / missing) |
| Map surface observed | ☐ Live Google tiles · ☐ Map-unavailable / synthetic fallback |
| Notes | _If no key: still exercise full trip UI; mark map rows N/A or Fail only if launch/crash._ |

**Do not paste the API key into this file or commit it.**

---

## 3. Critical flows — pass / fail

Mark **P** / **F** / **N/A**. Add a one-line note on Fail.

### 3.1 Install → launch → session

| # | Flow | P/F/N/A | Notes |
|---|------|---------|-------|
| 1 | Install succeeds (Sideloadly / TestFlight) | | |
| 2 | Cold launch → splash → auth or home | | |
| 3 | Sign-in path (phone → OTP → terms → confirm → welcome) | | |
| 4 | Sign out returns to Get Started | | |

### 3.2 Location & permissions

| # | Flow | P/F/N/A | Notes |
|---|------|---------|-------|
| 5 | Location permission prompt / settings path | | |
| 6 | Location used for pickup / map (or graceful denial) | | |
| 7 | Mic permission when trip audio enabled | | |
| 8 | Notification permission where offered | | |

### 3.3 Map & navigation

| # | Flow | P/F/N/A | Notes |
|---|------|---------|-------|
| 9 | Home / trip map renders (tiles **or** documented fallback) | | |
| 10 | Destination search / suggestions → choose ride | | |
| 11 | Confirm / Reserve booking | | |
| 12 | Active trip map: pins / route / driver follow (as available) | | |
| 13 | In-trip change destination | | |

### 3.4 Trip lifecycle & safety

| # | Flow | P/F/N/A | Notes |
|---|------|---------|-------|
| 14 | Searching → matched → en route → arrived → PIN → in trip → complete | | |
| 15 | Cancel search / cancel active (+ fee sheet if applicable) | | |
| 16 | Chat entry during active trip | | |
| 17 | Safety / SOS entry | | |
| 18 | Rate / receipt after complete | | |

### 3.5 Account / pay / support (smoke)

| # | Flow | P/F/N/A | Notes |
|---|------|---------|-------|
| 19 | Account hub opens; profile editable | | |
| 20 | Wallet / payment methods / payment history | | |
| 21 | Activity (past + upcoming / reserve cancel) | | |
| 22 | Help & support composer | | |

### 3.6 Device behavior (§72)

| # | Flow | P/F/N/A | Notes |
|---|------|---------|-------|
| 23 | Keyboard (phone, OTP, search, chat) — no clipped fields | | |
| 24 | Sheets / modals dismiss and re-present cleanly | | |
| 25 | Background → foreground resumes without stuck UI | | |
| 26 | Interrupted network (airplane / poor signal) — offline banner / recovery | | |
| 27 | Light and dark appearance | | |
| 28 | Orientation (portrait primary; landscape if allowed — no crash) | | |

---

## 4. Screenshot placeholders

Capture on-device; store privately or attach under a local folder **not** committed with secrets. Replace `_path_` when attached.

| Shot | What to capture | Path / link |
|------|-----------------|-------------|
| A | Splash or first frame after launch | `_screenshots/§72-A-launch.png_` |
| B | Home (map or fallback) | `_screenshots/§72-B-home.png_` |
| C | Choose ride | `_screenshots/§72-C-choose-ride.png_` |
| D | Active trip (driver / PIN / in-trip) | `_screenshots/§72-D-active-trip.png_` |
| E | Trip complete / receipt | `_screenshots/§72-E-complete.png_` |
| F | Account or wallet | `_screenshots/§72-F-account.png_` |
| G | Permission or offline state (optional) | `_screenshots/§72-G-edge.png_` |

---

## 5. Defects found on device

| ID | Severity | Steps | Expected | Actual | Build # |
|----|----------|-------|----------|--------|---------|
| D1 | | | | | |
| D2 | | | | | |

_None yet — template awaiting first run._

---

## 6. Sign-off

| Role | Name | Date | Verdict |
|------|------|------|---------|
| Tester | | | ☐ Pass · ☐ Pass with notes · ☐ Fail |
| Presenter / owner | | | ☐ Accepted for client walkthrough |

**Overall notes**

_

---

## Appendix — how to obtain build number on device

1. Install the IPA / TestFlight build.  
2. Settings → General → iPhone Storage → **Vuum**, **or** Account → About in-app if version is shown.  
3. Record **Version** + **Build** in §1 above.  
4. Prefer the same Codemagic build ID used for Sideloadly so evidence matches the IPA.
