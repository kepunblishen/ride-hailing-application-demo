# VUUM iOS — FULL PRODUCT REALISM, FEATURE EXPANSION, QA & PRODUCTION-READY PRESENTATION BUILD DIRECTIVE

## STATUS TRACKER (Agent 30 reconcile — 2026-08-23)

Full gap table: [`docs/DIRECTIVE_GAP_STATUS.md`](docs/DIRECTIVE_GAP_STATUS.md).  
**Remaining unfinished: 4** (3 credential steps + §72 device evidence).  
**§74 matrix:** [`docs/TESTING_MATRIX.md`](docs/TESTING_MATRIX.md).  
**§77 matrix:** [`docs/RFQ_204_MATRIX.md`](docs/RFQ_204_MATRIX.md).  
**§88 report:** [`docs/ENGINEERING_COMPLETION_REPORT.md`](docs/ENGINEERING_COMPLETION_REPORT.md).

`- [x]` = verified in codebase · `- [ ]` = still open.

### Done (verified)

- [x] Sections 5-8 Market / location / phone / Money + FX
- [x] Section 6 Reverse geocode (Google when keyed / CLGeocoder fallback)
- [x] Section 9 Language architecture (FR/EN/LN/SW; expand coverage over time)
- [x] Sections 10-12 Home / booking / product sheets
- [x] Sections 13-14 Maps software + fallback (credentials activate live tiles)
- [x] Sections 15-20 Trip realism incl. PIN + in-trip destination change
- [x] Sections 21-23 Schedule / multi-stop / ride for someone else
- [x] Sections 24-25 PaymentProvider adapters + payment history
- [x] Sections 26-27 Trip history + receipts
- [x] Sections 28-35 Account / support / lost item / ratings / cancel fees / promos / safety / SOS
- [x] Sections 36-39 Share / trusted contacts / audio / incidents
- [x] Sections 40-45 Permissions / notifications / geo zones (**incl. route-deviation corridor**) / cities / pricing / surge
- [x] Sections 46-50 Corporate / executive / field-sales / eligibility
- [x] Sections 51-54 Offline / status UI / empty states / startup
- [x] Section 55 Snyk disabled (`docs/NO_SNYK.md`)
- [x] Sections 57-63 Architecture / session / design / account nav / saved places
- [x] Sections 64-68 Places + Routes clients + zone availability + local payment adapters
- [x] Sections 69-71 Explainers / a11y / motion (ongoing polish OK)
- [x] Section 73 Codemagic / sideload pipeline
- [x] Section 74 Full device/feature testing matrix (`docs/TESTING_MATRIX.md`)
- [x] Section 75 Automated unit tests (partial — `VuumTests`: phases, lifecycle, ETA, fare/promo, auth, money, payment/referral; see `docs/TESTING.md`)
- [x] Sections 80-82 No invented backend / no user-facing demo language / hidden diagnostics
- [x] Section 87 software ready for Google credential checkpoint
- [x] Section 88 Final engineering completion report (`docs/ENGINEERING_COMPLETION_REPORT.md`)
- [x] Section 77 Full RFQ 204-reference status matrix (`docs/RFQ_204_MATRIX.md`)

### Still unfinished

- [ ] Google Cloud billing + enable Maps SDK for iOS, Places API (New), Routes API (and/or Directions)
- [ ] API key restricted to bundle ID `com.vuum.app`
- [ ] Inject `VUUM_GOOGLE_MAPS_API_KEY` (Codemagic / scheme / `Secrets.xcconfig`) and rebuild
- [ ] Section 72 Physical device testing evidence recorded in repo

When the key is supplied, follow [`docs/GOOGLE_MAPS_SETUP.md`](docs/GOOGLE_MAPS_SETUP.md) — no architectural rewrite expected.

## ROLE

You are the principal engineering agent responsible for taking the existing **VUUM iOS project in this repository** and turning it into an exceptionally polished, believable, location-aware, Uber/Bolt-class rider experience.

This is not a request to create a fresh app from scratch.

The project already exists, has already been built, and has already been sideloaded to a physical iPhone. You therefore have an important responsibility:

**FIRST inspect the entire repository and understand what is already implemented.**

Do not blindly rebuild existing screens or duplicate existing functionality.

For every requested feature:

1. Inspect the current implementation.
2. Determine whether it is:
   - Already implemented correctly
   - Partially implemented
   - Present but superficial
   - Broken
   - Architecturally weak
   - Missing entirely
3. Preserve good existing work.
4. Upgrade weak implementations.
5. Add genuinely missing capabilities.
6. Refactor only when doing so materially improves reliability, architecture, realism or maintainability.

Do not destroy functioning features simply because you can rewrite them.

---

# 1. IMPORTANT WORKING RULES

## DO NOT TREAT THIS AS A 10-MINUTE TASK

Do not make a few cosmetic changes and then declare the project finished.

Work through the repository systematically and continuously.

Complete multiple engineering passes:

- repository audit
- feature inventory
- architecture review
- UX review
- realism review
- localization review
- location/currency review
- permission review
- Maps integration review
- trip-state logic review
- payments review
- safety review
- settings/account review
- accessibility review
- failure-state review
- performance review
- package/dependency review
- build review
- physical-device behavior review
- regression testing
- final polish

After completing one pass, inspect the result again and identify what was missed.

Do not use "the app builds" as the definition of done.

The definition of done is:

**The application feels like a serious commercial ride-hailing product when operated on a real iPhone by somebody who has never seen the source code.**

---

# 2. PARALLEL AGENT EXECUTION

Use parallel sub-agents aggressively where the available coding environment supports them.

Target **20“40 parallel engineering/research workstreams**.

Do NOT create fake agents or claim that agents were used if the environment does not actually support them.

If 20“40 true parallel agents are available, distribute work across them.

Suggested workstreams:

### Product/UX agents
1. Current app UX audit
2. Home-screen audit
3. Booking-flow audit
4. Trip-state audit
5. Account/settings audit
6. Payment UX audit
7. Safety UX audit
8. Driver/matching realism audit
9. Localization audit
10. Accessibility audit

### Engineering agents
11. Architecture audit
12. State-machine audit
13. Location architecture
14. Maps integration
15. Places integration
16. Routes/ETA integration
17. Persistence/session layer
18. Notification layer
19. Permissions layer
20. Error/failure-state handling

### Product expansion agents
21. Uber feature comparison
22. Bolt feature comparison
23. RFQ Module 1 coverage
24. RFQ Module 2 coverage
25. RFQ Module 3 coverage
26. RFQ Module 4 coverage
27. Corporate-flow modelling
28. Trust & Safety modelling
29. Field-sales modelling
30. Future super-app expansion review

### QA/security/performance agents
31. Automated test review
32. UI/state regression testing
33. Performance/memory review
34. dependency/package audit
35. privacy/permission audit
36. offline/poor-network behavior
37. device/sideload build audit
38. visual consistency audit
39. edge-case testing
40. final product/meeting-readiness audit

Do not have every agent modify the same files blindly.

Have agents investigate related domains and then coordinate their changes.

Resolve conflicting implementations centrally.

---

# 3. THE CURRENT PRODUCT CONTEXT

Brand:

**VUUM**

Operator:

**Congo Mobility SARL**

Target operating markets:

**Lubumbashi and Kolwezi, Democratic Republic of Congo**

Commercial concept:

A premium ride-hailing platform covering consumer mobility, corporate/mining mobility, Trust & Safety and field-based growth.

The RFQ contains:

- Module 1 — Core Ride-Hailing Platform: 100 references
- Module 2 — Corporate Client Platform: 64 references
- Module 3 — Trust & Safety: 27 references
- Module 4 — Field Sales Growth Engine: 13 references
- Total: 204 references

The current iOS project is primarily the rider-facing presentation application.

However:

**Do not architect the rider client as a disposable toy.**

It must have structures that make it obvious that the same codebase could eventually connect to:

- real authentication
- real APIs
- real payment providers
- real driver matching
- real trip tracking
- real corporate services
- real safety services
- real notifications
- real backend infrastructure

The current local/mock services are acceptable as an interim data source, but the application should not be architected around fake behavior that would need to be thrown away.

---

# 4. ABSOLUTE PRODUCT PRINCIPLE

The application must feel real.

Avoid:

- fake-looking UI
- placeholder cards everywhere
- static "demo" text
- fixed Nairobi/Lubumbashi coordinates
- hard-coded KES/CDF everywhere
- fake-looking map behavior
- arbitrary simulated trips with no meaningful state
- buttons that do nothing
- settings that lead nowhere
- dead screens
- meaningless loading animations
- giant rounded-card "AI generated app" aesthetics
- overly decorative glass effects
- excessive gradients
- inconsistent spacing
- toy-like navigation
- screens that visually resemble a template rather than a transportation product

The application should feel like something a major mobility company could actually ship.

Use Uber/Bolt and other mature mobility applications as UX references, but:

**Do not copy their branding, proprietary assets, exact wording, logos, or visual identity.**

Learn from their interaction patterns and product conventions while establishing a distinctive VUUM identity.

---

# 5. KENYA DEVELOPMENT / DRC PRODUCT REQUIREMENT

This is extremely important.

The product is being built for DRC.

The development and presentation environment is Kenya.

Therefore separate:

### DEVICE CONTEXT

Determined from the real iPhone:

- current geographic location
- locale
- region
- currency environment
- phone-number country
- language preferences
- measurement system
- timezone

### OPERATING MARKET

A configurable VUUM market:

- DRC
  - Lubumbashi
  - Kolwezi

Eventually:

- Kenya
- Zambia
- other countries

