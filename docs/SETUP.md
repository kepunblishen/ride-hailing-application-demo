# iOS Setup — Raide

**Typical machine:** Windows laptop  
**Target:** iPhone via Sideloadly + Codemagic (no local Mac required for IPA builds)

---

## Tools on Windows

| Tool | Why |
|------|-----|
| Git | Version control |
| Sideloadly | Install `.ipa` |
| Codemagic | Cloud Mac build |
| GitHub | Host repo for Codemagic |
| Cursor | Edit Swift on Windows |

Xcode cannot run on Windows — builds go through Codemagic (or a rented Mac).

---

## Frameworks / packages

| Item | How | Required? |
|------|-----|-----------|
| **SwiftUI** | Built into iOS SDK | Yes — all UI |
| **UIKit** | Built into iOS SDK | Yes — maps / share bridges |
| **ComponentsKit** | SPM `https://github.com/componentskit/ComponentsKit` | Yes — linked (Wells pattern) |
| **Google Maps SDK** | SPM `https://github.com/googlemaps/ios-maps-sdk` | Yes — map surface |
| **Explore SwiftUI** | Copy-paste snippets | Optional patterns |
| Firebase / BLE | — | **No** (Wells-only product) |

Deployment target: **iOS 17.0+**

---

## Maps API key

Scheme env: `RAIDE_GOOGLE_MAPS_API_KEY`  
Without a key the app still runs with a map placeholder.

---

## Build flow

```
Edit Swift on Windows (Cursor)
        ↓
Push to GitHub
        ↓
Codemagic → build/Raide.ipa
        ↓
Sideloadly → iPhone
```

See [CODEMAGIC_SETUP.md](CODEMAGIC_SETUP.md).
