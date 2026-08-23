# QA Pass C — Account + Pay + Activity + Support

**Agent:** 21  
**Date:** 2026-08-23  
**Scope:** Account hub, wallet/payments, Activity (history/receipts), Help & support, referrals, corporate  
**Snyk:** not used  
**Commit:** none

## Verdict

Account / payments / activity / support / referrals / corporate are **wired and presentation-ready**. Remaining gaps are depth items (cancelled-trip filter, live payment gateways), not dead navigation.

## What was verified

| Area | Status | Notes |
|------|--------|--------|
| Account hub | Pass | Profile, wallet, methods, payment history, trip history → Activity, safety, trusted contacts, business, promos, referrals, settings, support, about, sign-out |
| Personal info | Pass | Edits persist via `SessionStore.updateProfile` |
| Wallet | Pass | Market balances; **Add funds** → `AddFundsShellView` / `PaymentMethodStore.addFunds`; methods + history links; default picker skips overwrite when company wallet is on |
| Payment methods | Pass | Default selection; unlinked MoMo / missing card opens link / add-card sheets; syncs `TripSession.paymentMethod` when not on company wallet |
| Payment hub / history | Pass | Ledger + detail (date, trip, amount, currency, method, status, refund note, receipt id) |
| Activity past | Pass | Time + product filters; receipt with fare lines, payment method, rebook / help / share |
| Activity upcoming | Pass | Reservations + cancel |
| Support | Pass | Directive categories; FAQ; composer; chat; phone/email |
| Referrals | Pass | Code, share, invite tracking, first-ride reward gate; push-safe from Account |
| Corporate | Pass | Spend limits, cost centre, company wallet + VIP wired into `TripSession` |
| Settings | Pass | Preferences, inbox, communications, saved places, privacy (delete account), accessibility, calendar, safety |

## Fixes touched in this pass

1. Wallet **Add funds** path (was empty / no-op in earlier revision) → `AddFundsShellView`.
2. Payment methods: link MoMo / add card when required before selecting.
3. Account → **Payment history** row into `PaymentHubView`.
4. Referrals: push-safe (no sheet-only Done / nested stack).
5. Safety tools: inactive share/chat no longer look actionable; share works on active trips.
6. Corporate VIP / company wallet bound to `TripSession`.
7. Activity receipts surface **payment method** on list, detail, and share text.

## Directive marks

- §74 Account checklist  
- Phase 5 Account ecosystem  
- Phase 7 Corporate / Phase 8 Referrals (confirmed)  
- Phase 9 → QA Pass C  
- Final review Account / Corporate / Field sales  

## Known gaps

- No dedicated cancelled-trip history filter (cancelled bookings are not receipted the same way as completed trips).  
- Payment providers are on-device adapters (no live MM/card settlement).  
- Support chat uses scripted replies; outbound messages persist locally.  
- Loyalty / promo UIs are product shells, not a server loyalty engine.

## Device smoke

- [ ] Edit profile → relaunch → persists  
- [ ] Wallet → Add funds → balance updates  
- [ ] Link MoMo → set default  
- [ ] Finish trip → Activity receipt shows payment method  
- [ ] Support → send message → listed under Your messages  
- [ ] Business → company wallet → ride pay shows company  
- [ ] Refer friends → copy / share  