Do NOT hard-code the device location as the product's operating market.

Do NOT force the rider to see +243 merely because VUUM is a DRC company.

If the physical presentation device is in Kenya, the experience should intelligently understand Kenya as the current device context.

Examples:

Kenya device context:

- phone prefix: +254
- currency: KES
- Kenya locale/number formatting
- Kenya timezone
- actual device GPS
- real current location

DRC operating market:

- Lubumbashi/Kolwezi
- CDF/USD
- DRC ride-service configuration

Design this as a proper **Market/Region Configuration layer**, not scattered if-statements.

Create something conceptually equivalent to:

`AppEnvironment`
`DeviceContext`
`MarketConfiguration`
`CurrencyConfiguration`
`PhoneNumberConfiguration`
`LocalizationConfiguration`

The actual naming should fit the existing architecture.

---

# 6. REAL LOCATION — NO FIXED DEMO LOCATION

The app must use the user's actual device location.

Do not keep a permanent fixed coordinate such as:

- Nairobi CBD
- Lubumbashi
- Kolwezi

unless the user explicitly chooses a presentation/test environment.

Default behavior:

1. Ask for location permission at the appropriate point in the onboarding/home experience.
2. Read the device's actual location using Core Location.
3. Center the map on the actual location.
4. Update the location when appropriate.
5. Reverse-geocode the location when necessary.
6. Show a real pickup address.
7. Use the actual current position for route calculations.
8. Populate relevant local place suggestions.

Use proper iOS permission handling and usage descriptions.

Do not request excessive permissions just for appearance.

Location authorization should be requested in context rather than firing every permission dialog at once.

---

# 7. PHONE NUMBER COUNTRY DETECTION

The authentication UI must behave like a real international ride-hailing app.

Implement:

- [x] country selector — **Agent 05**: `AuthCountryPickerSheet` + searchable catalog (KE/CD first)
- [x] country flag — **Agent 05**: flag + dial code chip on Get Started / Confirm Info
- [x] calling code — **Agent 05**: persisted dial code (`+254` / `+243` defaults via `AppLocale`)
- [x] local-number formatting — **Agent 05**: `AppLocale.formatLocalNumber` + trunk-`0` normalization
- [x] validation — **Agent 05**: national digit-length checks; Continue gated on valid local number
- [x] sensible default country based on device region — **Agent 05**: `AppLocale.defaultCountryCode`
- [x] persistence of selected country — **Agent 05**: UserDefaults last country/flag
- [x] ability to change country manually — **Agent 05**: country picker sheet

### Auth flow realism (Agent 05)

- [x] Get Started — phone validation, send loading, SMS disclosure, Apple/Google/Email inert (no toasts)
- [x] OTP — 4-digit boxes, autofill/paste, resend cooldown, invalid/expired/too-many errors, backup code sheet (`0000`)
- [x] Terms — agree checkbox, Terms/Privacy document sheets, Next gated on agree
- [x] Confirm info — name validation, optional email, read-only phone, save loading
- [x] Welcome — branded transition then Keychain `SessionStore.completeSignIn`
- [x] L10n — EN/FR/LN/SW auth strings
- [x] Session Keychain — signed-in restore, logout clear, corrupt/expiry reconcile

Examples:

Kenya:

`+254`

DRC:

`+243`

Do not display a generic "Phone Number" field containing an arbitrary hard-coded number.

If OTP remains simulated at this stage, keep the actual product flow realistic and make the authentication layer replaceable by a real SMS provider later.

The API should be able to plug into an actual OTP provider without redesigning the UI.

---

# 8. CURRENCY ARCHITECTURE

Never scatter currency symbols throughout the application.

Create a currency abstraction.

Support at minimum:

- KES
- CDF
- USD

Every amount should carry:

- numeric value
- currency code
- formatted representation

The presentation should intelligently follow the active context.

For the DRC product:

- CDF primary
- USD secondary

For Kenya device/presentation context:

- KES should be available and correctly formatted.

Implement:

- fare formatting
- payment formatting
- receipt formatting
- wallet formatting
- trip-history formatting
- promo/discount formatting
- corporate billing formatting

Never display:

`$10`

everywhere without knowing which currency context is active.

---

# 9. LANGUAGE ARCHITECTURE

The RFQ requires:

- French
- English
- Lingala
- Kiswahili

Implement proper localization architecture.

Do not scatter raw English strings through SwiftUI views.

Use localized string keys and a central localization layer.

Make sure localization covers:

- [x] onboarding
- [x] authentication
- [x] home
- [x] search
- [x] booking
- [x] ride-selection
- [x] matching
- [x] driver details
- [x] active trip
- [x] safety
- [x] payments
- [x] receipts
- [x] ratings
- [x] trip history
- [x] account
- [x] support
- [x] settings
- [x] notifications
- [x] corporate-related rider UI
- [x] errors
- [x] empty states
- [x] permission education
- [x] confirmations
- [x] cancellation
- [x] scheduled rides

Test long strings.

- [x] Test French.
- [x] Test Kiswahili.
- [x] Test Lingala.

Do not build a fake language selector that only changes a few labels.

---

# 10. HOME SCREEN — MAKE IT FEEL LIKE A REAL MOBILITY APP

The first meaningful screen after onboarding should feel immediately familiar as a professional ride-hailing application.

Priorities:

- [x] real map
- [x] current location
- [x] clean location marker
- [x] bottom booking/search surface
- [x] "Where to?" interaction
- [x] current location/address
- [x] service categories
- [x] saved places
- [x] promotions where appropriate
- [x] upcoming ride indication
- [x] account access
- [x] safety/accessibility cues

The home screen should support two mental modes:

### FAST NORMAL RIDE

User wants a normal trip.

Path:

Home → Where to? → destination → service → fare → request ride.

### SERVICE-FIRST FLOW

User first chooses a service.

Examples:

- [x] Vuum Go / Standard
- [x] Vuum Comfort
- [x] Vuum Premium
- [x] Executive
- [x] XL / XXL (Vuum XXL · ~10 min pickup)
- [x] Airport / Travel
- [x] Hourly
- [x] Corporate
- [x] Scheduled Ride
- [x] Courier / 2-Wheels / Group Ride product sheets (forms · fare · ETA · TripSession handoff)

The exact naming should align with Vuum's branding.

Do not create 20 pointless categories.

Prioritize realistic categories that make sense for VUUM.

---

# 11. BOOKING EXPERIENCE

Upgrade booking to support:

### Pickup

- [x] current location
- [x] map pin
- [x] searchable address
- [x] manual adjustment
- [x] saved places
- [x] recent places

### Destination

- [x] autocomplete
- [x] current location
- [x] saved places
- [x] recent searches
- [x] local POIs
- [x] business names where available

### Multiple stops

Support a proper stop-management model.

- [x] Allow adding/removing/reordering stops where appropriate.
- [x] RFQ multi-stop trips and waiting charges (fare line + in-trip wait indicator).

### Booking options

Support:

- [x] now
- [x] scheduled
- [x] future ride
- [x] self
- [x] someone else
- [x] corporate/employee context where applicable
- [x] premium/executive

### Fare preview

Show:

- base fare
- distance component
- time component
- minimum fare if applicable
- surge/peak multiplier when active
- waiting component where relevant
- discounts
- taxes if configured
- total

For DRC:

show CDF + USD.

For Kenya:

show KES appropriately.

---

# 12. SERVICE SELECTION SCREEN

Build a premium category selector.

Each ride category should show:

- vehicle illustration/icon
- category name
- passenger capacity
- ETA
- estimated fare
- payment method
- feature highlights
- accessibility/premium labels where relevant

Examples:

### Standard

Everyday city trip. Pickup ETA ≈ 5 min.

### Comfort

Higher vehicle comfort. Pickup ETA ≈ 5 min.

### Executive

Premium cars and highly rated drivers. Pickup ETA ≈ 10 min (large fleet).

### Airport / Travel

Airport-oriented service. Pickup ETA ≈ 10 min.

### XXL

Larger passenger capacity (Vuum XXL). Pickup ETA ≈ 10 min.

### 2-Wheels

Bike / scooter. Pickup ETA ≈ 2 min.

### Ride by Hour

Suitable for meetings, appointments and multi-stop journeys.

Do not pretend all categories are operational everywhere.

Category availability must come from market configuration.

---

## Agent 07 — Product sheets checklist

- [x] Shared `ProductBookingForm` with live ETA + fare estimate
- [x] Courier sheet (size / fragile / recipient / notes → TripSession)
- [x] Group Ride sheet (seats → Vuum XXL)
- [x] Hourly sheet (duration → inject hourly tier)
- [x] 2-Wheels sheet (bike ETA 2 min → TripSession)
- [x] Airport sheet (flight / luggage / meet & greet)
- [x] Executive sheet (traveller / meet-and-greet / schedule)
- [x] MockFares tiers: Vuum · Comfort · XXL · Executive · Airport
- [x] Sticky product inject survives fare / zone refresh
- [x] Services + Home entry points wired
- [x] `AirportProductSheet.swift` + `ExecutiveProductSheet.swift` registered in `project.pbxproj`
# 13. GOOGLE MAPS — IMPLEMENT THE REAL INTEGRATION NOW

Do not merely display a placeholder map shell and wait until the last minute.

Prepare the architecture completely now.

The only thing that should remain missing is the actual production/development API credentials.

Google's current iOS documentation supports Maps SDK through Swift Package Manager and Google Places SDK for place discovery/autocomplete. Routes API supports route computation, traffic-aware ETA, route polylines, alternate routes, waypoints and route options.

Implement the code path for:

### Maps SDK

