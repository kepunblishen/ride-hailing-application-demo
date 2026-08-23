# Vuum vs Uber / Bolt — Maps & rider capability matrix

**Audit:** §69 — Uber / Bolt comparison  
**Date:** 2026-08-23  
**Method:** Evidence from `ios/Vuum/` + prior QA docs. Uber/Bolt columns are **market-typical product patterns** (not a claim that every market ships every row). Do not copy branding.  
**Related:** [`MAPS_AUDIT_GAP_STATUS.md`](./MAPS_AUDIT_GAP_STATUS.md) · [`MAPS_HARDENING_FINAL_REPORT.md`](./MAPS_HARDENING_FINAL_REPORT.md)

**Legend (VUUM):** **Y** = shipped in rider client · **P** = partial / local-only / thinner UX · **N** = not present  
**Missing?** = gap vs benchmark for a presentation-credible rider app  
**Priority:** P0 presentation blocker · P1 high commercial credibility · P2 nice-to-have / later phase

---

## 1. Maps / location / routing (Google-facing)

| Capability | Uber | Bolt | VUUM | Missing? | Priority | Evidence / notes |
|---|---|---|---|---|---|---|
| Live basemap tiles (SDK) | Y | Y | **P** | Yes until keyed build proven | **P0** | `VuumMapView` + SPM GoogleMaps; placeholder without key |
| Blue-dot / current location | Y | Y | **P** | Device + permission proof open | **P0** | `RiderLocationManager`; market default centers still used in sheets |
| Pickup pin from GPS + reverse label | Y | Y | **Y/P** | Richer landmark chrome | P1 | `TripSession` + `ReverseGeocodingService` (Google → Apple → coord) |
| Destination autocomplete | Y | Y | **Y/P** | Place types / distance chrome | P1 | Places API (New) HTTPS + local catalog fallback |
| Place Details → lat/lng | Y | Y | **Y** | — | — | Field-masked Details in `PlacesSearchService` |
| Road-following route polyline | Y | Y | **Y/P** | Needs live-key device pass | **P0** | Routes → Directions → synthetic (`RouteEngine`) |
| Traffic-aware ETA (pre-trip) | Y | Y | **P** | In-trip often speed-based | P1 | Routes `TRAFFIC_AWARE` when keyed; synthetic otherwise |
| Multi-stop / waypoints on route | Y | Y | **Y** | — | — | Routes `intermediates` / Directions waypoints |
| In-trip destination change + re-route | Y* | Y* | **Y** | Device proof open | P1 | `ChangeDestinationSheet` + `destinationRouteGeneration` |
| Driver marker follows route + heading | Y | Y | **Y** | Backend GPS later | — | Local motion along polyline |
| Nearby fleet relative to pickup | Y | Y | **Y** | Mock fleet only | P2 | `seedNearbyVehicles` |
| Route deviation notice | Y | Y | **Y** | No real safety backend | P1 | `RouteDeviationMonitor` |
| Turn-by-turn Navigation SDK (rider) | N† | N† | **N** | Intentional | — | Rider map + polyline only (correct) |
| Distance Matrix client calls | Rare | Rare | **N** | — | — | Correctly unused |
| Offline / degraded map UX | P | P | **P** | Explicit Maps Retry copy thin | P1 | Catalog + synthetic; limited Google error Retry |

\* Market-dependent on Uber/Bolt.  
† Drivers use navigation apps/SDKs; riders typically see overview map.

---

## 2. Booking & trip realism (Maps-adjacent product)

