# Codemagic — Vuum unsigned iOS build

Same approach as the Wells scaffold: Codemagic builds an unsigned `.ipa`; Sideloadly signs with a free Apple ID.

## One-time setup

1. Add this repo as an iOS app in Codemagic
2. Workflow: **ios-release** (`codemagic.yaml`)
3. Optional: set env var `VUUM_GOOGLE_MAPS_API_KEY` for live maps in CI builds
4. Start build → download `build/Vuum.ipa` → install via Sideloadly

## Local / scheme key

In Xcode scheme **Vuum** → Run → Arguments → Environment Variables:

`VUUM_GOOGLE_MAPS_API_KEY` = your Maps SDK key

Or add `GMSApiKey` to `Info.plist` (do not commit real keys).

## Project paths

| Item | Value |
|------|--------|
| Project | `ios/Vuum.xcodeproj` |
| Scheme | `Vuum` |
| Bundle ID | `com.vuum.demo` |
| Deployment | iOS 17+ |
