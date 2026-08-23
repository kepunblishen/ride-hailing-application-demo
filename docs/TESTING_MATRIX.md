# Vuum iOS — Full device / feature testing matrix (§74)

**Directive:** §74 TESTING MATRIX  
**Date:** 2026-08-23  
**Scope:** Rider presentation app under `ios/Vuum/`  
**Related:** `docs/TESTING.md` (unit tests), `docs/QA_PASS_A.md` / `B` / `C`, `docs/GOOGLE_MAPS_SETUP.md`, `docs/DIRECTIVE_GAP_STATUS.md`

## How to read status

| Status | Meaning |
|--------|---------|
| **Pass** | Code-path verified in QA passes A–C and/or unit tests; runnable without a live Maps key (synthetic / local catalog / fallback UI). |
| **Blocked on Maps key** | Feature exists in software but **live** tiles, Google Places autocomplete, or road polylines need `VUUM_GOOGLE_MAPS_API_KEY` + enabled Cloud APIs. Without the key, a fallback still works — do not treat the whole booking flow as broken. |
| **Manual on device** | Requires physical iPhone (or simulator with OS prompts): permissions, mic, Keychain persistence across relaunch, airplane mode, Sideloadly install. Not fully evidenced in-repo yet (§72 still open). |

**OTP for presenters:** last 4 digits of the national number; backup `0000`.  
**Promos:** `VUUM10`, `WELCOME`.  
**Bundle ID:** `com.vuum.app`.

---

## 1. Authentication

| Feature | How to test | Expected result | Status |
|---------|-------------|-----------------|--------|
| Fresh install / no session | Delete app or clear Keychain session; launch | Splash → Get Started (auth), not Main tabs | Pass |
| Existing session restore | Complete auth once; force-quit; relaunch | Splash → Main tabs (Home) without re-OTP | Manual on device |
| Phone → OTP → terms → profile → welcome | Enter valid market phone → OTP (last 4) → accept terms → name → continue | Lands signed-in on Main tabs; session includes profile | Pass |
| Invalid OTP | Enter wrong 4 digits | Error shown; digits cleared; attempt limit enforced | Pass |
| Expired OTP | Wait past ~180s expiry; submit old code | Expired message; Resend issues fresh window | Pass |
| Resend OTP | Tap Resend after cooldown | New expiry window; can submit again | Pass |
| Backup OTP | Use backup path with `0000` | Accepts and advances flow | Pass |
| Sign out | Account → Sign out | Keychain cleared; trip draft reset; returns to Get Started | Pass |
| Apple / Google / Email continue | Tap Continue with Apple / Google / Email | Controls visible; **inert** (no network auth, no “demo” toast) | Pass |
| Auth localization | Switch EN / FR / LN / SW in prefs (or auth chrome) | Auth chrome strings localize; some downstream flow strings may stay EN | Pass |

---

## 2. Location & permissions

| Feature | How to test | Expected result | Status |
|---------|-------------|-----------------|--------|
| Location permission accepted | Grant When In Use on first prompt | Pickup defaults toward user coordinate; map/blue-dot when keyed | Manual on device |
| Location permission denied | Deny location | App remains usable; pickup via Adjust / saved / catalog; no crash | Manual on device |
| Location unavailable | Simulator without custom location / airplane GPS | Graceful unavailable / last-known path; booking still possible with selected places | Manual on device |
| Approximate location | iOS Precise Off (where available) | Coarse pickup still sets; Adjust Pickup available | Manual on device |
| Location changes | Move simulator/device during home / approach | Pickup / driver ETA UI updates from session location path | Manual on device |
| Permission explainers | Trigger location / mic / notifications when prompted | Contextual copy (not a silent dump of all permissions at once) | Pass |

---

## 3. Maps / Places / Routes

