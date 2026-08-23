# Vuum — Ride Hailing Demo

## Purpose

Client demo of an iOS ride-hailing product (Uber/Bolt-style experience). Goal is a polished, interactive UI walkthrough that feels production-ready, without a full production backend.

## Product

- **Platform:** iOS
- **UI:** SwiftUI first; UIKit only where needed (e.g. some map integration)
- **Brand:** **Vuum** (original app brand and visuals — not a white-label or clone of another company)
- **Build / CI:** Codemagic (no local Mac required for compiling and distributing builds)

## Demo scope (what we are building)

A rider-facing flow with map + mock trip logic:

1. Splash / entry
2. Home map with “Where to?”
3. Destination selection
4. Ride options (tiers) with estimated prices
5. Confirm request → searching / matching
6. Driver assigned (driver card, ETA)
7. Active trip on map (animated driver marker)
8. Trip complete + rating

### Real integrations in the demo

- **Maps:** Google Maps SDK (pickup/drop pins, route/context, moving driver marker)
- **Mock data layer:** drivers, fares, ETAs, trip state transitions (in-app / local JSON or models)

### Intentionally lightweight

No full dispatch system, payments stack, or complex backend for this demo. Core screens + maps + believable mock trip behavior are enough for the client to evaluate quality.

## Technical direction

- SwiftUI app structure organized around the rider demo flow
- Map-centric home and trip screens
- Simple state machine for trip stages (idle → searching → assigned → in trip → completed)
- Codemagic pipeline for iOS build / TestFlight-style delivery when Apple Developer signing is available

## Success criteria for the demo

- Client can walk through the full ride request → trip → complete path in a few minutes
- UI feels premium and coherent under our own brand
- Map interactions and trip animation sell the product vision
- Build is reproducible via Codemagic
