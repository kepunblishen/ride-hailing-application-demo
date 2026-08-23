# VUUM RFQ — 204-reference status matrix (§77)

**Source RFQ:** `VUUM Ride Universal Vendor RFQ.docx` (VUUM-RFQ-2026-UNI)  
**Companion scope:** [`RFQ_REQUIREMENTS_AND_DEMO_SCOPE.md`](RFQ_REQUIREMENTS_AND_DEMO_SCOPE.md)  
**Gap tracker:** [`DIRECTIVE_GAP_STATUS.md`](DIRECTIVE_GAP_STATUS.md)  
**Date:** 2026-08-23  
**Surface audited:** iOS **rider** presentation client under `ios/Vuum/`

## Honesty rules

| Status | Meaning |
|--------|---------|
| **done** | (= Implemented) Rider-facing behaviour exists and is usable in the walkthrough (local/mock data OK). |
| **partial** | (= Partially Implemented) Present but thin, simulated, shell-only, or incomplete vs RFQ acceptance. |
| **prepared** | (= Architecturally Prepared) Types, stores, or hooks exist so a real backend can plug in; little or no full UX. |
| **missing** | (= Missing) Not built in this repo (and in scope for rider or clearly called out as gap). |
| **n/a** | (= Not Applicable to Rider iOS Presentation) Driver app, admin/dispatcher, corporate/safety/field-sales **web** portals, cloud/ops, or commercial delivery — not claimed for this iOS rider build. |

Do **not** read **done** as “production backend live.” Maps/Places/Routes still need a Google API key (`docs/GOOGLE_MAPS_SETUP.md`).

## Count note (204 vs extract)

RFQ narrative: **100 + 64 + 27 + 13 = 204**.  
Extracted unique keys in `.tmp-rfq/refs_204.json`: **206** (shared-cell duplicates such as A26/A27/A28 bonus, A34/A36 heat-maps, T04/T05 hosting, D01/D02 KYC). This matrix lists **all 206 extracted keys** so nothing is silently dropped; treat shared-cell siblings as one commercial obligation.

| Bucket | Extracted rows |
|--------|---------------:|
| done | 33 |
| partial | 76 |
| prepared | 21 |
| missing | 0 |
| n/a | 76 |
| **Total rows** | **206** |

### Rider-relevant only (excludes n/a)

| Status | Count |
|--------|------:|
| done | 33 |
| partial | 76 |
| prepared | 21 |
| missing | 0 |
| **Subtotal** | **130** |

### By module

| Module | done | partial | prepared | missing | n/a | rows |
|--------|-----:|--------:|---------:|--------:|----:|-----:|
| M1 Core | 20 | 31 | 6 | 0 | 45 | 102 |
| M2 Corporate | 7 | 31 | 8 | 0 | 18 | 64 |
| M3 Trust & Safety | 6 | 10 | 2 | 0 | 9 | 27 |
| M4 Field sales | 0 | 4 | 5 | 0 | 4 | 13 |

## Executive read for sales walkthrough

**Strong on device (done):** core book→match→trip→rate, dual-currency fares, SOS, trip share, trusted contacts, trip-start PIN, branding, promo codes, cash, multi-stop/wait charge, executive meet-and-greet, incident report, in-trip audio-only (local).

**Expect partial talk-track:** languages (FR/EN/LN/SW incomplete literals), scheduled rides, chat/call (no masked VoIP), mobile money/card shells, corporate employee shell, field-sales referral commission (local), courier/grocery/food/hotel/group/airport product sheets, USSD dial sheet, fare suggest, TVA/CO₂ lines, driver speed/trust badges, flight status (local), surge (rider-visible, not admin-triggered).

**Do not claim:** driver app, admin/dispatcher, safety console cloud retention, corporate invoices/reports portal, full food marketplace / merchant ops, live payment/flight gateways, App Store listing.

---

## Module 1 — Core ride-hailing