| Feature | How to test | Expected result | Status |
|---------|-------------|-----------------|--------|
| API key absent | Launch with no usable `VUUM_GOOGLE_MAPS_API_KEY` | Map placeholder / non-GMS surface; local catalog search; synthetic routes; full trip UI | Pass |
| API key present | Inject key per `docs/GOOGLE_MAPS_SETUP.md`; rebuild | `GMSServices` boots; map tiles render | Blocked on Maps key |
| Live map tiles + blue-dot | Home / trip with key + Location | Google Map tiles; user location when permitted | Blocked on Maps key |
| Places autocomplete (Google) | Type arbitrary address with key | Places API (New) suggestions | Blocked on Maps key |
| Places fallback (no key) | Type destination without key | Local Lubumbashi / Nairobi catalog / recents / saved | Pass |
| Places failure | Key present but Places API disabled / network error | Falls back to local catalog; resolve failure shows short error | Pass |
| Places session + debounce | Focus search, type quickly, dismiss | One session token; ~300 ms debounce; abandon on dismiss | Pass |
| Routes / Directions live polyline | Confirm ride with key + APIs enabled | Road-following polyline via Routes → Directions | Blocked on Maps key |
| Routes failure / no key | Confirm ride without key or with Routes failing | Synthetic polyline retained; ETAs still shown | Pass |
| Reverse geocode | Drop / adjust pickup pin | Google reverse geocode when keyed; else `CLGeocoder` | Pass (live Google: Blocked on Maps key) |
| Vehicle-class map markers | Idle nearby fleet + book bike / car / XXL | Markers use SF Symbol badges: `bicycle` / `car.fill` / `car.2.fill` by `MapPin.vehicleClass` | Pass (live tiles: Blocked on Maps key) |

---

## 4. Home

| Feature | How to test | Expected result | Status |
|---------|-------------|-----------------|--------|
| Home hub loads | Sign in → Home tab | Where to?, pickup, suggestions, schedule entry points | Pass |
| Where to? | Tap destination field | Destination / search sheet; select place → choose ride | Pass |
| Adjust pickup | Tap pickup / Adjust | AdjustPickupSheet; confirm updates draft pickup | Pass |
| Recents | Open destination; pick a recent | Sets dropoff → choose ride | Pass |
| Saved places | Account Saved Places or home shortcuts | Select Home/Work/custom → booking draft | Pass |
| Schedule entry | Now / Later on home or booking | Opens schedule / Reserve path | Pass |
| Suggestions / Services | Tap suggestion or Services tab | Product / services surfaces open | Pass |
| Home map realism | Visual check of map plane | Live tiles only with key; otherwise placeholder + chrome | Blocked on Maps key |

---

## 5. Booking

| Feature | How to test | Expected result | Status |
|---------|-------------|-----------------|--------|
| Pickup set | Location or Adjust Pickup | Draft pickup set; choose-ride enabled when dropoff set | Pass |
| Destination set | Search / recent / saved | Dropoff set → ride options | Pass |
| Multiple stops | Add stop on ride options | Intermediate stop on draft; change destination keeps stops | Pass |
| Vehicle tiers | Choose Bike / Car / XXL etc. | Fare + ETA by class; Confirm enabled when draft complete | Pass |
| Promo code | Enter `VUUM10` or `WELCOME` | Discount applied in breakdown | Pass |
| Invalid promo | Enter garbage code | Validation error; no discount | Pass |
| Payment method on confirm | PaymentMethodPickerRow | Shows selected method / company wallet when corporate on | Pass |
| Ride for someone else | Toggle For others; omit name/phone | Confirm disabled until name + phone present | Pass |
| Ride for someone else (complete) | Name + phone filled | Confirm allowed; trip tagged for passenger | Pass |
| Scheduled / Reserve | Later → future time → Reserve | Upcoming reservation listed; cancel from Activity | Pass |
| Confirm → searching | Confirm request | Phase → searching; matching UI | Pass |
| Cancel before match | Cancel while searching | Returns to idle / home; fee rules if in window | Pass |
| Surge display | Book in high-demand zone (live GPS or catalog pin) | Surge banner + multiplier on choose-ride; fare breakdown surge line; still correct after live route reprice | Pass (software; live Maps key optional) |
| Preview route on choose-ride | Open choose-ride | Synthetic path immediately; live path when keyed | Pass (live: Blocked on Maps key) |

---

## 6. Trip phases

