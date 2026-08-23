# VUUM RFQ — Requirements Extract & Presentation Scope

**Source:** `VUUM Ride Universal Vendor RFQ.docx`  
**RFQ ref:** VUUM-RFQ-2026-UNI · Issued 15 Aug 2026  
**Client:** Congo Mobility SARL (VUUM Ride) — Lubumbashi & Kolwezi, DRC  
**Sponsor:** Evans Otieno Okoth · okoth59@gmail.com · +254 725 145 760  

This file is the working checklist so the **iOS presentation build** (rider client) impresses the client while we stay clear: **no production database**, local/mock trip and auth data, real **Maps + location + permissions**.

**Presentation geography:** product markets in the walkthrough are **DRC** (Lubumbashi / Kolwezi places, dual currency USD + CDF). Sales/sponsor context is **Kenya** (+254). The room may be Kenya; the map and trip story stay DRC.

**§77 status matrix:** per-reference done / partial / prepared / missing / n/a → [`RFQ_204_MATRIX.md`](RFQ_204_MATRIX.md).

---

## 1. What the client is buying (four modules)

| Module | Focus | Refs | MUST | HIGH | MEDIUM |
|--------|--------|------|------|------|--------|
| **1. Core ride-hailing** | Rider + driver apps, dispatcher, admin, fares, payments, localisation | 100 | 70 | 18 | 12 |
| **2. Corporate (B2B)** | Mining/employer accounts, billing, VIP transfers, safety, portal | 64 | 37 | 27 | 0 |
| **3. Trust & Safety** | In-trip audio, incidents, SOS, trip share, retention | 27 | 25 | 2 | 0 |
| **4. Field sales growth** | Recruit drivers/riders; commission on first completed ride | 13 | 8 | 5 | 0 |
| **Total** | | **204** | **140** | **52** | **12** |

**Priority meaning (RFQ):** MUST before a credible pilot; HIGH before formal anchor-client contract; MEDIUM within ~90 days / later phase.

**Delivery windows they care about:** MUST at contract → HIGH for Day 1–15 pilot → remaining HIGH by ~60 days → MEDIUM by ~90 days.

---

## 2. Coverage of this presentation build

| Surface | In this iOS build? | Notes |
|---------|--------------------|--------|
| **Rider client** | **Yes — primary** | Splash → auth → map home → book → match → trip → rate → account |
| **Driver app** | **Out of scope** | Talk-track / RFQ Module 1 only; no driver store build |
| **Admin / dispatcher** | **Out of scope** | Web consoles are real-product later; optional UI shell only if needed for story |
| **Corporate portal** | **Out of scope** | Module 2 = slide + optional lightweight shell later |
| **Safety console / audio** | **Out of scope** | Rider-side SOS / trip-share / OTP-to-start cues only |
| **Field sales engine** | **Out of scope** | Module 4 = proposal talk-track |

We quote the full 204-ref RFQ; we **ship** a polished **rider** walkthrough that proves Module 1 consumer UX on device.

**Coverage matrix (status per ref):** see [`RFQ_204_MATRIX.md`](./RFQ_204_MATRIX.md) — every Module:Ref mapped to `ios/Vuum/` surfaces with **done** / **partial** / **prepared** / **missing** / **n/a** (directive: Implemented / Partially Implemented / Architecturally Prepared / Missing / N/A).

---

## 3. Module 1 — Core ride-hailing (everything they need)

### Platform & ownership
- Rider **and** driver apps on **Android + iOS** (stores)
- Admin panel + **dispatcher** web console (live map, manual assign, phone booking)
- Branding (logo, colours, name) across apps
- Client-owned cloud (AWS/DO), domain + SSL, full data export, **100% source ownership**, scalability test (~200 rides/s), multi-city (Lubumbashi / Kolwezi)

### Trip booking, tracking & fares
- OTP login (rider + driver)
- GPS pickup/drop (pin drag, live address)
- Real-time fare estimate; itemised base + km + minute
- Live driver tracking (&lt;5s latency)
- Driver profile (name, photo, vehicle, rating)
- Trip history; two-way ratings
- Book for self **or another person**
- Cancel window + fee + reason capture
- SOS; in-app chat / **masked calling**
- Driver accept/reject timer + auto-reassign
- In-app turn-by-turn (e.g. Google Maps)
- **OTP to start trip**; passenger details for third-party bookings
- Scheduled rides; multi-stop + waiting charge; optional fare negotiation

### Payments & currency
- Cash; mobile money (Airtel + Orange DRC); cards via DRC gateway
- **Dual currency USD + CDF**; admin FX rate; both stored per trip
- Surge by zone; promo / referral / discount engine

### Localisation
- **French (primary)**, English, Lingala, Kiswahili — complete
- Low-data / lite mode (2G/3G)

### Admin, dispatch, fraud
- Driver/rider management; live ride map; dispatch rules; hot-zone queues
- Pricing & commission (incl. fleet-owner split)
- Cash reconciliation; payouts; financial + admin audit logs
- Instant suspension; BI dashboard; demand heat-maps (admin + driver)
- Ghost-trip + GPS route fraud detection

### Driver tools
- Earnings (cash vs digital); wallet/withdrawals; KYC; penalties; transparent net earnings

### Fleet / premium / growth (HIGH+)
- Fleet owner panel, vehicles, assignment, utilisation
- Independent driver self-reg; offline reasons; bonus system
- Airport / premium transfer zone + advance booking
- Accounting/ERP sync (HIGH)
- Voice prompts Lingala/Kiswahili; behaviour analytics; maintenance; complaints; mediation
- MEDIUM: food, grocery, parcel, carpool, super-app wallet, USSD, AI surge, hotel, franchise, extra cities, investor export