| Ref | Pri | Title | Status | Screens / services | Notes |
|-----|-----|-------|--------|--------------------|-------|
| M1:A01 | MUST | Full driver management | **n/a** | — | Admin driver management |
| M1:A02 | MUST | Full rider management | **n/a** | — | Admin rider management |
| M1:A03 | MUST | Live ride-tracking dashboard | **n/a** | — | Admin live ride dashboard |
| M1:A04 | MUST | Configurable dispatch rules | **n/a** | — | Dispatch rules console |
| M1:A05 | MUST | Driver queueing in high-demand zones | **prepared** | ServiceZoneCatalog high-demand zones | Hot zones exist for rider surge/context; no driver queue admin |
| M1:A06 | MUST | Admin-editable pricing configuration | **prepared** | PricingEngine, PricingRateCard, MockFares | Local rate cards; not admin-editable console |
| M1:A07 | MUST | Commission structure configuration | **n/a** | — | Commission config admin |
| M1:A08 | MUST | Commission split for partner/fleet-owner model | **n/a** | — | Fleet-owner commission split |
| M1:A09 | HIGH | Airport / premium transfer zone | **partial** | ServiceZoneCatalog, AirportProductSheet, MockSurge airport | Airport/premium zone + product sheet; not admin zone editor |
| M1:A10 | MUST | Admin-triggered surge pricing | **partial** | MockSurge, TripSession.surgeState, choose-ride surge UI | Rider sees surge; admin trigger console absent |
| M1:A11 | MUST | Promo, referral and discount engine | **done** | PromoCodesStore, PromoCodesView, TripSession.promo | Promo/referral discount at checkout (local) |
| M1:A12 | MUST | Dual currency display (USD + CDF) | **done** | Money / dual display | Same as R09 — rider dual currency |
| M1:A13 | MUST | Admin-controlled exchange rate | **prepared** | ExchangeRateConfiguration | FX rate configurable in code/config; no admin UI |
| M1:A14 | MUST | Per-transaction dual-currency storage | **done** | FareBreakdown, TripReceipt, PaymentTransaction | Dual amounts stored on trip/payment records locally |
| M1:A15 | MUST | Mobile money payment (e.g. Airtel Money) | **partial** | PaymentProviders, LinkMobileMoneyShellView, PaymentMethod | Airtel Money adapter + link shell; no live MM API |
| M1:A16 | MUST | Second mobile money provider (e.g. Orange Money DRC) | **partial** | PaymentProviders, Orange Money method | Orange Money adapter + UI; no live MM API |
| M1:A17 | MUST | Cash reconciliation dashboard | **n/a** | — | Cash reconciliation dashboard |
| M1:A18 | MUST | Driver payout management | **n/a** | — | Driver payout management |
| M1:A19 | MUST | Financial audit log | **n/a** | — | Financial audit log (admin) |
| M1:A20 | MUST | Card payment processing | **partial** | AddCardShellView, PaymentProviders card | Card method + add-card shell; no DRC gateway |
| M1:A22 | HIGH | Driver-to-vehicle assignment | **n/a** | — | Fleet vehicle assignment |
| M1:A23 | HIGH | Daily fleet payment tracking | **n/a** | — | Fleet daily payment tracking |
| M1:A24 | HIGH | Vehicle maintenance log and scheduling | **n/a** | — | Vehicle maintenance log |
| M1:A25 | HIGH | Fleet utilisation analytics | **n/a** | — | Fleet utilisation analytics |
| M1:A26 | HIGH | Configurable driver bonus system | **n/a** | — | Driver bonus system (admin) |
| M1:A27 | HIGH | Configurable driver bonus system | **n/a** | — | Driver bonus system (admin) |
| M1:A28 | HIGH | Configurable driver bonus system | **n/a** | — | Driver bonus system (admin) |
| M1:A29 | MUST | Ghost-trip detection | **prepared** | DiagnosticsToolsView SuspiciousTripFlagsView, RouteDeviationMonitor | Rider diagnostics / deviation flags; not admin ghost-trip engine |
| M1:A30 | MUST | GPS route fraud detection | **prepared** | RouteDeviationMonitor | Client-side deviation sensing; not admin fraud console |
| M1:A31 | MUST | Instant driver suspension | **n/a** | — | Instant driver suspension |
| M1:A32 | MUST | Complete admin audit trail | **n/a** | — | Admin audit trail |
| M1:A33 | MUST | Business intelligence dashboard | **n/a** | — | BI dashboard |
| M1:A34 | MUST | Demand heat-maps (admin) | **n/a** | — | Admin demand heat-maps |
| M1:A35 | HIGH | Per-driver performance dashboard | **n/a** | — | Per-driver performance dashboard |
| M1:A36 | MUST | Demand heat-maps (admin) | **n/a** | — | Admin demand heat-maps |
| M1:A37 | HIGH | Anonymous complaint channel | **partial** | SupportCenterView, IncidentReportView | Rider complaint/incident channels; not anonymous admin mediation |
| M1:A38 | HIGH | In-platform mediation workflow | **n/a** | — | Ops mediation console — not rider iOS |
| M1:D01 | MUST | Driver KYC onboarding | **n/a** | — | Driver KYC onboarding (driver app) |
| M1:D02 | MUST | Driver KYC onboarding | **n/a** | — | Driver KYC onboarding (driver app) |
| M1:D03 | HIGH | Driver offline-status reasons | **n/a** | — | Driver offline reasons |
| M1:D04 | MUST | Accept/reject countdown timer | **partial** | SearchingFlowView, TripSession matchingStatus | Rider sees search→assign timing; accept/reject timer is driver-side |
| M1:D05 | MUST | Auto-reassignment on timeout | **partial** | TripSession search reattempt / no-drivers path | Rider-side re-search UX; true auto-reassign is dispatch |
| M1:D06 | MUST | In-app driver navigation | **n/a** | — | In-app driver turn-by-turn |
| M1:D07 | MUST | OTP trip start | **done** | boardingPINEntry, ActiveTripFlowView / trip-start PIN | Rider-entered trip-start OTP/PIN before start |
| M1:D08 | MUST | Passenger detail visibility for third-party bookings | **done** | TripSession passengerName/phone, bookForSomeoneElse | Passenger details captured for third-party |
| M1:D09 | MUST | Driver earnings dashboard | **n/a** | — | Driver earnings dashboard |
| M1:D10 | MUST | Separate cash vs digital balance | **n/a** | — | Driver cash vs digital balance |
| M1:D11 | MUST | French UI (primary language) | **partial** | L10n FR | Shared French requirement; rider partial coverage |
| M1:D12 | HIGH | Lingala voice prompts (driver app) | **n/a** | — | Driver Lingala voice prompts |
| M1:D13 | MUST | Kiswahili UI | **partial** | L10n SW | Shared Kiswahili; rider partial |
| M1:D14 | MUST | Low-data / lite mode | **partial** | AppPreferences.lowDataMode, TripMapLayer, VuumMapView | Rider lite map + traffic off; driver-app lite N/A |
| M1:D15 | HIGH | Driver offline-status reasons | **n/a** | — | Driver offline reasons |
| M1:D16 | HIGH | Driver-to-vehicle assignment | **n/a** | — | Driver-to-vehicle assignment (fleet) |
| M1:D17 | MUST | Driver wallet and withdrawal requests | **n/a** | — | Driver wallet/withdrawals |
| M1:D20 | MUST | Earnings transparency | **n/a** | — | Driver earnings transparency |
| M1:D22 | HIGH | Driver behaviour analytics | **n/a** | — | Driver behaviour analytics |
| M1:D23 | MUST | Penalty and suspension | **n/a** | — | Driver penalty/suspension admin |
| M1:D24 | MUST | Demand heat-maps (driver) | **n/a** | — | Driver demand heat-maps |
| M1:F01 | MEDIUM | Food delivery module | **partial** | FoodProductSheet, ServicesHubView, ProductCatalogTiers.food | Food order sheet (restaurants/menu cart → address → ETA/fare → TripSession); not a full marketplace |
| M1:F02 | MEDIUM | Grocery / local marketplace module | **partial** | GroceryProductSheet, ServicesHubView | Grocery order sheet + tile; not a full marketplace |
| M1:F03 | MEDIUM | Parcel / logistics module | **partial** | CourierProductSheet, ProductBookingForm | Courier/parcel product shell only |
| M1:F04 | MEDIUM | Unified super-app wallet | **partial** | WalletSettingsView, PaymentHubView | Rider wallet shell; not unified super-app wallet |
| M1:F05 | HIGH | Advance booking for premium transfers | **partial** | AirportProductSheet, ScheduleRideSheet, ExecutiveProductSheet | Advance/airport/executive booking UX; not full premium transfer ops |
| M1:F06 | MEDIUM | Hotel/hospitality integration | **partial** | HotelTransferProductSheet, ServicesHubView | Hotel transfer sheet (guest/room/lobby); no PMS |
| M1:F07 | MEDIUM | AI demand prediction and automated surge | **prepared** | MockSurge, ServiceZoneCatalog | Zone/surge simulation; no AI demand prediction |
| M1:F08 | MEDIUM | Ride-sharing / carpooling | **partial** | GroupRideProductSheet | Group ride product shell; not full carpool marketplace |
| M1:R01 | MUST | OTP login — rider and driver | **done** | AuthFlowView, OTPVerifyView, SessionStore, AuthFlowController | Local OTP session; not real SMS gateway |
| M1:R02 | MUST | GPS pickup/drop-off selection | **done** | DestinationScaffoldView, AdjustPickupSheet, VuumMapView, RiderLocationManager, ReverseGeocodingService | Pin/GPS + Places when keyed; CLGeocoder fallback |
| M1:R03 | MUST | Real-time fare estimate | **done** | PricingEngine, MockFares, RideOptionsScaffoldView, TripSession.farePreview | Estimate before confirm; updates on route/dest change |
| M1:R04 | MUST | Real-time driver tracking | **done** | ActiveTripFlowView, TripSession motion, VuumMapView | Simulated live marker path (<5s feel); not real driver GPS feed |
| M1:R05 | MUST | Driver profile shown to rider | **done** | DriverCardViews, DriverProfile, SearchingFlowView, ActiveTripFlowView | Name/photo/vehicle/plate/rating on match + trip |
| M1:R06 | MUST | Trip history with fare breakdown | **done** | ActivityHubView, TripHistoryStore, TripReceipt | History + itemised fare; local persistence |
| M1:R07 | MUST | Two-way ratings | **partial** | TripCompleteFlowView, PostTripFeedback | Rider→driver rating/tags/tip; driver→rider not a full two-way product surface |
| M1:R08 | MUST | Cash payment | **done** | PaymentMethod.cash, PaymentMethodStore, choose-ride payment row | Cash selectable end-to-end in booking |
| M1:R09 | MUST | Dual currency display (USD + CDF) | **done** | Money, MoneyPair, CurrencyConfiguration, fare UI | USD + CDF display throughout fares |
| M1:R10 | MUST | Book for self or another person | **done** | TripSession.bookForSomeoneElse, RideOptionsScaffoldView | Passenger name/phone for third-party booking |
| M1:R11 | MUST | Ride cancellation with configurable window | **done** | CancellationPolicy, CancelTripSheet, TripSession | Window + fee logic |
| M1:R12 | MUST | Cancellation reason capture | **done** | CancelTripSheet, CancellationRecord | Reason capture on cancel |
| M1:R13 | MUST | French UI (primary language) | **partial** | AppLanguage, L10n, AppPreferences | FR primary in architecture; many flow strings still English literals |
| M1:R14 | MUST | English UI | **partial** | AppLanguage, L10n | EN present; incomplete string coverage |
| M1:R15 | MUST | Lingala UI | **partial** | AppLanguage.ln, L10n | Lingala selectable; incomplete string coverage |
| M1:R16 | MUST | Kiswahili UI | **partial** | AppLanguage.sw, L10n | Kiswahili selectable; incomplete string coverage |
| M1:R17 | HIGH | Lingala voice prompts (driver app) | **n/a** | — | Driver-app Lingala voice prompts |
| M1:R18 | MUST | Low-data / lite mode | **partial** | AppPreferences.lowDataMode, TripMapLayer, VuumMapView | Preferences toggle; simplified polyline + traffic off |
| M1:R19 | MUST | SOS — rider app | **done** | SOSConfirmationSheet, SafetyToolkitView, TripSession.sosRequested | Visible SOS with local safety-team notify simulation |
| M1:R20 | MUST | In-app chat / masked calling | **partial** | DriverChatView, ActiveTripFlowView call affordance | In-app chat UI; call is device dialer / no real masked VoIP |
| M1:R21 | MEDIUM | USSD booking fallback | **partial** | USSDBookingView, SupportHomeView | Dialable short-code sheet; no carrier USSD gateway |
| M1:R22 | MUST | Scheduled / pre-booked rides | **partial** | ScheduleRideSheet, ReservedTripStore, ActivityHubView | Reserve + list/cancel; edit/reminders thinner than Uber |
| M1:R23 | MUST | Multi-stop trips with waiting charge | **done** | TripSession.stops, pickupWaitChargeLocal, DestinationScaffoldView | Multi-stop + waiting charge simulation |
| M1:R26 | MUST | Transparent itemised pricing | **done** | FareBreakdown, RideOptionsScaffoldView, ActivityHubView receipts | Base/km/min/surge/toll itemisation |
| M1:R27 | MUST | Fare negotiation (optional) | **partial** | TripSession negotiate fare, RideOptionsScaffoldView | Suggest-a-fare ±15% on choose-ride; local only |
| M1:T01 | MUST | Rider app — Android & iOS | **partial** | ios/Vuum (rider), AuthFlow*, OTPVerifyView | iOS rider app buildable; not App Store / Android |
| M1:T02 | MUST | Driver app — Android & iOS | **n/a** | — | Driver store apps out of presentation scope |
| M1:T03 | MUST | Dispatcher web console | **n/a** | — | Admin / dispatcher web consoles out of scope |
| M1:T04 | MUST | Client-owned cloud hosting | **n/a** | — | Client cloud hosting is delivery/ops, not rider client |
| M1:T05 | MUST | Client-owned cloud hosting | **n/a** | — | Client cloud hosting is delivery/ops, not rider client |
| M1:T06 | MEDIUM | Investor-grade data export package | **n/a** | — | Investor/admin export package out of scope |
| M1:T07 | MUST | Source code ownership | **n/a** | — | Commercial source-ownership obligation, not an app feature |
| M1:T09 | MUST | Scalability test | **n/a** | — | Load-test report is ops deliverable |
| M1:T10 | MUST | Multi-city configuration | **partial** | AppLocale, MockPlaces, ServiceZoneCatalog | Lubumbashi/Kolwezi (+ Kenya room) markets; not full admin multi-city console |
| M1:T12 | MUST | Low-data / lite mode | **partial** | AppPreferences.lowDataMode, VuumMapView | Same rider lite map mode as R18/D14 |
| M1:T15 | MUST | Client branding applied | **done** | SplashView, AppIcon, VuumTheme, AuthChrome | Vuum branding on rider client; driver/web not in this build |

