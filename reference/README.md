# UI Reference Libraries

Local clones for component lookup during development. **Not compiled into the app** unless you also add them via SPM (ComponentsKit is already linked in Xcode).

| Source | Use |
|--------|-----|
| [ComponentsKit](https://github.com/componentskit/ComponentsKit) | Button / card / progress reference |
| [Explore SwiftUI](https://exploreswiftui.com/latest) | Native Liquid Glass / sheet / list snippets you paste into `ios/Vuum/UI/` |

Optional: clone ComponentsKit under `reference/ComponentsKit/` for offline browsing (gitignored if large).

## Vuum design system (in repo)

| File | Role |
|------|------|
| `ios/Vuum/UI/Theme/VuumTheme.swift` | Tokens + ComponentsKit accent |
| `ios/Vuum/UI/Components/VuumGlass.swift` | Glass / material surfaces |
| `ios/Vuum/UI/Components/VuumChrome.swift` | Buttons + sheet chrome |
| `ios/Vuum/Maps/VuumMapView.swift` | UIKit map bridge |
