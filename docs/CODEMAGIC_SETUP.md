# Codemagic — Raide unsigned iOS build

Same approach as the Wells scaffold: Codemagic builds an unsigned `.ipa`; Sideloadly signs with a free Apple ID.

## One-time setup

1. Add this repo as an iOS app in Codemagic
2. Workflow: **ios-release** (`codemagic.yaml`)
3. Optional: set env var `RAIDE_GOOGLE_MAPS_API_KEY` for live maps in CI builds
4. Start build → download `build/Raide.ipa` → install via Sideloadly

## Local / scheme key

In Xcode scheme **Raide** → Run → Arguments → Environment Variables:

`RAIDE_GOOGLE_MAPS_API_KEY` = your Maps SDK key

Or add `GMSApiKey` to `Info.plist` (do not commit real keys).

## Project paths

| Item | Value |
|------|--------|
| Project | `ios/Raide.xcodeproj` |
| Scheme | `Raide` |
| Bundle ID | `com.raide.demo` |
| Deployment | iOS 17+ |