---

## 4. Module 2 — Corporate (B2B)

- Corporate accounts, sub-accounts, bulk CSV onboarding, spend limits, cost centres
- Deactivate employees; live corporate dashboard; monthly invoices PDF/CSV
- On-account / prepaid / bank top-up; dual-currency invoices; DRC TVA; credit limits; spend alerts
- **Executive / VIP tier:** vetted pool, 24–72h pre-book with confirmed driver, bio SMS/email, flight tracking, meet-and-greet, VIP billing line, 4.5+ drivers
- Reports: per-employee, department, night rides, routes, CO₂, real-time spend, auto monthly email, YTD
- Safety: journey share, SOS to corporate number, background-check flags, inspection status, **rider-entered trip-start OTP**, deviation alerts, incident reporting, speed monitoring
- Separate corporate admin portal (not ops admin); permission tiers
- Driver: corporate badge, pre-book reminders, dress-code, earnings premium, silent mode, wait-and-return
- Onboarding: bulk SMS, corporate code, WhatsApp link, QR, **language first launch**, branded welcome
- Privacy: residency, deletion, audit, export, multi-tenant segregation, breach protocol

---

## 5. Module 3 — Trust & Safety (audio + incidents)

- In-trip **audio** only (not covert; both parties notified; auto-stop at trip end)
- Restricted Safety Team access; secure storage; playback-not-download default
- Incident types + Safety console; retention/deletion engine
- SOS workflow; **trip sharing** with trusted contact; poor-network retry for uploads
- Multi-country recording policy (DRC → Zambia later)

---

## 6. Module 4 — Field sales growth engine

- Recruit drivers & riders; status pipelines
- Commission **only after first completed genuine ride** (anti-fraud)
- Executive mobile portal + admin program tools + KPI targets

---

## 7. Commercial questions they will ask (Section 7)

Answer in any proposal: hosting country / Africa-EU option; DRC TVA; breach 24h/72h; multi-tenant segregation; **rider** OTP to start; source ownership; Year-2 maintenance; MUST in 4 weeks / HIGH in 8 weeks?; audio consent by jurisdiction; security testing cadence.

---

## 8. Presentation build — rider client vs later

Legend: **Ship in iOS presentation** · **UI shell / talk-track** · **Real product only**

### Ship in presentation (rider client)

| RFQ theme | Presentation behaviour |
|-----------|------------------------|
| Branding T15 | ✅ Vuum splash (light/dark), AppIcon, AccentColor; auth buttons use catalog icons or SF Symbol fallbacks |
| Rider OTP auth R01 | Mobile number flow + session flag (local); Kenya (+254) default for sponsor-room UX; DRC market copy on map |
| Map pickup/drop R02 | Google Maps + Core Location + pin UX (Lubumbashi / Kolwezi catalog) |
| Fare estimate R03 / R26 | Mock tiers + itemised breakdown + **USD + CDF** |
| Live driver R04 / R05 | Moving marker, **driver card** (photo/initials, rating, vehicle, plate), class ETA badge |
| Matching D04/D05 | Searching → assigned (timed UI); share / message / call on active trip |
| Trip complete + ratings R06/R07 | End screen + rate |
| SOS R19 / SA22 | Visible SOS control (local alert) |
| Chat/call R20 | UI present (no real VoIP yet) |
| OTP trip start D07 / S05 | Rider OTP UI before “start” |
| Premium tier V01 | “Vuum Black / Executive” tier on options |
| Languages O05 | Language picker or FR/EN toggle (expand to 4 later) |
| Location permissions | Real iOS “Allow While Using / Always” prompts |
| Cars on map | Local nearby vehicles (Uber-like) |

### Real free/cheap services allowed

- Google Maps SDK (map, markers, polyline, camera)
- Core Location (live GPS)
- Local persistence (session)
- Optional Places Autocomplete later if key budget allows

### Out of scope for this presentation build

- **Driver app** (store build, accept/reject, earnings, KYC)
- **Admin panel / dispatcher** backends and live ops consoles
- Real SMS OTP, Airtel/Orange Money, card gateway
- Corporate portal, invoices, bulk CSV, flight tracking
- Audio recording pipeline + Safety console
- Field sales commission engine
- Fleet owner systems, USSD, food/grocery modules
- Production cloud, multi-tenant DB, ERP sync

---

## 9. How we use this in the sales meeting

1. **Walk the rider journey** on a physical iPhone (Sideloadly IPA) — maps + permissions do the heavy lifting. Expect **Kenya room / DRC product map**.  
2. **Point at RFQ modules** on a slide: “Module 1 consumer rider live in your hand; driver + admin + Modules 2–4 are the stack we implement next against these reference numbers.”  
3. **Quote** using the same refs (T01, R04, C01, SA01…) — RFQ Section 9 expects that discipline.  
4. Never say “demo” on screen; treat every control as product. Internally call this a **presentation build**.

---

## 10. Suggested next build increments (still no DB)

1. **Next step — Google Maps API key only** — Info.plist / xcconfig / URL-query schemes / usage strings are ready. Set `VUUM_GOOGLE_MAPS_API_KEY` (Codemagic, scheme, or `Secrets.xcconfig`) so IPAs show live Maps; see [GOOGLE_MAPS_SETUP.md](GOOGLE_MAPS_SETUP.md)  
2. Dual-currency fare sheet + itemised breakdown  
3. SOS + trip-share sheet + rider trip-start OTP  
4. FR/EN (then Lingala/Kiswahili strings); confirm DRC (+243) in country picker alongside Kenya default  
5. Executive tier + “book for someone else” UI  
6. Lightweight “Corporate” tab as a **shell** that previews Module 2 story (still not admin/driver)
