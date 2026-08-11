# Morning Lockout

A personal iOS app: no phone use for the first 30 minutes of the day, and not before I've walked a minimum number of steps — enforced with a real alarm that can't be silenced or tapped away.

Full spec: [`PRD.md`](./PRD.md). Read §5 first — it's the reason this is a realistic personal project now: AlarmKit (new in iOS 26) gives a real unstoppable alarm, and Family Controls' *development* entitlement (no Apple approval needed, unlike the App Store distribution version) gives a real app-blocking shield, both usable on a build you sign and install to your own phone from Xcode.

## Status

Scaffold, not a working app yet:

- ✅ PRD
- ✅ Swift/SwiftUI app structure: models, `AppViewModel`, all four screens (Onboarding, Home, Alarm, Gate, Settings), and service protocols for the three system-framework integrations
- ✅ `DeviceActivityMonitor` extension target (`MorningLockoutMonitor`) so the shield survives the main app not running
- ⬜ **Not compiled.** This was written without access to Xcode/macOS, so treat it as a first draft to open in Xcode and fix up against the real SDKs — particularly `AlarmScheduler.swift` (AlarmKit is new and its exact API surface should be checked against current docs) and the `.all(except:)` call in `AppShield.swift`.

## Setup

Requires a Mac with Xcode (26+, for AlarmKit) and a personal Apple ID.

```bash
brew install xcodegen
cd morning-lockout
xcodegen generate     # turns project.yml into MorningLockout.xcodeproj
open MorningLockout.xcodeproj
```

Then in Xcode:
1. Select the `MorningLockout` target → Signing & Capabilities → set your personal team.
2. Confirm the `Family Controls` capability is present (it's declared in `project.yml`'s entitlements block, but double-check it shows up after signing).
3. Build to a physical device — Family Controls and real alarm-while-locked behavior don't work meaningfully in Simulator.
4. During onboarding in the running app, use the "Select this app" picker so `AppShield` knows not to shield itself.

**Free Apple ID vs. paid Developer Program:** a free account signs and installs fine, but the build expires after 7 days and needs reinstalling from Xcode. For something meant to run every morning, the $99/year Developer Program (1-year signing) is worth it — and per PRD §10, may also matter for how reliably the Family Controls entitlement behaves.

`.xcodeproj` is not committed — it's generated from `project.yml` via XcodeGen so the project file (which is a pain to diff/merge) doesn't need to live in git. Re-run `xcodegen generate` after pulling changes to `project.yml`.

## Project layout

```
PRD.md
project.yml                        XcodeGen spec — generates the .xcodeproj
MorningLockout/                    main app target
  MorningLockoutApp.swift          @main entry point
  Models/                          LockoutSettings, GateProgress
  ViewModels/AppViewModel.swift    phase state machine, ties the three services together
  Views/                           RootView + Onboarding/Home/Alarm/Gate/Settings
  Services/
    AlarmScheduler.swift           AlarmKit wrapper — needs SDK verification, see file header
    ActivityMonitor.swift          CMPedometer (primary) + CMMotionActivityManager (fallback)
    AppShield.swift                FamilyControls/ManagedSettings — the app-blocking shield
MorningLockoutMonitor/             DeviceActivityMonitor extension target
  ShieldMonitor.swift              keeps the shield enforced independent of the main app
```

## Next steps (in order)

1. `xcodegen generate`, open in Xcode, fix whatever doesn't compile against the real AlarmKit/FamilyControls SDKs.
2. Get the Family Controls picker + `.all(except:)` shield policy actually excluding this app's own token — that's the piece most likely to need a different exact API than what's sketched here.
3. Build to your iPhone, enable the Developer Program if you haven't, and test one real morning end-to-end (alarm → dismissal challenge → gate → unlock) before trusting it daily.
4. Once the core loop works, revisit the math-challenge dismissal fallback and the "pause for today" two-step confirmation from PRD §6.4 — both are in the spec but not yet in the scaffold.