| Feature | How to test | Expected result | Status |
|---------|-------------|-----------------|--------|
| Searching | Confirm a ride | Searching / matching UI; then matched beat | Pass |
| Assigned / matched | Wait through search simulation | Driver card, vehicle, ETA | Pass |
| Approaching / en route | Continue lifecycle | Driver approaching pickup; map path updates | Pass (map motion realism: Blocked on Maps key) |
| Arrived | Reach driver-arrived phase | Arrived state; boarding PIN panel when required | Pass |
| Boarding PIN / OTP | Preference require PIN on; confirm boarding | Correct PIN advances; wrong PIN blocked | Pass |
| In trip (active) | Confirm boarding | In-trip chrome; share / chat / safety available | Pass |
| In-trip destination change | Change destination sheet | Updates dropoff; **live route polyline + fare** via `RouteEngine` (synthetic first, then live); keeps stops | Pass (hardened: `destinationRouteGeneration`; see `InTripDestinationChangeTests`) |
| Completion | Finish trip simulation | Post-trip fare / rate / receipt path | Pass |
| Cancel mid-trip (policy) | CancelTripSheet from active phases | Fee vs free window per `CancellationPolicy` | Pass |
| Rebook from receipt | Activity → past trip → Rebook | Reopens choose-ride / draft for that route | Pass |

---

## 7. Chat & contact

| Feature | How to test | Expected result | Status |
|---------|-------------|-----------------|--------|
| Driver chat (active trip) | Open chat from active trip | Chat UI; scripted / local replies; messages persist in session | Pass |
| Chat when inactive | Open chat tools with no trip | Not falsely actionable / disabled appropriately | Pass |
| Call affordance | Tap call on driver card | System dialer / call intent for driver number when provided | Manual on device |
| Support chat | Account → Support → composer | Message listed under Your messages; scripted replies | Pass |

---

## 8. Safety

| Feature | How to test | Expected result | Status |
|---------|-------------|-----------------|--------|
| Safety toolkit | Open Safety from trip or Account | SOS, share, contacts, recording, incident entry points | Pass |
| SOS | Trigger SOS → confirm sheet | Local notify / confirmation state (no real safety backend) | Pass |
| Trip share | Share trip during active trip | Share sheet / link flow; inactive share not fake-enabled | Pass |
| Share by default preference | Enable in safety settings | Prompts rider; does not auto-SMS contacts | Pass |
| Trusted contacts | Account → Trusted contacts; add/edit | Contacts persist locally | Pass |
| Incident report | File incident from safety | Report captured locally | Pass |
| Recording permission | Start trip audio first time | Mic permission prompt with contextual copy | Manual on device |
| Recording start / stop | Start then stop on-device record | Recording phase updates; on-device only (no cloud retention) | Manual on device |

---

## 9. Payments

| Feature | How to test | Expected result | Status |
|---------|-------------|-----------------|--------|
| Wallet balances | Account → Wallet | Market balances visible | Pass |
| Add funds | Wallet → Add funds | Balance updates via on-device adapter | Pass |
| Payment methods list | Account → Payment methods | Card / MoMo / cash / wallet options | Pass |
| Link MoMo / add card | Select unlinked method | Link / add-card sheet before default | Pass |
| Set default method | Choose default | Syncs to `TripSession.paymentMethod` unless company wallet | Pass |
| Company wallet | Business profile → company wallet on | Ride pay shows company; default picker respects flag | Pass |
| Payment history | Account → Payment history / hub | Ledger rows with amount, method, status, receipt id | Pass |
| Live gateway settlement | Charge real MoMo / card network | Not in scope — local adapters only | Pass (presentation adapters; no live PSP) |

---

## 10. Activity (history & upcoming)

| Feature | How to test | Expected result | Status |
|---------|-------------|-----------------|--------|
| Past trips list | Activity tab | Completed trips with time / product filters | Pass |
| Receipt detail | Open past trip | Fare lines, payment method, help / share / rebook | Pass |
| Upcoming reservations | Activity → Upcoming | Scheduled rides listed | Pass |
| Cancel reservation | Cancel from upcoming | Removed / cancelled; returns to bookable state | Pass |
| Cancelled-trip filter | Look for dedicated cancelled filter | Not a first-class filter (known gap) | Pass (depth gap noted) |

---

## 11. Account