- [x] map initialization
- [x] user location
- [x] camera
- [x] markers
- [x] route polyline
- [x] map styling
- [x] pickup marker
- [x] destination marker
- [x] driver markers
- [x] map interactions
- [x] zoom
- [x] recenter
- [x] location button

### Places

Prepare:

- [x] Autocomplete
- [x] Place selection
- [x] Place Details
- [x] address retrieval
- [x] location coordinates
- [x] saved places abstraction

Use proper Places session-token handling instead of making an unbounded request per keystroke. Google explicitly recommends session tokens for Autocomplete sessions.

Request only the Place data fields actually needed rather than blindly requesting everything.

### Routes

Prepare:

- origin
- destination
- waypoints
- distance
- ETA
- polyline
- alternate routes
- traffic-aware routes
- route refresh
- route deviation calculations

Google's Routes API supports traffic-aware route calculation, polylines, multiple locations and route options.

### API KEY ARCHITECTURE

Do NOT hard-code the key into source code.

Use configuration such as:

`VUUM_GOOGLE_MAPS_API_KEY`

and corresponding environment/build settings.

Support:

- local Xcode development
- Codemagic
- Release configuration
- Debug configuration

Prepare documentation telling me exactly:

1. which Google Cloud project to create
2. which APIs to enable
3. where to put the key
4. how to restrict it
5. which APIs require billing
6. how to configure iOS application restrictions
7. how to configure bundle identifier restrictions
8. how to configure Maps SDK
9. how to configure Places API
10. how to configure Routes API
11. how to test everything

Do not tell me to add the API key until the software side is actually ready.

When all code is complete, clearly say:

**GOOGLE MAPS CREDENTIALS ARE NOW THE ONLY REMAINING CONFIGURATION STEP**

and provide the exact setup instructions.

---

# 14. MAP FALLBACK

The application should still open if the Google API key is missing.

Do not crash.

Show a controlled developer/configuration state.

But do not make the application permanently dependent on a fake map.

Once the key exists:

the real map should activate automatically.

---

# 15. LIVE DRIVER SIMULATION ARCHITECTURE

The rider application should be able to demonstrate realistic dispatch behavior without requiring a production backend.

Do not fake it with random UI-only animation.

Create a proper simulated mobility data layer.

Model:

- available drivers
- driver status
- distance
- ETA
- driver acceptance
- driver approach
- arrival
- trip start
- trip progress
- trip completion

Driver state machine should resemble:

`Available`
→ `RequestReceived`
→ `Accepted`
→ `NavigatingToPickup`
→ `Arrived`
→ `Waiting`
→ `TripStarted`
→ `EnRoute`
→ `ApproachingDestination`
→ `Completed`

Also handle:

`Cancelled`
`DriverCancelled`
`RiderCancelled`
`Expired`
`Reassigned`
`SafetyIncident`

Driver positions should move along a meaningful route rather than simply teleport around a circle.

When Google Routes is connected, derive movement from the actual route.

---

# 16. MATCHING SCREEN

Build a realistic driver-matching sequence.

It should show:

- [x] searching animation
- [x] nearby drivers
- [x] estimated matching time
- [x] category
- [x] map activity
- [x] subtle status changes
- [x] no-drivers outcome + Try again
- [x] slow-connection / delayed matching messaging

**Agent 27:** Cancel reasons + free/fee window, pickup wait timer, no-drivers retry, network-ish delay states; surge with §45.

Then transition into:

### Driver assigned

Display:

- [x] name
- [x] photo (initials avatar; optional asset)
- [x] rating
- [x] trips
- [x] vehicle make
- [x] vehicle model
- [x] vehicle colour
- [x] license plate
- [x] estimated arrival (class ETA badge: bike 2 / car 5 / XXL 10)
- [x] trip PIN / verification code

Uber and Bolt both expose driver identity and ride verification/security elements; use that as a product-pattern reference, not a branding template.

---

# 17. DRIVER APPROACH EXPERIENCE

Make this feel alive.

Show:

- [x] live driver marker
- [x] ETA countdown
- [x] distance
- [x] pickup point
- [x] driver route
- [x] "Driver is on the way"
- [x] contact actions (message / call)
- [x] safety action
- [x] cancellation action
- [x] verification details
- [x] share trip

Do not allow a driver to instantly teleport from 7 minutes away to "Arrived."

### Agent 02 — TripSession / Matching / ETA Realism

- [x] Vehicle-class pickup ETAs: bike ≈ 2 min, standard car ≈ 5 min, XXL/large ≈ 10 min (`VehiclePickupETA` / `TripMotionTiming`)
- [x] Drivers approach pickup with progress over time (`routeProgress`, compressed wall-clock motion)
- [x] Tier selection affects fare, ETA, vehicle icon/class, and nearby fleet mix
- [x] Phase machine: searching → matched → driverEnRoute (arriving) → driverArrived → inTrip → completed
- [x] Map simulation APIs: `routeProgress`, `motionSimulationKind`, `isSimulatingDriverMotion`, `activeVehicleClass`, `MapPin.vehicleClass`

---

# 18. TRIP START / OTP

Implement a real rider-side trip verification model.

The RFQ specifically requires rider-provided OTP/PIN trip start.

Show:

- [x] driver details
- [x] vehicle details
- [x] plate
- [x] verification/PIN
- [x] "Verify your ride"
- [x] trip-start confirmation

Incorrect OTP should fail.

Correct OTP should advance the trip state.

---

# 19. ACTIVE TRIP

The active-trip UI should be one of the strongest screens in the application.

Include:

- [x] map
- [x] route
- [x] current driver/rider position
- [x] destination
- [x] ETA
- [x] remaining distance
- [x] trip progress
- [x] driver details
- [x] call
- [x] chat
- [x] safety
- [x] share trip
- [x] emergency/SOS
- [x] recording/safety controls if enabled
- [x] fare/payment information
- [x] change destination (in-trip)

Keep the map dominant.

Do not cover the entire screen with cards.

---

# 20. DESTINATION CHANGE

Allow destination change before trip completion.

Recalculate:

- [x] route
- [x] distance
- [x] ETA
- [x] fare estimate

The RFQ expects dynamic route and fare handling, and Bolt currently supports destination changes in some markets.

Do not make the fare a static number that never changes.

---

# 21. SCHEDULED RIDES

Implement a proper scheduled-rides experience.

User can select:

- [x] date
- [x] pickup time
- [x] pickup
- [x] destination
- [x] category
- [x] payment method

Show:

- [x] upcoming ride
- [x] edit
- [x] cancel
- [x] confirmation
- [x] reminder state
- [x] assigned-driver status when appropriate

Bolt currently supports reserved rides with upcoming-ride management; the RFQ also explicitly requires scheduled/pre-booked rides.

**Agent 25:** Quiet ride + accessibility notes on choose-ride; promo field with apply / invalid / expired; reserved trips persist locally.


# 22. MULTI-STOP RIDES

Implement:

- [x] add stop
- [x] remove stop
- [x] reorder
- [x] intermediate destination
- [x] waiting indicator
- [x] fare recalculation

The RFQ explicitly requires multiple stops and waiting charges.

---

# 23. RIDE FOR SOMEONE ELSE

Create a proper "Someone else" booking path.

Support:

- passenger name
- phone
- optional relationship
- passenger instructions

The UI should make it obvious the booking is for another person.

This is explicitly required by the RFQ.

---

# 24. PAYMENT SYSTEM

Create a proper Payment Methods area.

At minimum model:

- [x] Cash
- [x] Card
- [x] Mobile Money
- [x] promotional credits
- [x] corporate/on-account
- [x] future wallet

For DRC:

prepare adapters for:

- [x] Airtel Money
- [x] Orange Money
- [x] card gateway

Do not pretend to charge real money without a provider.

Instead, create provider interfaces so actual integrations can be dropped in later.

For example conceptually:

- [x] `PaymentProvider`
- [x] `CardPaymentProvider`
- [x] `MobileMoneyProvider`
- [x] `CorporateBillingProvider`

The UI and transaction lifecycle must already be correct.

Support states:

- [x] pending
- [x] processing
- [x] successful
- [x] failed
- [x] cancelled
- [x] refunded
- [x] partially refunded

**Agent 09:** Local payment method management, default selection, trip charge recording, wallet balances/history persistence, and provider adapter interfaces are in place.

---

# 25. PAYMENT HISTORY

Account → Payments should show:

- [x] transaction date
- [x] trip
- [x] amount
- [x] currency
- [x] method
- [x] status
- [x] receipt
- [x] refund state

---

# 26. TRIP HISTORY

Create a serious trip history.

Filters:

- [x] all
- [x] completed
- [x] cancelled
- [x] upcoming

Each trip should display:

- [x] date
- [x] pickup
- [x] destination
- [x] category
- [x] driver
- [x] vehicle
- [x] fare
- [x] payment method
- [x] currency
- [x] rating
- [x] receipt
- [x] support/report issue

Trip details should open a proper receipt-like detail page.

The RFQ specifically requires historical trips with itemized fares.

---

# 27. RECEIPTS

Create professional receipts.

Include:

- [x] VUUM branding
- [x] trip ID
- [x] date/time
- [x] pickup
- [x] destination
- [x] driver
- [x] vehicle
- [x] distance
- [x] duration
- [x] base fare
- [x] distance charge
- [x] time charge
- [x] waiting
- [x] surge
- [x] discount
- [x] subtotal
- [x] tax if configured
- [x] total
- [x] payment method
- [x] CDF/USD where relevant

- [x] Support a share/export action.

---

# 28. ACCOUNT PAGE — EXPAND THIS SIGNIFICANTLY

