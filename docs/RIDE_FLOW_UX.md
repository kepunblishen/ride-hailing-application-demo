# Rider flow UX (Uber-like sequencing)

Agent guidance for Vuum trip screens. Keep the map as the spatial hero after destination is known; use half-sheets only for decisions that need map context.

## Sequence

| Step | Surface | Belongs here |
|------|---------|--------------|
| **1. Home (content)** | Full tab / hub | “Where to?”, recent/saved places, services entry, account shortcuts. Map optional/teaser — not the booking decision UI. |
| **2. Destination search** | Full-screen search (or tall sheet that owns keyboard) | Pickup/dropoff fields, suggestions, recent/saved, map pin adjust after pick. Primary job: resolve places. |
| **3. Map + route** | Map-dominant + compact chrome | Route polyline, pickup/drop pins, ETA/distance chips on map. Confirms spatial story before products. |
| **4. Product select** | Half-sheet over map | Product list (name, ETA, price), payment chip, primary CTA (“Choose …”). Map stays visible (~50–70%). |
| **5. Confirm** | Same sheet stack or short confirm step | Pickup pin refine, fare summary, payment method, Confirm CTA. Still map-backed. |
| **6. Matching** | Map + compact status sheet | Searching/matching state, cancel, weak-network hint. No product browsing. |
| **7. En route** | Map + trip sheet | Driver card (name, photo, rating, vehicle, plate), ETA, call/chat, share trip, safety. Route: driver → pickup. |
| **8. In trip** | Map + trip sheet | Driver → destination route, remaining time, share/safety, change destination / stop (secondary). |
| **9. Receipt** | Full post-trip screen | Fare, tip, rating, receipt ID, rebook/help. Payment already settled — no live map required. |

## Half-sheet: put / don’t put

**Put on the half-sheet**

- One decision or one status block (products, confirm, matching pulse, live driver card).
- Price + ETA rows, payment method shortcut, single primary CTA.
- Short secondary actions (Schedule, For me / someone else) that don’t need another map mode.

**Do not put on the half-sheet**

- Home content hubs (promos, multi-service catalogs, activity lists, settings).
- Long forms, legal text, multi-step wizards, nested navigation stacks.
- Full destination search / keyboard-heavy place browsing (use full search).
- Receipt, ratings history, wallet top-up, support tickets.
- Dense chrome that covers the map (keep map readable for pin/route trust).
- Duplicate map controls as a second UI — map owns location; sheet owns choice/status.

## Rules of thumb

1. **One job per step** — don’t mix product selection with destination editing or receipt.
2. **Map stays visible** from route preview through in-trip; hide it only for search and receipt.
3. **Color = signal** — status (matched, surge, SOS), not decoration.
4. **Primary CTA** sits at the bottom of the sheet; one clear verb.
5. Sheets are **transient** — not a place for account, history, or deep links that need Back stacks.
