# Codemagic — Vuum unsigned iOS build

Same approach as the Wells scaffold: Codemagic builds an unsigned `.ipa`; Sideloadly signs with a free Apple ID. No Apple Developer Program membership is required for this path.

**Software side is ready.** Once `VUUM_GOOGLE_MAPS_API_KEY` is set as a secure Codemagic env var, CI injects it and the IPA ships with a live Maps key in Info.plist. Remaining steps are credential / console only (below).

No Snyk (or other security-scan) steps run in this workflow — see [NO_SNYK.md](NO_SNYK.md).

---

## One-time Codemagic setup

1. Add this GitHub repo as an iOS app in Codemagic
2. Select workflow **ios-release** from root `codemagic.yaml`
3. (Credential) Set secure env var `VUUM_GOOGLE_MAPS_API_KEY` — see [Remaining credential-only steps](#remaining-credential-only-steps)
4. Start build → download `build/Vuum.ipa` → install via Sideloadly

---

## What the workflow does

| Step | Purpose |
|------|---------|
| Inject Maps key | If `VUUM_GOOGLE_MAPS_API_KEY` is set, writes gitignored `ios/Secrets.xcconfig` (picked up by `Vuum.xcconfig` `#include?`) |
| Resolve SPM | ComponentsKit, Google Maps SDK, KeychainSwift |
| `xcodebuild build` | Unsigned Debug `iphoneos` build; also passes `VUUM_GOOGLE_MAPS_API_KEY` for Info.plist `$(VUUM_GOOGLE_MAPS_API_KEY)` substitution |
| Package IPA | Zips `Vuum.app` → `build/Vuum.ipa` for Sideloadly |

Without the env var, the **build still succeeds**; `MapBootstrap` treats an empty / placeholder key as missing and the UI shows the map-unavailable surface.

---

## Maps API key (Codemagic)

Scheme Run env alone is **not** enough for Sideloadly IPAs — the key must be baked at build time into Info.plist.

`codemagic.yaml` does both:

1. Writes `ios/Secrets.xcconfig` when the secure env var is present  
2. Passes `VUUM_GOOGLE_MAPS_API_KEY=…` on the `xcodebuild` command line  

`Info.plist` already has:

```xml
<key>VUUM_GOOGLE_MAPS_API_KEY</key>
<string>$(VUUM_GOOGLE_MAPS_API_KEY)</string>
```

Full Maps console guide: [GOOGLE_MAPS_SETUP.md](GOOGLE_MAPS_SETUP.md).

---

## Local / scheme key (Mac)

In Xcode scheme **Vuum** → Run → Arguments → Environment Variables:

`VUUM_GOOGLE_MAPS_API_KEY` = your Maps SDK key

Or:

```bash
cp ios/Secrets.example.xcconfig ios/Secrets.xcconfig
# edit ios/Secrets.xcconfig — never commit it
```

---

## Project paths

| Item | Value |
|------|--------|
| Workflow | `ios-release` |
| Project | `ios/Vuum.xcodeproj` |
| Scheme | `Vuum` |
| Bundle ID | `com.vuum.app` |
| Deployment | iOS 17+ |
| Artifact | `build/Vuum.ipa` |
| DerivedData (CI) | `build/DerivedData` |

Unit tests (`VuumTests`) are documented in [TESTING.md](TESTING.md). They are not part of the default IPA workflow.

---

## Remaining credential-only steps

These are **not** code changes. Do them in Google Cloud / Codemagic UI:

1. **Google Cloud** — project with billing; enable **Maps SDK for iOS** (Places / Routes later if needed)
2. **Create API key** — restrict to iOS apps + bundle ID `com.vuum.app`; API restriction → Maps SDK for iOS
3. **Codemagic** → Application → Environment variables → add:

   | Name | Secure | Used by |
   |------|--------|---------|
   | `VUUM_GOOGLE_MAPS_API_KEY` | Yes | `codemagic.yaml` inject + `xcodebuild` |

4. **Rebuild** → Sideload `build/Vuum.ipa` → confirm live map tiles (not “Map unavailable”)
5. **Optional later** — Places / Routes keys or expanded API restrictions (see [GOOGLE_MAPS_SETUP.md](GOOGLE_MAPS_SETUP.md))

Do **not** paste real keys into git-tracked files (`Secrets.example.xcconfig`, `Info.plist`, scheme committed values, docs).

---

## CI readiness checklist

### Done in repo (no credentials required)

- [x] `codemagic.yaml` unsigned `ios-release` workflow
- [x] SPM resolve + deterministic `-derivedDataPath`
- [x] Maps key injection path (env → Secrets.xcconfig + xcodebuild)
- [x] Info.plist `$(VUUM_GOOGLE_MAPS_API_KEY)` substitution
- [x] IPA packaging for Sideloadly
- [x] No Apple Developer Portal / signing certs required on CI
- [x] No Snyk / security-scan steps in CI

### Credential-only (you / operator)

- [ ] Google Cloud billing + Maps SDK for iOS enabled
- [ ] API key created and restricted to `com.vuum.app`
- [ ] `VUUM_GOOGLE_MAPS_API_KEY` set as Codemagic secure env var
- [ ] Rebuild IPA and verify live map on device