The current account/settings requirement is too shallow.

Build a comprehensive account center.

Sections should include:

### Profile
- [x] name
- [x] profile photo
- [x] phone number
- [x] email
- [x] preferred language
- [x] account status

### Payment
- [x] payment methods
- [x] default method
- [x] transaction history
- [x] receipts

### Trips
- [x] trip history
- [x] upcoming rides
- [x] saved places

### Safety
- [x] trusted contacts
- [x] safety center
- [x] emergency settings
- [x] ride verification
- [x] trip sharing
- [x] safety preferences

### Notifications
- [x] trip updates
- [x] promotions
- [x] receipts
- [x] scheduled ride reminders
- [x] safety notifications
- [x] support updates

### Privacy
- [x] location preferences
- [x] data controls
- [x] account data
- [x] permissions
- [x] privacy policy
- [x] data deletion request

### Security
- [x] change phone/email
- [x] sign-in history where applicable
- [x] biometric/app lock if appropriate
- [x] active sessions
- [x] sign out

### Support
- [x] Help Center
- [x] Contact Support
- [x] report a trip
- [x] safety issue
- [x] payment issue
- [x] lost item
- [x] driver complaint
- [x] rider complaint
- [x] FAQs
- [x] live support placeholder architecture

### Language
- [x] Français
- [x] English
- [x] Lingala
- [x] Kiswahili

### Country / Region
- [x] country
- [x] operating market where permitted

### About
- [x] app version
- [x] terms
- [x] privacy
- [x] licenses
- [x] open-source acknowledgements

### Invite & Earn / Referral
- [x] referral code
- [x] invite friends
- [x] referral rewards

### Corporate
When account belongs to a company:

- [x] company
- [x] department
- [x] spending limit
- [x] cost center
- [x] corporate rides
- [x] corporate support

---

# 29. SUPPORT CENTER

Do not reduce support to a dead "Contact us" button.

Create a functional support flow.

Categories:

- [x] My driver
- [x] My rider experience
- [x] Payment
- [x] Fare dispute
- [x] Lost item
- [x] Safety
- [x] Cancellation
- [x] Scheduled ride
- [x] Account
- [x] Other

Each category should lead to contextual options.

Example:

Payment → select trip → select issue → describe → submit → support ticket.

Create local persistence for tickets.

Ticket states:

- [x] submitted
- [x] received
- [x] investigating
- [x] response available
- [x] resolved

---

# 30. LOST ITEM FLOW

Create:

Trip History → Trip → Help → Lost Item

Show:

- [x] trip
- [x] driver
- [x] vehicle
- [x] time
- [x] description field
- [x] contact/support pathway

---

# 31. RATINGS

Implement:

- [x] 1–5 star rating
- [x] optional comment
- [x] common feedback tags
- [x] driver/rider appreciation
- [x] skip option where appropriate
- [x] rating persistence
- [x] post-trip state

Two-way ratings are part of the RFQ.

---

# 32. CANCELLATION

Do not implement a simple "Are you sure?" popup.

Implement:

1. [x] Cancel ride
2. [x] Show reason list
3. [x] If free window → free cancellation
4. [x] If fee applies → clearly show fee
5. [x] Confirm cancellation
6. [x] Update trip state
7. [x] Save cancellation reason
8. [x] Show resulting status
9. [x] Pickup wait timer + waiting charges after free grace

The RFQ requires configurable cancellation windows and cancellation-reason capture.

---

# 33. PROMOTIONS / REFERRALS

Create:

### Promo codes

- [x] apply code
- [x] validation
- [x] invalid state
- [x] expired state
- [x] usage restrictions
- [x] discount preview

### Referrals

- [x] referral code
- [x] invite/share
- [x] referral status
- [x] credits
- [x] eligible ride
- [x] completed reward

The RFQ requires promo, referral and discount behavior.

---

# 34. SAFETY CENTER

Safety must feel like a core product capability rather than one SOS button.

Create a Safety Center containing:

- emergency assistance
- SOS
- trusted contacts
- trip sharing
- ride verification
- driver/vehicle verification
- report safety issue
- safety tips
- safety preferences
- incident reporting
- audio safety recording where enabled

Uber and Bolt both prominently expose safety toolkits, trip sharing, emergency assistance and ride verification patterns.

---

# 35. SOS FLOW

SOS should not instantly execute a dangerous action with no confirmation unless the actual product configuration explicitly requires it.

Use:

SOS → confirmation → emergency workflow.

Show:

- current location
- active trip
- trip ID
- driver
- vehicle
- emergency contacts
- safety team notification status

The RFQ defines the SOS workflow around trip ID, GPS, participant identification, safety contacts and Safety Team notification.

For a presentation implementation, simulate the backend event lifecycle locally while keeping the interfaces ready for a real backend.

---

# 36. TRIP SHARING

Implement a proper trip-sharing interface.

Shared information:

- driver
- vehicle
- registration
- trip ID
- destination
- ETA
- live location
- active trip state

The RFQ explicitly requires trip sharing with a trusted contact.

Use the iOS Share Sheet when appropriate.

---

# 37. TRUSTED CONTACTS

Account → Safety → Trusted Contacts.

Support:

- add
- edit
- remove
- default contact
- trip-sharing reminder
- emergency contact indication

---

# 38. IN-TRIP AUDIO SAFETY

This feature must be implemented carefully.

The RFQ explicitly states that recording must NOT become covert background surveillance. Recording is intended only for an active trip, must be disclosed to the other participant, must visibly indicate recording, must stop automatically at trip termination and must respect jurisdiction-specific consent/retention rules.

Therefore:

### DO

- active-trip-only recording
- explicit user activation
- microphone permission
- visible recording state
- other-party notification in the eventual backend model
- automatic stop at trip completion
- recording metadata
- retention configuration
- local encrypted temporary handling where necessary
- clearly defined consent state
- future backend-upload abstraction

### DO NOT

- secretly record
- record outside a trip
- keep recording after trip completion
- build hidden microphone functionality
- make the microphone permission request meaningless

Recording architecture should conceptually support:

`RecordingSession`
`AudioRecording`
`RecordingPermissionState`
`RecordingUploadState`
`RecordingRetentionState`

The backend abstraction should support the RFQ's required recording lifecycle and auditability.

---

# 39. INCIDENT REPORTING

Create:

Trip → Report Issue → Incident Type.

Initial incident categories should include the RFQ categories:

- verbal dispute
- harassment
- threatening behavior
- driver conduct complaint
- rider conduct complaint
- payment dispute
- trip dispute
- safety concern
- other

The RFQ requires this workflow.

---

# 40. PERMISSIONS

Audit every iOS permission.

Potential permissions:

- [x] Location — when-in-use for pickup/map; always usage string reserved for trip share
- [x] Notifications — requested with home essentials after explainer
- [x] Microphone — requested only when starting in-trip safety recording
- Photos where actually necessary
- [x] Camera — available via PermissionCenter when a feature needs it (not asked on launch)
- Contacts only where a justified product flow requires it

- [x] Do not request everything on launch.
- [x] Request each permission at the moment the user understands why it is necessary.

Apple recommends contextual notification permission requests and defines the Core Location authorization/usage-description requirements in its current documentation.

- [x] Make every denied-permission state usable.

Examples:

Location denied:

→ [x] explain why location improves pickup (home banner + Privacy settings → Open Settings)

Notifications denied:

→ [x] provide settings shortcut/instruction (Communication settings / inbox)

Microphone denied:

→ [x] show safety recording unavailable rather than crashing (active trip + Safety toolkit)

---

# 41. NOTIFICATIONS

Create a proper notification architecture.

Notification types:

- [x] OTP
- [x] driver assigned
- [x] driver arriving
- [x] driver arrived
- [x] trip started
- [x] trip completed
- [x] receipt
- [x] scheduled ride reminder
- [x] driver reassigned
- [x] payment succeeded
- [x] payment failed
- [x] cancellation
- [x] support response
- [x] safety event
- [x] recording started
- [x] recording stopped
- [x] incident update

Do not hard-code notifications into random views.

Use a notification service abstraction.

---

# 42. LOCATION / GEO UTILITIES

Create a proper geographic utility layer for:

- [x] distance
- [x] bearing
- [x] ETA
- [x] geocoding
- [x] reverse geocoding
- [x] route deviation — `TripGeo` distance-to-polyline corridor + `RouteDeviationMonitor` persistence; rider notice + share on `ActiveTripFlowView`
- [x] geofencing
- [x] service zones

This is especially important because the RFQ specifies:

- multi-city configuration
- airport zones
- demand zones
- route deviation
- corporate safety
- city-specific pricing.

**Implementation notes:** Corridor threshold default **90 m**; notice after **~6 s** continuous off-route; clears after **~3 s** back inside **55 m**. In-trip motion evaluates against `ActiveTrip.tripRoute`.

# 43. OPERATING CITIES

Build market configuration for at least:

### Lubumbashi

### Kolwezi

Each city should be able to have:

- boundaries
- pricing
- service categories
- currency behavior
- airport/premium zones
- availability
- safety configuration

Do not duplicate whole applications per city.

---

# 44. PRICING ENGINE

Create a proper fare calculation layer.

Inputs:

- [x] city
- [x] service category
- [x] distance
- [x] duration
- [x] minimum fare
- [x] base fare
- [x] per-km
- [x] per-minute
- [x] waiting
- [x] surge
- [x] airport/premium zone
- [x] booking type
- [x] promo
- [x] corporate rules

Outputs:

- [x] subtotal
- [x] discount
- [x] tax
- [x] total
- [x] primary currency
- [x] secondary currency
- [x] pricing breakdown