---

## Module 2 — Corporate (B2B)

| Ref | Pri | Title | Status | Screens / services | Notes |
|-----|-----|-------|--------|--------------------|-------|
| M2:A01 | MUST | Separate corporate admin login | **n/a** | — | Corporate admin portal login |
| M2:A02 | MUST | Employee management | **n/a** | — | Corporate employee management console |
| M2:A03 | MUST | Pre-booking management | **partial** | ReservedTripStore, ScheduleRideSheet, BusinessProfileView | Rider/pre-book list; not corp admin pre-book console |
| M2:A04 | MUST | Real-time ride monitor | **n/a** | — | Corporate real-time ride monitor |
| M2:A05 | MUST | Client-configured spend alerts | **prepared** | MockCorporate spend limits, BusinessProfileView | Spend shown to employee; alert config is admin |
| M2:A06 | MUST | Report download centre | **n/a** | — | Corporate report download centre |
| M2:A07 | MUST | Billing history | **partial** | BusinessProfileView recent trips, ActivityHubView | Rider-facing trip list; not corporate billing history portal |
| M2:A08 | MUST | User permission tiers | **n/a** | — | Corporate permission tiers |
| M2:C01 | MUST | Corporate account creation | **partial** | MockCorporate, BusinessProfileView | Sample corporate account attached to rider; no create-account admin |
| M2:C02 | MUST | Sub-account creation | **prepared** | MockCorporate department/cost centre fields | Sub-account concepts in model; no portal |
| M2:C03 | MUST | Bulk employee onboarding | **n/a** | — | Bulk CSV employee onboarding |
| M2:C04 | MUST | Per-employee spend limits | **partial** | MockCorporate.monthlySpendLimitCDF, BusinessProfileView | Limit displayed + blocks company wallet when exhausted |
| M2:C05 | MUST | Corporate billing/cost-centre code | **partial** | MockCorporate.costCentre, tripPurpose | Cost centre shown; booking can tag purpose |
| M2:C06 | MUST | Instant employee deactivation | **n/a** | — | Instant employee deactivation (admin) |
| M2:C07 | MUST | Corporate account dashboard | **partial** | BusinessProfileView | Employee dashboard shell (spend, wallet, VIP) |
| M2:C08 | MUST | Monthly consolidated invoice | **n/a** | — | Monthly consolidated invoice PDF/CSV |
| M2:D01 | HIGH | Corporate-ride indicator | **prepared** | TripSession.bookOnCompanyWallet / vip flags | Corporate-ride indicator for rider booking; driver badge is driver-app |
| M2:D02 | HIGH | Pre-booking notification | **partial** | NotificationStore, reserved trip confirmations | Local reservation notifications; not driver corp pre-book push |
| M2:D03 | HIGH | Dress-code reminder | **n/a** | — | Driver dress-code reminder |
| M2:D04 | HIGH | Corporate-ride earnings premium | **n/a** | — | Driver corporate earnings premium |
| M2:D05 | HIGH | Silent-mode prompt for premium rides | **partial** | TripSession.preferQuietRide, Ride preferences | Quiet/silent preference on rider side |
| M2:D06 | HIGH | Wait-and-return rides | **partial** | HourlyProductSheet, wait charge | Hourly / wait patterns; not full wait-and-return product |
| M2:O01 | MUST | Bulk SMS onboarding from employee CSV | **n/a** | — | Bulk SMS from CSV |
| M2:O02 | MUST | Corporate code registration at signup | **prepared** | RecruitmentSource.corporateInvite, FieldSalesModels | Invite/source types exist; no corp-code signup UX |
| M2:O03 | MUST | WhatsApp onboarding link | **partial** | CorporateOnboardingView | Opens WhatsApp with pre-filled join request |
| M2:O04 | MUST | QR code onboarding | **partial** | CorporateOnboardingView | Paste/apply VUUM-CORP QR payload; camera scan deferred |
| M2:O05 | MUST | Language selection at first launch | **done** | AppPreferences language, GetStarted/Welcome | Language selection in app preferences / first-run path |
| M2:O06 | MUST | Branded welcome screen | **done** | WelcomeView, SplashView | Branded welcome |
| M2:P01 | HIGH | Invoice / on-account payment mode | **partial** | bookOnCompanyWallet, BusinessPaymentProfileShellView | On-account via company wallet toggle; not full invoice mode |
| M2:P02 | HIGH | Pre-paid credit balance | **partial** | MockCorporate.companyWalletBalanceCDF | Prepaid balance shown locally |
| M2:P03 | HIGH | Corporate wallet top-up by bank reference | **partial** | BankReferenceTopUpView, BusinessProfileView | Bank reference + local credit; no live bank webhook |
| M2:P04 | HIGH | Dual-currency invoicing (USD + CDF) | **prepared** | Money dual currency + corporate models | Dual currency ready; invoice docs not generated |
| M2:P05 | HIGH | DRC TVA-compliant tax line | **partial** | PricingRateCard taxRate 16%, fare/receipt TVA line | DRC TVA 16% on fares/receipts; not fiscal e-invoice |
| M2:P06 | HIGH | Credit-limit enforcement with grace ride | **partial** | remainingSpendCDF gate on company wallet | Limit enforcement; no grace-ride policy engine |
| M2:P07 | HIGH | Spend-alert notifications | **prepared** | NotificationStore | Infra for alerts; corp spend-alert rules not wired |
| M2:R01 | HIGH | Monthly per-employee trip report | **n/a** | — | Monthly per-employee report (portal) |
| M2:R02 | HIGH | Department spend report | **n/a** | — | Department spend report |
| M2:R03 | HIGH | Night-ride safety report | **n/a** | — | Night-ride safety report |
| M2:R04 | HIGH | Route analysis | **n/a** | — | Route analysis report |
| M2:R05 | HIGH | Carbon/emissions estimate per trip | **partial** | TripEmissions, PostTripCompleteView, ActivityHubView | CO₂ estimate on fare preview/receipts; factors are local |
| M2:R06 | HIGH | Real-time spend dashboard | **partial** | BusinessProfileView spend meters | Employee real-time spend view only |
| M2:R07 | HIGH | Automated monthly email report | **n/a** | — | Automated monthly email |
| M2:R08 | HIGH | Year-to-date spend summary | **partial** | BusinessProfileView used/remaining | YTD-style summary thin / monthly only |
| M2:S01 | MUST | Live journey-share link | **done** | TripShare, SafetyToolkitView, ActiveTripFlowView | Live journey-share message/URL |
| M2:S02 | MUST | SOS with broadcast to a corporate safety number | **partial** | SOSConfirmationSheet, TrustedContactsStore | SOS + contacts; dedicated corporate safety number broadcast is simulated |
| M2:S03 | MUST | Driver background-check flag | **partial** | DriverProfile.backgroundCheckPassed, DriverCardView | Background-check chip on driver card (local flags) |
| M2:S04 | MUST | Vehicle inspection status per driver | **partial** | DriverProfile.vehicleInspection, DriverCardView | Inspection status chip on driver card |
| M2:S05 | MUST | Rider-entered trip-start OTP | **done** | boarding PIN / trip-start OTP | Rider-entered trip-start OTP |
| M2:S06 | MUST | Trip-deviation alert | **partial** | RouteDeviationMonitor, TripSession.routeDeviationNotice | Deviation notice on rider; corporate alert pipeline absent |
| M2:S07 | MUST | Post-ride incident reporting | **done** | IncidentReportView, IncidentReportStore | Post-ride incident reporting (local) |
| M2:S08 | MUST | Driver speed monitoring | **partial** | TripSession.driverSpeedKmh, ActiveTripFlowView | Simulated live speed during approach/trip |
| M2:V01 | MUST | Dedicated premium vehicle tier | **done** | RideTier executive/Vuum Black, ExecutiveProductSheet | Dedicated premium/executive tier |
| M2:V02 | MUST | 24–72 hour pre-booking with confirmed driver | **partial** | ExecutiveProductSheet, ScheduleRideSheet, startExecutiveMeetAndGreetBooking | Advance executive booking UX; confirmed-driver ops simulated |
| M2:V03 | MUST | Driver bio shared in advance | **partial** | DriverProfile.bio, DriverCardView | Bio on match/card; advance SMS/email not real |
| M2:V04 | MUST | Flight-tracking integration | **partial** | AirportProductSheet flight status | Local flight board from flight number; no live API |
| M2:V05 | MUST | Meet-and-greet option | **done** | meetAndGreetEnabled, ExecutiveProductSheet | Meet-and-greet option with sign name |
| M2:V06 | MUST | Separate VIP billing line | **partial** | vipExecutiveTransfer, BusinessProfileView VIP billing cues | VIP line conceptual; not separate invoice system |
| M2:V07 | MUST | Rated premium driver pool | **partial** | MockDrivers ratings / executive pool selection | High-rated drivers preferred in mock; not vetted pool admin |
| M2:X01 | HIGH | Data residency confirmation | **prepared** | PrivacySettingsView, AboutLegalView | Privacy copy; residency attestation is commercial |
| M2:X02 | HIGH | Employee data deletion on account closure | **partial** | DeleteAccountView, PrivacySettingsView | Local delete-account path; not corp employee purge |
| M2:X03 | HIGH | Full audit log | **n/a** | — | Corporate full audit log |
| M2:X04 | HIGH | Data export | **partial** | PrivacySettingsView, trip history | Rider data export thin; corp export portal n/a |
| M2:X05 | HIGH | Strict role-based access control | **n/a** | — | Multi-tenant RBAC |
| M2:X06 | HIGH | Data-breach incident response protocol | **prepared** | AboutLegal / privacy docs | Breach protocol is policy text, not product engine |

