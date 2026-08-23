# Codemagic — Vuum unsigned iOS build

Same approach as the Wells scaffold: Codemagic builds an unsigned `.ipa`; Sideloadly signs with a free Apple ID. No Apple Developer Program membership is required for this path.

**Software side is ready.** Once group `vuum_secrets` exists and `VUUM_GOOGLE_MAPS_API_KEY` is set Secure inside it, CI injects the key and the IPA ships with a live Maps value in Info.plist. Remaining steps are credential / console only (below).

No Snyk (or other security-scan) steps run in this workflow — see [NO_SNYK.md](NO_SNYK.md).

---

## Exact Codemagic checklist (before you start a build)

Do these in order. Names must match **exactly**.

1. **Repo app** — Add this GitHub repo as an iOS application in Codemagic; select workflow **`ios-release`** from root `codemagic.yaml`.
2. **Variable group** — Application → **Environment variables** → create a group named **`vuum_secrets`** (exact spelling; must match `environment.groups` in YAML).  
   - If you use a **Team** global group, grant this application access to it.  
   - Create the empty group even before you have a key — a missing group fails the build; a missing key does not.
3. **Secure variable** — Inside group `vuum_secrets`, add:

   | Name | Secure | Value |
   |------|--------|--------|
   | `VUUM_GOOGLE_MAPS_API_KEY` | **Yes** | Maps SDK for iOS key restricted to bundle ID `com.vuum.app` |

4. **Google Cloud** (if not done) — Billing on; enable at least **Maps SDK for iOS**; create/restrict the key (full steps: [GOOGLE_MAPS_SETUP.md](GOOGLE_MAPS_SETUP.md)).
5. **Start build** → download artifact **`build/Vuum.ipa`** → install with Sideloadly.
6. **Verify** — Log line `VUUM_GOOGLE_MAPS_API_KEY is set — wrote ios/Secrets.xcconfig…`; on device, live map tiles (not “Map unavailable”).

Do **not** paste real keys into git-tracked files.

---

## One-time Codemagic setup (summary)

1. Add this GitHub repo as an iOS app in Codemagic
2. Select workflow **ios-release** from root `codemagic.yaml`
3. Create group **`vuum_secrets`** and set Secure `VUUM_GOOGLE_MAPS_API_KEY` in that group
4. Start build → download `build/Vuum.ipa` → install via Sideloadly

---

## What the workflow does

| Step | Purpose |
|------|---------|
| Import `vuum_secrets` | Loads Secure env from Codemagic UI group into the build machine |
| Inject Maps key | If `VUUM_GOOGLE_MAPS_API_KEY` is set, writes gitignored `ios/Secrets.xcconfig` (picked up by `Vuum.xcconfig` `#include? "../../Secrets.xcconfig"`) |
| Resolve SPM | `xcodebuild -resolvePackageDependencies` — ComponentsKit, Google Maps SDK, KeychainSwift |
| `xcodebuild build` | Unsigned Debug `iphoneos` build; passes `VUUM_GOOGLE_MAPS_API_KEY` on the CLI **only when set** (empty override would wipe xcconfig) |
| Package IPA | Zips `Vuum.app` → `build/Vuum.ipa` for Sideloadly |

**Injection path:** `vuum_secrets` → env `VUUM_GOOGLE_MAPS_API_KEY` → `ios/Secrets.xcconfig` + `xcodebuild … VUUM_GOOGLE_MAPS_API_KEY=…` → Info.plist.

Without the **variable**, the **build still succeeds**; `MapBootstrap` treats an empty / placeholder key as missing and the UI shows the map-unavailable surface.  
Without the **group** `vuum_secrets`, Codemagic fails before scripts run (group must exist).

---

## SPM resolve on Codemagic (required path from Windows)

Apple SPM cannot be resolved on Windows PowerShell. Codemagic is the supported resolve + build host.

The **Resolve Swift packages** step in `codemagic.yaml` runs:

```bash
xcodebuild -resolvePackageDependencies \
  -project ios/Vuum.xcodeproj \
  -scheme Vuum
```

Pins live only in `ios/Vuum.xcodeproj/project.pbxproj` (`XCRemoteSwiftPackageReference`). No committed `Package.resolved`; each CI run resolves within the declared `upToNextMajorVersion` floors:

| Package | URL | Floor (pbxproj) | Product on `Vuum` |
|---------|-----|-----------------|-------------------|
| Google Maps SDK | `https://github.com/googlemaps/ios-maps-sdk` | ≥ 10.0.0 (`< 11`) | `GoogleMaps` |
| ComponentsKit | `https://github.com/componentskit/ComponentsKit` | ≥ 1.7.0 (`< 2`) | `ComponentsKit` |
| KeychainSwift | `https://github.com/evgenyneu/keychain-swift.git` | ≥ 24.0.0 (`< 25`) | `KeychainSwift` |

Remote tags verified (2026-08-23): Maps `9.4.0`…`11.0.0` (resolve stays on latest **9.x**); ComponentsKit `1.7.1`; KeychainSwift **`24.0.0`**. No Snyk / security-scan steps.

---

## Maps API key (Codemagic)

Scheme Run env alone is **not** enough for Sideloadly IPAs — the key must be baked at build time into Info.plist.

`codemagic.yaml` does both when the Secure env is present:

1. Writes `ios/Secrets.xcconfig`  
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
| Env group | `vuum_secrets` |
| Secure var | `VUUM_GOOGLE_MAPS_API_KEY` |
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
3. **Codemagic** → Application → Environment variables:

   | Group (exact) | Variable | Secure |
   |---------------|----------|--------|
   | `vuum_secrets` | `VUUM_GOOGLE_MAPS_API_KEY` | Yes |

4. **Rebuild** → Sideload `build/Vuum.ipa` → confirm live map tiles (not “Map unavailable”)
5. **Optional later** — Places / Routes keys or expanded API restrictions (see [GOOGLE_MAPS_SETUP.md](GOOGLE_MAPS_SETUP.md))

Do **not** paste real keys into git-tracked files (`Secrets.example.xcconfig`, `Info.plist`, scheme committed values, docs).

---

## CI readiness checklist

### Done in repo (no credentials required)

- [x] `codemagic.yaml` unsigned `ios-release` workflow
- [x] `environment.groups: vuum_secrets` wired (exact UI group name)
- [x] SPM resolve + deterministic `-derivedDataPath`
- [x] SPM pins verified — Maps ≥10.0.0 product `GoogleMaps`; ComponentsKit ≥1.7.0; KeychainSwift ≥24.0.0 (no broken floors)
- [x] Maps key injection path (`vuum_secrets` → env → `Secrets.xcconfig` + `xcodebuild` only when set)
- [x] Info.plist `$(VUUM_GOOGLE_MAPS_API_KEY)` substitution
- [x] `MapBootstrap` placeholder skip + fallthrough; scheme env disabled by default
- [x] Bundle ID `com.vuum.app`
- [x] IPA packaging for Sideloadly
- [x] No Apple Developer Portal / signing certs required on CI
- [x] No Snyk / security-scan steps in CI
- [x] Build succeeds without Maps key value (map unavailable only) when group exists

### Credential-only (you / operator)

- [ ] Google Cloud billing + Maps SDK for iOS enabled
- [ ] API key created and restricted to `com.vuum.app`
- [ ] Codemagic group **`vuum_secrets`** created and linked to this app
- [ ] `VUUM_GOOGLE_MAPS_API_KEY` set Secure **inside** that group
- [ ] Rebuild IPA and verify live map on device
