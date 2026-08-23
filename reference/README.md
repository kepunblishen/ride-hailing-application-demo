# UI Reference Libraries

Local clones for component lookup during development. **Not compiled into the app** unless you also add them via SPM (ComponentsKit is already linked in Xcode).

| Source | Use |
|--------|-----|
| [ComponentsKit](https://github.com/componentskit/ComponentsKit) | Button / card / progress reference |
| [Explore SwiftUI](https://exploreswiftui.com/latest) | Native Liquid Glass / sheet / list snippets you paste into `ios/Raide/UI/` |

Optional: clone ComponentsKit under `reference/ComponentsKit/` for offline browsing (gitignored if large).

## Raide design system (in repo)

| File | Role |
|------|------|
| `ios/Raide/UI/Theme/RaideTheme.swift` | Tokens + ComponentsKit accent |
| `ios/Raide/UI/Components/RaideGlass.swift` | Glass / material surfaces |
| `ios/Raide/UI/Components/RaideChrome.swift` | Buttons + sheet chrome |
| `ios/Raide/Maps/RaideMapView.swift` | UIKit map bridge |