| Feature | How to test | Expected result | Status |
|---------|-------------|-----------------|--------|
| Account hub | Account tab | Profile, wallet, payments, safety, business, promos, referrals, settings, support, about, sign-out | Pass |
| Personal info edit | Edit name / email; relaunch | Persists via `SessionStore` | Manual on device |
| Settings / preferences | Language, market, accessibility, privacy | Prefs apply; delete-account privacy path present | Pass |
| Saved places CRUD | Add / edit / remove | Places available on home / booking | Pass |
| Notifications inbox | Open inbox | Local inbox surface | Pass |
| Communications | Toggle comms prefs | Prefs persist | Pass |
| Referrals | Refer friends → copy / share | Code + invite tracking UI; first-ride reward gate | Pass |
| Corporate / business | Business profile | Spend limits, cost centre, VIP / company wallet wiring | Pass |
| Field sales / eligibility | Referral / eligibility surfaces | Field-sales models + store lifecycle present | Pass |
| About / legal | Open About | Legal / about content | Pass |
| Hidden diagnostics | Secret entry to diagnostics | Developer tools; not in normal rider chrome | Pass |
| Localization prefs | Switch FR/EN/LN/SW | Core chrome updates; many flow strings still EN | Pass |

---

## 12. Products & services

| Feature | How to test | Expected result | Status |
|---------|-------------|-----------------|--------|
| Services hub | Services tab | Product entry points (courier, hourly, group, two-wheels, airport, eats browse, etc.) | Pass |
| Executive meet-and-greet | Business / Executive sheet → book | `startExecutiveMeetAndGreetBooking` path | Pass |
| Airport product | Airport sheet near airport zones | Zone-aware copy / booking entry | Pass |
| Courier / hourly / group / two-wheels | Open each product sheet | Forms / sheets open; booking hooks where wired | Pass |
| Eats browse | Open Eats list | Browse-only notice; no fake chevrons | Pass |

---

## 13. Zones & geo

| Feature | How to test | Expected result | Status |
|---------|-------------|-----------------|--------|
| Service zone catalog | Book inside Lubumbashi / Nairobi markets | Zone gating on Home / Services / choose-ride | Pass |
| Airport geofence | Pickup near Luano / JKIA / Wilson (catalog coords) | Airport product / zone messaging | Pass |
| Downtown / high-demand | Book in catalog high-demand cells | Surge / demand presentation when active; banner stays aligned after pickup adjust + live preview | Pass |
| Out-of-zone messaging | Force pickup outside service area if UI allows | Unavailable / out-of-zone status (not a silent book) | Pass |
| Live city boundary polygons | Drive arbitrary GPS across city edges | Full polygon / route-deviation depth still thin | Manual on device |

---

## 14. Offline & network

| Feature | How to test | Expected result | Status |
|---------|-------------|-----------------|--------|
| Offline banner | Enable Airplane Mode (or kill network) | `VuumOfflineBanner` on `ContentView` | Manual on device |
| Weak / flaky network | Throttle network in Instruments / Charles | Status UI does not crash; retries / local fallbacks | Manual on device |
| Reconnect | Restore network after offline | Banner clears; session continues | Manual on device |
| Offline booking draft | Lose network mid-draft | Local draft retained; live Places/Routes deferred until online | Manual on device |
| Offline Maps tiles | No network with key present | Cached tiles may show; otherwise degraded map — not a software defect | Blocked on Maps key |

---

## Summary counts (honest)

| Status | Approx. rows | Notes |
|--------|-------------:|-------|
| **Pass** | Majority | Auth, booking, trip SM, safety UI, payments adapters, activity, account, products, zones, synthetic maps |
| **Blocked on Maps key** | ~8–10 | Live tiles, blue-dot, Google Places, live road polylines, on-map driver motion realism |
| **Manual on device** | ~15 | Permissions, mic recording, Keychain relaunch, airplane mode, call dialer — fill evidence under §72 |

## Credential checkpoint (do not fake Pass)

Until `VUUM_GOOGLE_MAPS_API_KEY` is injected and Maps SDK / Places (New) / Routes (and/or Directions) are enabled for `com.vuum.app`:

1. Mark live map / Places / Routes rows **Blocked on Maps key**.
2. Still demo the full rider journey on synthetic maps (acceptable for presentation without claiming live Google tiles).
3. After key injection, re-run §3 and map-dependent rows in §4–§6 only — no architectural rewrite expected.

## Evidence trail

| Pass | Coverage |
|------|----------|
| QA Pass A | Auth → Home → Booking |
| QA Pass B | Trip phases, Maps wiring, Safety |
| QA Pass C | Account, payments, Activity, support, corporate, referrals |
| `ios/VuumTests/` | Fare / promo / phase / pickup ETA (§75) |

§72 physical device log remains a separate deliverable; this matrix is the §74 walkthrough artifact.
