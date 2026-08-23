# Automated tests — Vuum iOS

XCTest target **`VuumTests`** covers critical business logic (directive **§75 partial** — not fully done):

| File | Focus |
|------|--------|
| `ios/VuumTests/TripSessionPhaseTests.swift` | Trip phase machine: idle → selecting → choosingRide → searching → cancel / reset |
| `ios/VuumTests/TripSessionLifecyclePhaseTests.swift` | Accelerated search → matched → enRoute → arrived → inTrip (+ boarding PIN) |
| `ios/VuumTests/VehiclePickupETATests.swift` | Pickup ETA by class: bike **2**, car **5**, XXL/large **10** |
| `ios/VuumTests/FarePromoMathTests.swift` | `MockFares.breakdown` discount / waiting / surge; `PromoCodesStore` validation |
| `ios/VuumTests/AuthOTPValidationTests.swift` | Phone / OTP digit gates, profile email rules, `AppLocale` national-number helpers |
| `ios/VuumTests/CurrencyMoneyFormattingTests.swift` | `Money` / `CurrencyFormatter` / FX helpers / dual-currency pairs |
| `ios/VuumTests/PaymentReferralEligibilityTests.swift` | `PaymentMethodStore` selection gates + `ReferralStore` anti-fraud lifecycle |
| `ios/VuumTests/RouteDeviationTests.swift` | Polyline corridor distance + `RouteDeviationMonitor` persistence / recovery |

Still open for a fuller §75 pass: async OTP verify / expiry / attempt lockout (network-style sleeps), full in-trip → completed + cancel-fee matrix, `FieldSalesStore` commission settlement, market-selection UI store tests, live Routes/Places (credential-gated).

Windows cannot run `xcodebuild` / XCTest. Use a Mac or Codemagic. Suites are registered on the **VuumTests** target so they compile with the app.

`TripSession.testingAcceleratedLifecycle` + `testingPreferImmediateDriverMatch()` compress search ticks and approach motion for lifecycle XCTests only (default off in the product).

---

## Mac (Xcode)

1. Open `ios/Vuum.xcodeproj`
2. Resolve SPM if needed (**File → Packages → Resolve Package Versions**)
3. Select scheme **Vuum**
4. Product → Test (`⌘U`), or:

```bash
cd "/path/to/Raide hailing application demo"
xcodebuild test \
  -project ios/Vuum.xcodeproj \
  -scheme Vuum \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath build/DerivedData
```

Replace the simulator name with any installed iOS 17+ simulator (`xcrun simctl list devices available`).

---

## Codemagic

The default `ios-release` workflow builds an unsigned IPA and does **not** run tests (keeps Sideloadly packaging fast).

To run unit tests on CI, add a script step (or a separate workflow) after SPM resolve:

```bash
set -o pipefail
xcodebuild test \
  -project ios/Vuum.xcodeproj \
  -scheme Vuum \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO
```

Use an `instance_type` with Xcode + simulators (`mac_mini_m2`). Adjust the destination to a simulator present on that Xcode image.

---

## Target wiring

- App target: `Vuum` (`com.vuum.app`)
- Test target: `VuumTests` (`com.vuum.app.tests`), app-hosted (`TEST_HOST` → `Vuum.app`)
- Scheme **Vuum** lists `VuumTests` under Test