---

## Module 3 — Trust & Safety

| Ref | Pri | Title | Status | Screens / services | Notes |
|-----|-----|-------|--------|--------------------|-------|
| M3:SA01 | MUST | Driver and rider activation | **partial** | TripAudioRecorder, SafetySettingsView | Rider can activate in-trip audio with notice; dual-party backend consent thin |
| M3:SA02 | MUST | Restricted staff access | **n/a** | — | Restricted Safety Team staff access (console) |
| M3:SA03 | MUST | Recording workflow | **partial** | TripAudioRecorder | On-device recording workflow; no cloud pipeline |
| M3:SA04 | MUST | No general-purpose recording | **done** | TripAudioRecorder scoped to trip | Recording tied to active trip, not general recorder |
| M3:SA05 | MUST | Automatic stop | **done** | TripAudioRecorder + trip phase end | Stops with trip lifecycle |
| M3:SA06 | MUST | Unique recording identification | **partial** | local recording identifiers | Local IDs; not SA07 cloud table |
| M3:SA07 | MUST | audio_recordings data table | **n/a** | — | audio_recordings DB table |
| M3:SA08 | MUST | Recording status lifecycle | **partial** | TripAudioRecorder states | Local status; not full retention lifecycle |
| M3:SA09 | MUST | Automatic safety-system activation | **partial** | SafetyAutoActivation, TripSession.applyAutomaticSafetyActivation | Night/long-trip auto-share + auto-record rules (local) |
| M3:SA10 | MUST | Secure object/file storage | **n/a** | — | Secure object storage (backend) |
| M3:SA11 | MUST | Security requirements | **prepared** | on-device only design | Security model = local; no cloud encryption pipeline |
| M3:SA12 | MUST | Recording playback, not download, by default | **n/a** | — | Safety console playback-not-download |
| M3:SA13 | MUST | Audio quality | **partial** | SafetyAutoActivation.AudioQuality, TripAudioRecorder, SafetySettingsView | Economy/standard/high sample-rate picker; not certified SLA |
| M3:SA14 | MUST | Audio only | **done** | TripAudioRecorder audio-only | Audio only (no video) |
| M3:SA15 | MUST | Incident reporting workflow | **done** | IncidentReportView, IncidentReportStore | Incident reporting workflow (local) |
| M3:SA16 | MUST | Configurable incident types | **partial** | IncidentCategory enum | Fixed categories in app; not admin-configurable |
| M3:SA17 | MUST | Safety & Incident Management admin dashboard | **n/a** | — | Safety & Incident admin dashboard |
| M3:SA18 | MUST | Incident status lifecycle | **partial** | IncidentReport status fields | Local lifecycle; not ops console |
| M3:SA19 | MUST | Full access audit log | **n/a** | — | Full access audit log (safety) |
| M3:SA20 | MUST | Configurable retention | **n/a** | — | Configurable retention (admin) |
| M3:SA21 | MUST | Automatic retention engine | **n/a** | — | Automatic retention engine |
| M3:SA22 | MUST | SOS / emergency workflow | **done** | SOSConfirmationSheet, TripSession SOS | SOS / emergency workflow on rider |
| M3:SA23 | MUST | Trip sharing with a trusted contact | **done** | TrustedContactsStore, TripShare, SafetyToolkitView | Trip sharing with trusted contact |
| M3:SA24 | MUST | Poor-connectivity handling | **partial** | NetworkReachability, VuumOfflineBanner | Poor-connectivity UI; no audio upload retry queue |
| M3:SA25 | MUST | Notification set | **partial** | NotificationStore | Local notification set; not full safety notify matrix |
| M3:SA26 | HIGH | Multi-country / multi-jurisdiction architecture | **prepared** | AppLocale markets KE/DRC | Multi-market locale; recording policy by jurisdiction not encoded |
| M3:SA27 | HIGH | Admin configuration surface | **n/a** | — | Safety admin configuration surface |