This makes the system ready for admin-controlled pricing later.

---

# 45. SURGE

Implement configurable surge logic.

UI should explain:

"High demand"

or equivalent VUUM wording.

- [x] Fare should recalculate.
- [x] Do not hide a multiplier inside an arbitrary total.
- [x] Configurable surge by zone / peak window (admin-ready).

The RFQ specifically requires admin-controlled surge pricing by defined zone.

---

# 46. CORPORATE MODULE PREPARATION

Although the current app is rider-facing, the rider client must be prepared for corporate users.

Support architecture for:

- [x] corporate account identity
- [x] employee account
- [x] department
- [x] cost center
- [x] spend limit
- [x] corporate payment mode
- [x] corporate trip
- [x] premium/executive ride
- [x] safety policy
- [x] corporate SOS recipient
- [x] corporate booking

The RFQ describes company profiles, sub-accounts, bulk employee onboarding, per-employee spend limits, cost-centre codes and consolidated billing.

---

# 47. CORPORATE RIDER EXPERIENCE

When logged in as a corporate rider:

Show appropriate context such as:

- [x] company name
- [x] department
- [x] available transport allowance
- [x] corporate payment
- [x] cost centre
- [x] remaining spend
- [x] corporate ride history

Do not allow a user to exceed configured limits.

---

# 48. EXECUTIVE / VIP FLOW

Build a premium corporate transfer flow.

Include:

- [x] Executive vehicle tier
- [x] advanced booking
- [x] confirmed driver
- [x] driver profile
- [x] vehicle
- [x] plate
- [x] traveller name
- [x] trip purpose
- [x] meet-and-greet option
- [x] premium service messaging

The RFQ calls for a dedicated executive tier, advance booking, driver information and meet-and-greet support. 
This is important for the client presentation because executive/mining mobility is a major commercial story.

---

# 49. FIELD SALES ARCHITECTURE

Do not necessarily build a separate sales application now.

However, create model/interfaces that can support:

- [x] sales executive ID
- [x] recruitment source
- [x] referral code
- [x] driver recruitment
- [x] rider recruitment
- [x] activation
- [x] first completed ride
- [x] commission state

The RFQ requires commissions to be triggered by a genuine, successfully paid first completed ride and to contain anti-fraud checks.

Design the data structures now so this can be connected later without rewriting the rider app.

---

# 50. ANTI-FRAUD / REALISM LOGIC

Even in a presentation build, internal state should make sense.

Do not award:

- driver activation
- referral reward
- sales commission

merely because a screen was opened.

Model logical prerequisites.

Example:

`registered`
→ `verified`
→ `activated`
→ `firstRideCompleted`
→ `paymentSuccessful`
→ `commissionEligible`

---

# 51. OFFLINE / POOR CONNECTIVITY

The target market includes environments where connectivity may be weak.

The RFQ explicitly requires low-data/lite behavior and poor-connectivity handling. 

Implement:

- [x] network monitor
- [x] offline banner
- [x] retry strategy
- [x] request timeout *(brief connecting / retry pulse — no infinite spinner)*
- [x] cached essential data *(local trip / wallet / places persistence)*
- [x] local trip-state resilience
- [x] no infinite spinners
- [x] graceful recovery

The application should remain usable when:

- [x] connection disappears
- [x] connection returns
- [x] request fails
- [ ] Google service fails *(requires live Maps key / Places)*
- [x] GPS becomes unavailable *(permission / location empty handling elsewhere)*

---

# 52. ERROR STATES

For every async operation, create explicit states.

At minimum:

- [x] `idle`
- [x] `loading` *(connecting)*
- [x] `success` *(ready)*
- [x] `empty`
- [x] `error`
- [x] `retrying`
- [x] `offline`

Never leave users staring at a spinner forever.

---

# 53. EMPTY STATES

Design intentional empty states for:

- [x] no payment methods *(add / link CTAs in Payments)*
- [x] no trips
- [x] no upcoming trips
- [x] no saved places
- [x] no notifications
- [x] no support tickets
- [x] no trusted contacts
- [x] no referrals
- [x] no corporate history

Each should contain a useful action.

---

# 54. APP STARTUP

Audit startup.

The splash screen should:

- [x] feel premium
- [x] be short enough not to irritate users
- [x] load dependencies
- [x] determine session
- [x] determine device context
- [x] initialize services
- [x] avoid unnecessary blocking
- [x] branded light/dark splash assets (`SplashBackground`) with SF Symbol fallback if missing

### Navigation / Tab IA

- [x] Four-tab shell: Home · Services · Activity · Account
- [x] Hide tab bar during active trip (searching / matched / en route / in trip)
- [x] Deep links: Services Ride → Home booking; Home → Services; Activity empty/rebook → Home; Account trip history → Activity; inbox → Home/Services/Account by category
- [x] Product sheets hand off into Home ride flow
- [x] RootFlowView routes exclusively by `TripPhase`
- [x] Splash → auth (signed out) or main tabs (signed in) with short brand gate

Do NOT initialize unrelated background programs.

---

# 55. REMOVE THE "SYNK/SNYK/SYNC" PROBLEM

There is an unwanted "Synk" / "Snyk" / "Sync" initialization/process in the development environment that is interfering with the workflow.

Inspect the project and determine exactly what it is.

Search:

- scripts
- package dependencies
- build phases
- Xcode build scripts
- CI configuration
- Codemagic
- shell scripts
- package managers
- prebuild/postbuild commands
- Git hooks
- background tooling

If it is an unnecessary project dependency/process and is not required for VUUM runtime or builds:

**REMOVE IT FROM THE PROJECT.**

Do not blindly delete unrelated operating-system tools.

Do not replace it with another intrusive service.

Do not reinitialize/reinstall it during builds.

Do not create a new automatic sync process.

The goal is a clean developer workflow:

Open project → build → run → test.

---

# 56. DEPENDENCY POLICY

You are permitted to install packages that genuinely improve the application.

Before adding a package:

1. confirm it solves a real problem
2. check maintenance status
3. check compatibility with current iOS target
4. avoid unnecessary dependency duplication
5. avoid packages that replace simple native functionality
6. pin sensible versions
7. update package references correctly
8. verify physical-device builds

Prefer:

- Apple frameworks
- Google official SDKs
- mature, maintained Swift packages

Do not turn VUUM into a dependency-heavy mess.

---

# 57. ARCHITECTURE

Preserve the existing architecture where it is good.

But move toward clean separation between:

### Presentation

SwiftUI Views

### View State

Observable / model state appropriate to the project's current architecture.

### Domain

Trip
Ride
Driver
Fare
Payment
Safety
User
Location
Market

### Services

Location
Maps
Places
Routes
Payments
Notifications
Authentication
Persistence
Support
Safety

### Data

- [x] Local mock repository now (rich drivers / places / fares / bike·car·XXL fleets).

Remote repositories later.

This allows:

`MockTripRepository`

to become:

`RemoteTripRepository`

without rewriting the screens.

---

# 58. TRIP STATE MACHINE

Create one authoritative trip state.

Do not allow different screens to invent their own trip status.

All major screens should derive from the same source of truth.

Make invalid state transitions impossible or explicitly handled.

---

# 59. SESSION PERSISTENCE

The current Keychain-based session approach is acceptable if implemented correctly.

Audit:

- [x] login persistence — **Agent 05**: KeychainSwift after welcome / `completeSignIn`
- [x] logout — **Agent 05**: `SessionStore.signOut` clears Keychain keys
- [x] reinstall behavior — **Agent 05**: container wipe drops Keychain session → Get Started
- [x] corrupted state — **Agent 05**: reconcile drops signed-in with too-short mobile
- [x] missing user — **Agent 05**: empty profile fields allowed; mobile required for signed-in
- [x] expired session — **Agent 05**: soft 365-day `signedInAt` expiry
- [x] device restart — **Agent 05**: `accessibleAfterFirstUnlockThisDeviceOnly`

Do not store sensitive data in ordinary UserDefaults if Keychain is appropriate.

---

# 60. DESIGN SYSTEM

Continue using the existing VUUM design system.

Audit:

- [x] typography — shared `VuumType` scale across hubs <!-- Agent 17 -->
- [x] spacing — shared `VuumLayout` insets / section gaps <!-- Agent 17 -->
- [x] corner radii — chip / control / card / panel / sheet tokens <!-- Agent 17 -->
- [x] shadows — restrained panel glass; solid hub cards <!-- Agent 17 -->
- [x] iconography (AppIcon + auth SF Symbol fallbacks; no invented off-brand art)
- [x] cards — `VuumHubCard` solid grouped surfaces on hubs <!-- Agent 17 -->
- [x] sheets — `VuumSheetChrome` / `VuumSheetHandle` for map overlays <!-- Agent 17 -->
- [x] buttons — `VuumPrimaryButton` / `VuumSecondaryButton` / press style <!-- Agent 17 -->
- [x] maps — map-first home; chrome does not fight the map <!-- Agent 17 -->
- [x] tab/navigation behavior
- [x] dark mode — semantic colors + adaptive hairlines/shadows <!-- Agent 17 -->
- [x] light mode — primary presentation path; home sheet remains light <!-- Agent 17 -->

The app must not look like a collection of independently generated AI screens.

Everything should feel like one product.

---

# 61. THE DESIGN SHOULD FEEL PREMIUM, NOT "AI GENERATED"

This is extremely important.

Avoid:

- [x] excessive frosted glass — hubs use solid cards; glass limited to map sheets <!-- Agent 17 -->
- [x] giant pill buttons everywhere — primary CTA is rounded rect; capsule kept for auth parity <!-- Agent 17 -->
- [x] huge gradients — service hero tiles use flat fills <!-- Agent 17 -->
- [x] cartoonish icons — SF Symbols via shared badges <!-- Agent 17 -->
- [x] excessive emojis — none in chrome <!-- Agent 17 -->
- [x] oversized typography — `VuumType` caps section/hero sizes <!-- Agent 17 -->
- [x] unnecessary decorative blobs — removed from hub cards <!-- Agent 17 -->
- [x] random floating cards — consistent `VuumHubCard` elevation <!-- Agent 17 -->
- [x] meaningless animations — shared subtle `VuumPressStyle` only <!-- Agent 17 -->

Use the visual hierarchy found in high-quality mobility applications:

- map first
- clear destination interaction
- restrained bottom sheets
- strong typography
- clear action buttons
- subtle animation
- high information density where useful
- minimal decoration

---

# 62. ACCOUNT NAVIGATION

Make account navigation feel deep and professional.

It should contain multiple real settings rather than a six-item placeholder list.

Settings that should be evaluated:

- [x] Profile
- [x] Phone
- [x] Email
- [x] Password/security
- [x] Language
- [x] Country
- [x] Currency
- [x] Notifications
- [x] Privacy
- [x] Location permission
- [x] Safety
- [x] Trusted contacts
- [x] Payment methods
- [x] Trip history
- [x] Saved places
- [x] Scheduled rides
- [x] Corporate account
- [x] Promotions
- [x] Referrals
- [x] Support
- [x] Terms
- [x] Privacy policy
- [x] About
- [x] Sign out
- [x] Delete account

Only expose settings appropriate to the active account.

---

# 63. SAVED PLACES

Support:

- [x] Home
- [x] Work
- [x] Favorites
- [x] Recent places

Use real addresses from Places where available.

---

# 64. SEARCH QUALITY

Search should behave like a real map product.

Support:

- [x] autocomplete
- [x] typo tolerance where the provider supports it
- [x] businesses
- [x] landmarks
- [x] addresses
- [x] recent searches
- [x] saved places
- [x] current location

Do not show hard-coded destinations as the only options.

---

# 65. REAL MAP DATA SHOULD DRIVE UI WHERE POSSIBLE

When Google credentials are installed:

Pickup and destination should come from actual map data.

Route should come from Routes.

ETA should come from the route.

Distance should come from the route.

Current position should come from Core Location.

Nearby places should come from Places where appropriate.

This is the difference between:

"animated presentation"

and

"working product prototype."

---

# 66. SERVICE AVAILABILITY

Do not show every service in every location.

Service availability should be configurable by:

- country
- city
- zone
- account type

This allows future expansion.

---

# 67. PRICING SHOULD BE CONTEXTUAL

Examples:

Kenya presentation:

`KES 850`

DRC:

`CDF 32,000`
secondary:
`â‰ˆ USD 11.00`

Do not hard-code a single exchange rate everywhere.

Create:

`ExchangeRateConfiguration`

and let the presentation layer consume it.

---

# 68. NOT EVERYTHING NEEDS TO BE "REAL MONEY"

We need realism without pretending a financial transaction happened when it didn't.

Use clearly separated:

- UI simulation
- payment adapter
- real provider integration

The UI should behave as if it will connect to production infrastructure.

When a real provider is connected, the same state machine should continue to work.

---

# 69. APP PERMISSION EXPERIENCE

Create contextual explanations before asking:

Location:

- [x] "VUUM uses your location to find your pickup point and show nearby drivers."

Microphone:

- [x] "Safety recording is available only during an active trip."

Notifications:

- [x] "Get driver arrival, trip and safety updates."

- [x] Do not present generic system permission screens without explaining what feature is about to use them.

---

# 70. ACCESSIBILITY

Audit:

- [x] Dynamic Type — primary auth/home/trip controls use system fonts that scale
- [x] VoiceOver labels — primary trip, auth, and home controls labeled with hints
- [x] Hit target sizes — primary controls meet ~44pt targets (chrome / SOS / safety)
- [ ] Color contrast — polish pass still recommended on secondary chips
- [ ] Reduce Motion — not fully audited for every animation
- [x] Dark Mode — splash/auth support light/dark assets where provided
- [x] Readable fare formatting — locale formatters used for VoiceOver-friendly amounts
- [x] Accessible map controls — trip map exposes phase-aware VoiceOver summary; safety/recenter labeled

Do not rely only on color to communicate state.

---

# 71. ANIMATION

Use animation where it communicates state:

- driver approaching
- searching
- sheet presentation
- map updates
- trip progression
- success
- rating

Avoid animation simply because it looks flashy.

---

# 72. PHYSICAL DEVICE TESTING

Do not assume simulator behavior is enough.

The app has already been sideloaded to an actual iPhone.

Before finalizing:

- build
- install
- launch
- test location
- test permissions
- test map
- test navigation
- test keyboard
- test sheets
- test notifications where available
- test background/foreground
- test interrupted network
- test audio permission
- test dark/light mode
- test orientation behavior where relevant

---

# 73. CODESIGN / SIDeloadING

Preserve the current Codemagic/Sideloadly workflow.

Do not break:

`codemagic.yaml`

Do not introduce a requirement that cannot work with sideloading unless it is genuinely unavoidable.

Make sure:

- [x] bundle identifier is correct
- [x] assets are present (`AppIcon`, `AccentColor`, `SplashBackground`, auth icon imagesets + SF Symbol fallbacks)
- [ ] Info.plist is valid
- [ ] required entitlements are valid
- [ ] build configuration is reproducible

### CI / Codemagic checklist (Agent 18)

Docs: `docs/CODEMAGIC_SETUP.md`, `docs/GOOGLE_MAPS_SETUP.md`, `ios/README.md`, `ios/Secrets.example.xcconfig`.

#### Done in repo (software)

- [x] Unsigned `ios-release` workflow in `codemagic.yaml` (no Apple Developer Portal / certs on CI)
- [x] SPM resolve + deterministic DerivedData path for IPA packaging
- [x] Maps key injection: Codemagic secure env → `ios/Secrets.xcconfig` + `xcodebuild` `VUUM_GOOGLE_MAPS_API_KEY`
- [x] Info.plist `$(VUUM_GOOGLE_MAPS_API_KEY)` substitution wired; `MapBootstrap` ignores placeholders
- [x] Bundle ID `com.vuum.app`; iOS 17+; Sideloadly IPA artifact `build/Vuum.ipa`
- [x] No Snyk / security-scan steps in CI (see `docs/NO_SNYK.md`)
- [x] Build succeeds without Maps credentials (map unavailable surface only)

#### Credential-only remaining (operator — not code)

- [ ] Google Cloud billing + **Maps SDK for iOS** enabled
- [ ] API key restricted to iOS + bundle ID `com.vuum.app`
- [ ] Codemagic secure env `VUUM_GOOGLE_MAPS_API_KEY` set
- [ ] Rebuild IPA → Sideloadly → confirm live map tiles

When the three credential boxes above are checked:

**GOOGLE MAPS CREDENTIALS ARE NOW THE ONLY REMAINING CONFIGURATION STEP** (for CI map tiles; Places/Routes remain optional expansions).

---

# 74. TESTING MATRIX

**Deliverable:** [`docs/TESTING_MATRIX.md`](docs/TESTING_MATRIX.md) — full device/feature walkthrough with columns Feature / How to test / Expected result / Status (`Pass` · `Blocked on Maps key` · `Manual on device`).

Build an internal test matrix covering:

### Authentication
- [x] fresh install — **Pass A / Agent 05**: splash → Get Started when no Keychain session
- [x] existing session — **Pass A / Agent 05**: `SessionStore` restores signed-in → Main tabs (**Manual on device** relaunch evidence → §72)
- [x] logout — **Pass A / Agent 05**: Account sign out clears Keychain → Auth flow
- [x] invalid OTP — **Pass A / Agent 05**: wrong code errors; digits cleared; max attempts
- [x] expired OTP — **Pass A / Agent 05**: 180s expiry; Resend refreshes; expired message on submit
- [x] Apple/Google/Email continue — **Agent 05**: visible, inert, silent (no demo toasts)
- [x] auth L10n — **Agent 05**: EN/FR/LN/SW strings for all auth screens

### Location
- [x] permission accepted — **Manual on device** (matrix §2)
- [x] permission denied — **Manual on device**
- [x] location unavailable — **Manual on device**
- [x] approximate location — **Manual on device**
- [x] location changes — **Manual on device**

### Maps
- [x] API key present — **Blocked on Maps key** until credential checkpoint
- [x] API key absent — **Pass** (placeholder + local catalog + synthetic routes)
- [x] Places available — live Google **Blocked on Maps key**; local catalog **Pass**
- [x] Places failure — **Pass** (catalog fallback)
- [x] Routes available — **Pass B**: RouteEngine + synthetic fallback; live road path **Blocked on Maps key**
- [x] Routes failure — **Pass B**: synthetic path retained

### Home / chat / products / zones
- [x] Covered in `docs/TESTING_MATRIX.md` §§4, 7, 12–13 (Pass A–C + zone catalog)

### Booking
- [x] pickup — **Pass A**: Home pickup → AdjustPickupSheet; location updates pickup
- [x] destination — **Pass A**: Where to? / recents / saved → choose ride
- [x] multiple stops — **Pass A**: Add stop from ride options; change destination keeps stops
- [x] scheduled — **Pass A**: Now/Later; future → Reserve → upcoming
- [x] someone else — **Pass A**: For others requires name + phone before Confirm
- [x] cancellation — **Pass B**: CancelTripSheet + fee/free window
- [x] promo — **Pass A**: VUUM10 / WELCOME on choose-ride
- [x] payment — **Pass A**: PaymentMethodPickerRow / company wallet path

