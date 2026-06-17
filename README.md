# Zenly

An iOS focus app that blocks distracting apps and websites during focus sessions —
like Screen Time, but more powerful and user-friendly. Built with SwiftUI on Apple's
ScreenTime stack (FamilyControls + ManagedSettings + DeviceActivity).

## Status

**Phase 1 — plumbing.** The multi-target ScreenTime architecture is scaffolded and a
minimal manual "Block Now" flow proves the picker → shield path end-to-end. Custom shield
UI, category/website blocking polish, strict mode, sessions, analytics, and gamification
follow in later phases.

## Requirements

- Xcode 26+
- A **paid** Apple Developer account (the Family Controls capability requires one)
- A **physical iPhone** — FamilyControls / ManagedSettings / DeviceActivity do **not**
  run on the iOS Simulator. The app compiles for the simulator, but blocking only works on-device.
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`

## Bootstrap

The Xcode project is **generated** from `project.yml` — it is not committed.

```bash
xcodegen generate      # creates Zenly.xcodeproj
open Zenly.xcodeproj
```

After changing targets, capabilities, or build settings, edit `project.yml` and re-run
`xcodegen generate`. **Never edit the generated `.xcodeproj` by hand.**

## Architecture

Four targets sharing one App Group (`group.me.adithyan.shalinth.Zenly`):

| Target | Type | Role |
|---|---|---|
| `Zenly` | app | UI, authorization, app picker, block toggle |
| `ZenlyMonitor` | DeviceActivityMonitor extension | Schedule-driven blocking (Phase 2) |
| `ZenlyShield` | ShieldConfiguration extension | Custom shield UI shown over blocked apps |
| `ZenlyShieldAction` | ShieldAction extension | Shield button handling / override (strict mode) |

The app target follows **MVVM**:

```
Zenly/
├── App/         ZenlyApp.swift — composition root, injects services
├── Views/       SwiftUI views (ContentView, BlockingView) — UI only
├── ViewModels/  @Observable presentation logic (BlockingViewModel)
├── Services/    System-framework wrappers (AuthorizationService, BlockingService)
├── Models/      Persistence / data (SelectionStore)
└── Core/        Shared constants (AppGroup, named ManagedSettingsStore)
```

The app writes the user's `FamilyActivitySelection` into App-Group `UserDefaults` and applies
shields via a **named** `ManagedSettingsStore`, so the extensions can manage the same shield set.

## Verifying the blocking engine (on-device)

1. Run `Zenly` on a physical iPhone from Xcode.
2. Grant Screen Time access (system Face ID / passcode prompt).
3. Choose apps/websites to block, then tap **Block Now**.
4. Try to open a blocked app → it's shielded. Tap **Stop Blocking** → it opens normally.