| Capability | Uber | Bolt | VUUM | Missing? | Priority | Evidence / notes |
|---|---|---|---|---|---|---|
| Service / tier selection + fare preview | Y | Y | **Y** | Live settlement later | — | `PricingEngine` / mock fares (not Google) |
| Reserve / scheduled rides | Y | Y | **P** | Edit/reminders thinner | P1 | Reserve + Upcoming list; local persistence |
| Ride for someone else | Y | Y | **Y** | — | — | `bookForSomeoneElse` + name/phone gate |
| Quiet ride preference | Y* | Y* | **Y** | Preference only (no dispatch) | P2 | `preferQuietRide` |
| Accessibility notes to driver | Y* | Y* | **Y** | Preference only | P2 | `accessibilityNotes` |
| Pickup notes / landmarks | Y | Y | **P** | Dedicated note field thin | P2 | Airport zone chrome; not full Uber pickup notes |
| Airport pickup instructions | Y | Y | **P** | Zone flag + fare line | P2 | `zoneContext.isAirportArea` |
| Cash + mobile money options | Market | Market | **Y** | Real MM APIs later | P1 | Cash / M-Pesa / Airtel / wallet / card UI |
| Boarding / trip PIN | Y | Y | **Y** | Driver app verify later | — | Trip PIN UI + mismatch handling |
| In-trip chat | Y | Y | **P** | Local / gated phases | P1 | `DriverChatView` when `isChatAvailable` |
| Cancel + fee messaging | Y | Y | **Y** | Policy backend later | — | Cancel fee paths in trip session |

---

## 3. Safety, support, account (credibility)

| Capability | Uber | Bolt | VUUM | Missing? | Priority | Evidence / notes |
|---|---|---|---|---|---|---|
| Safety toolkit | Y | Y | **Y** | — | — | `SafetyToolkitView` |
| SOS | Y | Y | **P** | No live safety ops backend | **P0**‡ | Local notify / confirmation only |
| Trip share | Y | Y | **P** | Share sheet; no live tracking server | P1 | Share with phase message |
| Trusted contacts | Y | Y | **Y** | SMS/push later | P1 | Account + toolkit |
| Favorite / saved places | Y | Y | **Y** | — | — | `SavedPlacesView` / favorites |
| Favorite drivers | Y* | Y* | **N** | Optional | P2 | Not implemented |
| Lost item report | Y | Y | **Y** | Ticket backend later | P2 | `LostItemReportView` + support |
| Receipt / history | Y | Y | **Y** | Email/provider later | P1 | Activity + payment history |
| Fare review / dispute | Y | Y | **P** | Support shells | P2 | Ratings / support; thin dispute |
| Driver reporting | Y | Y | **P** | Incident entry | P2 | Safety / support paths |
| Child seat / accessibility product SKU | Market | Market | **N** | Notes only | P2 | Accessibility notes ≠ seat SKU |
| Rider ID verification | Y | Y | **N** | Future | P2 | Auth OTP only |
| Suspicious trip alerts | Y | Y | **N** | Future / backend | P2 | — |

‡ For **client presentation**, SOS must look complete; live dispatch is explicitly out of rider-only scope but should be disclosed as simulated notify if asked.

---

## 4. Platform / ops (not rider UI, but matrix-relevant)

| Capability | Uber | Bolt | VUUM | Missing? | Priority | Notes |
|---|---|---|---|---|---|---|
| Production dispatch / driver GPS | Y | Y | **N** | Backend + driver app | P0 post-presentation | Local motion simulation |
| Split Maps SDK vs web API keys | Y | Y | **N** | Security hardening | P1 | Single `VUUM_GOOGLE_MAPS_API_KEY` |
| Places native iOS SDK | Mixed | Mixed | **N** | REST New chosen | P2 | Intentional; document in architecture |
| Cloud key restriction applied | Y | Y | **?** | Operator action | **P0** | Docs prescribe; Console not verifiable in repo |
| Physical device Maps E2E signed off | Y | Y | **N** | Evidence template empty | **P0** | `DEVICE_QA_EVIDENCE.md` / `MAPS_POST_KEY_QA.md` |

---

## 5. Summary — what still matters most

**Do not treat “Uber has it” as a must-build list.** Closest commercial gaps for Vuum’s Maps audit:

1. **P0** — Live keyed IPA + Kenya GPS / DRC market device proof; Cloud key restrictions; honest SOS scope.  
2. **P1** — In-trip ETA from remaining Google duration; Places result chrome; Maps error Retry; key split plan; scheduled-ride depth.  
3. **P2** — Favorite drivers, child-seat SKU, verification, suspicious-trip alerts, Navigation SDK (skip for rider).

**High-value features already present (do not re-build):** multi-stop, destination change, PIN, reserve path, ride-for-others, quiet/accessibility notes, safety toolkit, saved places, lost-item UI, cash/MM payment selection UI.

---

## 6. Out of scope this doc

- Feature implementation  
- Commits / real API keys  
- Snyk  
- Changing Google Cloud Console (operator checklist only)