---

## Module 4 — Field sales growth

| Ref | Pri | Title | Status | Screens / services | Notes |
|-----|-----|-------|--------|--------------------|-------|
| M4:SE01 | MUST | Driver recruitment pipeline | **prepared** | FieldSalesModels, FieldSalesStore, FieldSalesPipelineView | Driver recruit pipeline models + diagnostics; not exec portal |
| M4:SE02 | MUST | Customer recruitment pipeline | **partial** | ReferFriendsView, FieldSalesStore, RecruitmentKind.rider | Rider referral / recruitment UX; not full field pipeline |
| M4:SE03 | MUST | Executive-assisted onboarding | **prepared** | FieldSalesModels executive-assisted source | Modelled; no assisted-onboarding UI |
| M4:SE04 | MUST | First-ride commission trigger | **partial** | CommissionState, EligibilityMilestone, FieldSalesStore | First-ride commission trigger logic (local) |
| M4:SE05 | MUST | Automated commission workflow | **partial** | FieldSalesStore commission workflow | Local automated state machine; no payout backend |
| M4:SE06 | MUST | Illustrative driver commission structure | **prepared** | FieldSalesModels illustrative structures | Illustrative driver commission in models/diagnostics |
| M4:SE07 | MUST | Illustrative customer commission structure | **prepared** | ReferFriendsView + commission models | Illustrative customer commission |
| M4:SE08 | MUST | Anti-fraud controls | **partial** | EligibilityMilestone gates, SuspiciousTripFlagsView | Local anti-fraud prerequisites before award |
| M4:SE09 | HIGH | Executive mobile portal | **n/a** | — | Executive mobile portal |
| M4:SE10 | HIGH | Executive performance dashboard | **n/a** | — | Executive performance dashboard |
| M4:SE11 | HIGH | Admin portal for the program | **n/a** | — | Admin portal for field-sales program |
| M4:SE12 | HIGH | KPI framework | **prepared** | FieldSalesChecklistView in diagnostics | KPI checklist in hidden diagnostics only |
| M4:SE13 | HIGH | Required database tables | **n/a** | — | Required DB tables (backend) |

---

## Missing (rider-relevant or explicit gaps)

| Ref | Pri | Title | Status | Screens / services | Notes |
|-----|-----|-------|--------|--------------------|-------|
| — | — | — | — | — | No rider-relevant **missing** rows remain in the 206-key extract. Depth gaps stay **partial** / **prepared** (see F01 food sheet vs full marketplace). |

Cleared in this wave (now **partial**): food delivery sheet, grocery, hotel transfer, USSD dial sheet, fare suggest, TVA 16%, CO₂ estimate, driver speed, flight status board, WhatsApp/QR corp join, bank-reference top-up, background-check + inspection chips, lite map mode, safety auto-activation + audio quality. A38 mediation reclassified **n/a** (ops console).

---

## Regeneration

Classification script: `.tmp-rfq/build_matrix.js` (from `refs_204.json`). Re-run after major feature waves and reconcile against `ios/Vuum/` before changing statuses upward.
