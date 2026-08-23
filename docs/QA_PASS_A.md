# QA Pass A — Auth → Home → Booking

Agent 19. Code-path audit + wiring fixes. Maps engine left alone.

## Verified

| Area | Result |
|------|--------|
| Splash → auth / home | `ContentView` gates on `SessionStore.isSignedIn` |
| Auth phone → OTP → terms → profile → welcome → sign-in | Wired; session includes email |
| Invalid / expired OTP | Controller validates last-4 phone OTP; 180s expiry; resend + backup `0000` |
| Sign out | Account clears session + trip draft; returns to Get Started |
| Home Where to? / pickup / schedule / suggestions | Opens destination, AdjustPickup, ScheduleRide, Services tab |
| Recents / saved | Market-aware places; select → choose ride |
| Choose ride → Confirm / Reserve | Tier, promo, payment, for-others gate via `canConfirmRequest` |
| Change destination | `changeDestination()` keeps intermediate stops |

## Fixes landed

- Wired OTP UI: errors, resend cooldown, backup sheet, digit paste, loading Next
- Added missing `L10n.Auth` error / backup strings
- Confirm info: name filter, optional email, profile errors
- Confirm CTA disabled until booking draft is complete (incl. someone-else fields)
- Eats list: removed fake chevrons (browse-only notice already present)

## Presenter notes

- OTP = **last 4 digits** of the national number entered (e.g. `…7890` → `7890`)
- Backup code = `0000`
- Promo codes: `VUUM10`, `WELCOME`
- Apple / Google / Email / Find account remain inert (no network auth)

## Out of scope / deferred

- Maps Places/Routes engine (other agents)
- Trip live states, Safety, cancellation deep-path (later QA passes)
- Real SMS provider