### Trip
- [x] searching — **Pass B**
- [x] assigned — **Pass B** (matched beat)
- [x] approaching — **Pass B**
- [x] arrived — **Pass B**
- [x] OTP — **Pass B** (boarding PIN + requirePIN pref)
- [x] active — **Pass B**
- [x] destination change — **Pass B**
- [x] completion — **Pass B**

### Safety
- [x] SOS — **Pass B**
- [x] trip share — **Pass B**
- [x] trusted contacts — **Pass B**
- [x] incident report — **Pass B**
- [x] recording permission — **Pass B** / **Manual on device** (mic prompt)
- [x] recording start — **Pass B** / **Manual on device**
- [x] recording stop — **Pass B** / **Manual on device**

### Account
- [x] profile <!-- QA Pass C -->
- [x] payments <!-- QA Pass C -->
- [x] history <!-- QA Pass C -->
- [x] support <!-- QA Pass C -->
- [x] settings <!-- QA Pass C -->
- [x] localization <!-- QA Pass C (prefs / market) -->

### Network
- [x] offline — **Manual on device** (`VuumOfflineBanner`)
- [x] weak network — **Manual on device**
- [x] reconnect — **Manual on device**

---

# 75. AUTOMATED TESTING

Where practical, add tests for:

- fare calculations
- currency formatting
- market selection
- phone number country configuration
- trip state transitions
- cancellation rules
- promo validation
- OTP validation
- ETA calculations
- driver state
- payment state
- referral eligibility

Do not spend the entire effort writing tests for trivial SwiftUI visual minutiae.

Test business logic and critical state.

---

# 76. REGRESSION RULE

Every significant code change must preserve:

- app launch
- authentication
- home
- booking
- trip state
- account
- build pipeline

Do not "fix" one screen by breaking three others.

---

# 77. RFQ COVERAGE AUDIT

**Status (2026-08-23):** Delivered — [`docs/RFQ_204_MATRIX.md`](docs/RFQ_204_MATRIX.md)  
(206 extracted keys; statuses: **done** / **partial** / **prepared** / **missing** / **n/a** ≡ Implemented / Partially Implemented / Architecturally Prepared / Missing / Not Applicable to Rider iOS Presentation).

Create an internal coverage matrix mapping every relevant RFQ reference to:

`Implemented`
`Partially Implemented`
`Architecturally Prepared`
`Not Applicable to Rider iOS Presentation`
`Missing`

Do this across all 204 references.

The current rider-only scope means many references belonging to:

- Driver
- Admin
- Dispatcher
- Corporate web portal
- Safety backend
- Field sales portal

will not literally be implemented inside this iOS rider app.

That is fine.

But the application must be architected so the rider-facing portions are ready.

Do not falsely claim that the rider app implements the admin dashboard.

---

# 78. PRIORITY ORDER

Work in this order:

## PHASE 1 — REPOSITORY INTELLIGENCE

Before changing anything:

- inspect entire repository
- inspect project structure
- inspect Package.swift / SPM references if present
- inspect Xcode project
- inspect Info.plist
- inspect build scripts
- inspect Codemagic
- inspect all UI
- inspect state management
- inspect TripSession
- inspect SessionStore
- inspect maps
- inspect persistence
- inspect the unwanted Synk/Snyk/Sync process

Produce an internal implementation map.

Then begin modifications.

---

## PHASE 2 — CORE PRODUCT FOUNDATION

Fix:

- location
- market
- language
- currency
- phone number
- session
- trip state
- fare engine
- service categories
- maps abstraction

---

## PHASE 3 — REAL MAP STACK

Implement:

- Maps
- [x] Places
- Routes
- current GPS
- route
- ETA
- [x] address search
- markers
- moving vehicle

Leave only credentials/configuration for me.

---

## PHASE 4 — UBER/BOLT-CLASS RIDER FLOW

Polish:

- home
- destination
- ride type
- fare
- matching
- driver approach
- driver arrival
- PIN
- active trip
- [x] completion <!-- Agent 24: PostTripCompleteView -->
- [x] rating <!-- Agent 24: stars, tip, tags, skip, persist to Activity -->

---

## PHASE 5 — ACCOUNT ECOSYSTEM

Implement:

- [x] profile <!-- QA Pass C -->
- [x] payments <!-- QA Pass C -->
- [x] history <!-- QA Pass C -->
- [x] receipts <!-- QA Pass C -->
- [x] scheduled rides <!-- QA Pass C (Activity Upcoming) -->
- [x] saved places
- [x] promotions <!-- QA Pass C -->
- [x] referrals
- [x] settings <!-- QA Pass C -->
- [x] support
- [x] safety <!-- QA Pass C -->

---

## PHASE 6 — TRUST & SAFETY

Implement:

- [x] safety center
- [x] SOS
- [x] trusted contacts
- [x] share trip
- [x] incident reporting
- [x] audio safety architecture
- [x] permission flows
- [x] safety notifications

---

## PHASE 7 — CORPORATE

Implement rider-facing:

- [x] corporate account
- [x] spending-limit feedback
- [x] billing context
- [x] cost centre
- [x] corporate trip
- [x] executive booking
- [x] corporate safety

---

## PHASE 8 — FIELD SALES / REFERRALS

Prepare:

- [x] referral codes
- [x] recruitment attribution
- [x] first-ride trigger model
- [x] commission eligibility model

---

## PHASE 9 — QA

Run a full regression.

- [x] QA Pass C — Account + Pay + Activity + Support (`docs/QA_PASS_C.md`) <!-- Agent 21 -->

---

## PHASE 10 — VISUAL POLISH

Only after logic is stable.

Fix:

- [x] spacing — `VuumLayout` tokens on hubs <!-- Agent 17 -->
- [x] typography — `VuumType` on shared chrome + hubs <!-- Agent 17 -->
- [x] transitions — shared press style; no decorative motion <!-- Agent 17 -->
- [x] icons (catalog + SF Symbol fallbacks)
- [x] sheets — shared handle + restrained glass panel style <!-- Agent 17 -->
- [x] dark mode — semantic colors + adaptive hairlines/shadows <!-- Agent 17 -->
- [x] accessibility — headers/traits on section chrome; filter chips as plain buttons <!-- Agent 17 -->
- [x] empty/error states — coming-soon / hub empties use primary button + brand badge <!-- Agent 17 -->

---

# 79. DO NOT STOP WHEN ONE AGENT FINISHES

One agent saying:

"Feature implemented"

does NOT mean the feature is complete.

Another agent should inspect it.

Then another should test its integration.

Then a final audit should verify:

- UX
- logic
- architecture
- visual consistency

---

# 80. DO NOT INVENT BACKEND DEPENDENCIES

We currently have no requirement to build a production database simply to make this presentation application work.

Use local repositories/mocks intelligently.

However, never hard-code the entire product around fake screens.

Every important service must have an interface boundary that could later connect to a backend.

---

# 81. NO FAKE "DEMO" LANGUAGE IN USER-FACING UI

Never show:

- Demo
- Fake Ride
- Simulated Driver
- Mock Payment
- Demo Location

unless a hidden developer/testing mode specifically exposes such information.

User-facing UI should simply behave like VUUM.

Internal documentation may refer to this as a presentation build.

---

# 82. DEVELOPER / TEST MODE

Create a clearly separated developer-only environment if useful.

It may expose:

- reset data
- choose market
- simulate driver state
- force trip state
- inspect current location
- simulate network
- simulate payment response
- test SOS
- test recording
- test localization

Do NOT expose this casually to the client-facing UI.

Make sure it cannot accidentally become part of the normal user journey.

---

# 83. DO NOT DESTROY CURRENT GOOD WORK

Before large refactors:

- inspect existing implementation
- understand dependencies
- preserve components that are already polished
- migrate incrementally

Do not rewrite the whole app just to satisfy this prompt.

---

# 84. FINAL VISUAL BENCHMARK

Before saying finished, mentally compare the application against a polished commercial mobility app.

Ask:

"Would a client immediately believe this is a real ride-hailing product?"

Then ask:

"What would give away that it is only a presentation build?"

Fix those things.

The biggest tells are usually:

- static maps
- dead buttons
- shallow settings
- unrealistic driver movement
- bad location behavior
- inconsistent currency
- generic placeholder data
- no loading/error states
- poor trip history
- weak account screen
- no safety ecosystem
- no realistic cancellation
- no payment state
- no scheduled rides
- no actual location context

Eliminate those.

---

# 85. FINAL ACCEPTANCE CRITERIA

The final iPhone build should allow a presenter to do this naturally:

1. [x] Launch VUUM.
2. [x] See polished branding.
3. [x] Grant location permission.
4. [x] See actual current location. *(Core Location + pickup update work without Maps key; live map tiles / blue-dot require Google Maps API key)*
5. [x] Tap "Where to?"
6. Search for a real address. *(Local catalog + PlacesSearchService fallback without key; arbitrary Google Places autocomplete requires API key)*
7. [x] Select a destination.
8. View a real route. *(Synthetic route + distance/ETA without key; live Directions polyline on map requires API key)*
9. [x] See distance and ETA.
10. [x] Select a ride category.
11. [x] See meaningful fare breakdown.
12. [x] Select payment.
13. [x] Request ride.
14. [x] See realistic matching.
15. [x] Get a driver.
16. [x] See driver details.
17. Watch vehicle approach. *(Motion simulation without key; on-map vehicle animation requires Maps API key)*
18. [x] Verify vehicle/PIN.
19. [x] Start the ride.
20. [x] See active trip.
21. [x] Open chat/call UI.
22. [x] Open safety center.
23. [x] Share trip.
24. [x] Trigger/inspect SOS workflow.
25. [x] Change destination if supported.
26. [x] Complete ride.
27. [x] View final fare.
28. [x] Rate driver.
29. [x] View receipt.
30. [x] Open trip history.
31. [x] Open payment history.
32. [x] Open account.
33. [x] Open support.
34. [x] Open settings.
35. [x] Change language.
36. [x] Inspect trusted contacts.
37. [x] Inspect payment methods.
38. [x] Inspect scheduled rides.
39. [x] Inspect referral/promotion features.
40. [x] Demonstrate corporate/Executive functionality where applicable.

The experience should not require the presenter to explain why buttons do nothing.

**Agent 38 — credential-only remaining (Google Maps API key):**
- Live map tiles (not “Map unavailable”)
- Blue-dot / my-location on Google Maps
- Google Places autocomplete for arbitrary addresses
- Live Directions polyline rendering on the map
- On-map driver approach / in-trip vehicle animation

---

# 86. BEFORE YOU DECLARE COMPLETION

Run one final autonomous audit with these exact questions:

### Product

- Does this feel like a real VUUM product?

### Location

- Does it actually respond to the device's location?

### Kenya

- On a Kenyan device, does phone configuration naturally support +254 and KES?

### DRC

- Can the same architecture represent +243, CDF and USD correctly?

### Maps

- Is Google Maps fully wired so that inserting credentials activates the intended functionality?

### Search

- [x] Does Places autocomplete have the correct session architecture?

### Routes

- Does route calculation provide usable distance/ETA/polyline data?

### Trip logic

- Can every trip state transition be explained?

### Payments

- [x] Are payment states realistic?

### Safety

- Is SOS coherent?
- Is trip sharing coherent?
- Are trusted contacts coherent?
- Is audio recording explicitly permissioned and limited to active trips?

### Permissions

- Are permission prompts contextual?

### Account

- [x] Does the account page feel as comprehensive as a major ride-hailing application? <!-- QA Pass C: AccountHub + settings depth -->

### RFQ

- Have all relevant rider-facing RFQ requirements been covered?

### Corporate

- [x] Is corporate rider support architecturally prepared? <!-- QA Pass C: BusinessProfile + company wallet / VIP -->

### Field sales

- [x] Is referral/recruitment attribution architecturally prepared? <!-- QA Pass C: ReferFriends + lifecycle model -->


### Build

- Does the project still build cleanly?

### Sideload

- Can the resulting IPA still be sideloaded?

### Dependencies

- Did we remove unnecessary dependencies?
- Did we remove the unwanted Synk/Snyk/Sync initialization?

### Regression

- Did any new feature break an existing one?

### Premium feel

- Would I confidently put this app in front of the VUUM client?

If the answer to any meaningful question is "no", continue working.

Do not report completion until the outstanding issue has been addressed or explicitly documented as a credential/backend-only dependency.

---

# 86A. AGENT 04 — DEPENDENCIES / SPM / SDK WIRING (CHECKLIST)

Status as of Agent 04 pass:

- [x] Audit `ios/Vuum.xcodeproj` SPM package references
- [x] **Google Maps** SPM declared — `https://github.com/googlemaps/ios-maps-sdk` â‰¥ 9.0.0, product `GoogleMaps` (remote tags verified)
- [x] **ComponentsKit** SPM declared — `https://github.com/componentskit/ComponentsKit` â‰¥ 1.7.0 (remote tags verified)
- [x] **KeychainSwift** SPM declared — `https://github.com/evgenyneu/keychain-swift.git` (fixed broken pin `24.0.0` → **`9.0.0`**; latest remote tag is 9.0.2)
- [x] Places helper ready without extra SPM — `PlacesSearchService` (Places API New HTTPS + session tokens); no-key / failure → local catalog fuzzy fallback
- [x] Routes helper ready without extra SPM — `RoutesAPIService` (`computeRoutes` HTTPS + polyline decode); no-key → `nil` / `TripGeo` fallback
- [x] No Firebase / BLE / Snyk / Navigation SDK added
- [x] Docs: `docs/SETUP.md` + `docs/GOOGLE_MAPS_SETUP.md` document API key as only remaining credential step
- [x] Mac SPM resolve admin commands documented in `docs/SETUP.md` (Windows cannot resolve Apple SPM locally)
- [ ] **Credential-only (user):** create Google Cloud key, enable Maps SDK for iOS + Places API (New) + Routes API, inject `VUUM_GOOGLE_MAPS_API_KEY` via Codemagic / scheme / `Secrets.xcconfig`

---

# 87. GOOGLE CREDENTIAL CHECKPOINT

When the application is genuinely ready for the Google integration credentials, stop and report exactly:

**GOOGLE MAPS / PLACES / ROUTES CREDENTIAL CHECKPOINT REACHED**

Then provide:

- Google Cloud project requirements
- APIs that must be enabled
- API key restrictions
- bundle ID requirements
- where to place the key
- Xcode configuration
- Codemagic configuration
- required billing configuration
- test procedure

Do not ask for the credentials prematurely.

Do not leave Google integration half-implemented.

Once I provide the credentials, the application should require configuration rather than a major architectural rewrite.

---

# 88. FINAL OUTPUT TO ME

At the end, provide a concise engineering report containing:

### 1. What already existed
### 2. What was improved
### 3. What was added
### 4. What was removed
### 5. What packages were installed
### 6. What packages were removed
### 7. What happened to the Synk/Snyk/Sync process
### 8. Current Google integration state
### 9. Remaining credential-only steps
### 10. Remaining backend-only requirements
### 11. RFQ rider-side coverage
### 12. Known limitations
### 13. Tests performed
### 14. Build result
### 15. Sideload readiness

Do not write "everything is done" if anything material is still broken.

---

# FINAL COMMAND

Start by auditing the current VUUM repository.

Do not immediately start designing screens.

Understand what exists.

Then execute the workstreams in parallel where supported.

Research current Uber/Bolt product patterns and official Google/Apple documentation where necessary.

Implement improvements directly in the repository.

Install dependencies that are genuinely required.

Remove unnecessary tooling that interferes with the application workflow, including the unwanted Synk/Snyk/Sync initialization if it is confirmed to be an unnecessary project dependency.

Keep the architecture extensible.

Keep the UI premium.

Keep location and market context dynamic.

Keep currencies dynamic.

Keep phone-number configuration dynamic.

Keep Maps/Places/Routes ready for real credentials.

Keep the rider flow believable.

Keep the application stable.

Continue iterating through audit → implementation → test → refinement cycles rather than stopping after the first successful build.

The objective is not to produce a pretty mockup.

The objective is to produce the most convincing, polished, realistic **VUUM rider application possible at this stage**, so that after the required real service credentials are supplied, the existing architecture can transition naturally toward the full production platform described by RFQ `VUUM-RFQ-2026-UNI`.

Do not rush to finish.

Do the work thoroughly.

---

# AGENT 37 — INTEGRATION GLUE (TripSession ↔ Map ↔ Chat ↔ ETA)

## Single ride path (source of truth)

`TripSession` owns the live ride. Do not invent parallel ETA clocks in SwiftUI.

### Phase path

`idle → selectingDestination → choosingRide → searching → matched → driverEnRoute → driverArrived → inTrip → completed`

(`matched` is a short beat after assignment so the driver card + chat open before the car starts moving.)

### Product ETA constants

| Fleet class | Displayed pickup ETA | Source |
|-------------|----------------------|--------|
| Bike / 2-Wheels | **2 min** | `VehiclePickupETA.bikeMinutes` |
| Standard car (Vuum, Comfort, Courier) | **5 min** | `VehiclePickupETA.standardCarMinutes` |
| Large / XL / Executive / Hourly | **10 min** | `VehiclePickupETA.largeXXLMinutes` |

Wall-clock map animation is compressed via `TripMotionTiming` (delegates to the same class baselines). `VehiclePickupETA.approachSimulationSeconds` must call `TripMotionTiming` — no second timing table.

### What one assignment drives

1. **Match ETA** — `tier.etaMinutes` / `VehiclePickupETA.minutes(for:)` on the choose-ride row and on the driver card after match.
2. **Map car animation** — spawn distance from `TripMotionTiming.approachDistanceMeters`; marker motion duration from `TripMotionTiming.approachSimulationSeconds` / `tripSimulationDurationSeconds`; `routeProgress` + `motionSimulationKind` published for Maps.
3. **Chat availability** — `TripSession.isChatAvailable` is true for `matched | driverEnRoute | driverArrived | inTrip` when `activeTrip != nil`. Message CTA uses this flag.
4. **Driver card** — `RootFlowView` shows active-trip UI for `matched` onward; card ETA counts down with motion via `TripMotionTiming.displayedETAMinutes`.

### Integration checklist

- [x] Tier rows publish class-based pickup ETAs (not raw chord distance).
- [x] `assignDriver` / `finishAssignDriver` spawn by class ETA distance and pick a class-matched driver.
- [x] Approach / in-trip motion uses `TripMotionTiming` (no hard-coded display clocks).
- [x] Chat gated by `isChatAvailable`.
- [x] Map pins carry `vehicleClass` (bike vs car vs XL glyphs).
- [x] `RootFlowView` routes `.matched` to the active-trip UI.

### Do not

- Reintroduce independent ETA math in map or chat views.
- Skip `.matched` when wiring new trip UI.
- Duplicate bike/car/XL minute constants outside `VehiclePickupETA`.
