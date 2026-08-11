# Morning Lockout

A personal iOS app: no phone use for the first 30 minutes of the day, and not before I've walked a minimum number of steps — enforced with a real alarm that can't be silenced or tapped away.

Full spec: [`PRD.md`](./PRD.md). Read §5 first — it's the reason this is a realistic personal project now: AlarmKit (new in iOS 26) gives a real unstoppable alarm, and Family Controls' *development* entitlement (no Apple approval needed, unlike the App Store distribution version) gives a real app-blocking shield, both usable on a build you sign and install to your own phone from Xcode.

## Status

Scaffold, not a working app yet:

- ✅ PRD
- ✅ Swift/SwiftUI app structure: models, `AppViewModel`, all four screens (Onboarding, Home, Alarm, Gate, Settings), and service protocols for the three system-framework integrations
- ✅ `DeviceActivityMonitor` extension target (`MorningLockoutMonitor`) so the shield survives the main app not running
- ✅ Physical activity gate is wired end-to-end and real, not a placeholder: `ActivityMonitor` runs a live `CMPedometer` session starting the moment the alarm fires, `AlarmView` reads that live count for the dismissal challenge instead of a fake counter, and the same session carries its steps straight into the lockout gate's `activityProgress` on transition — so steps walked to silence the alarm count toward the gate instead of resetting to zero. Falls back to accelerometer-based motion detection (`CMMotionActivityManager`) if step counting is unavailable or denied, so there's always a path to unlocking. The one intentional cheat-adjacent bit — a manual step-increment button — only compiles into Simulator builds (`#if targetEnvironment(simulator)`), never a real device, since a bypass button has no business existing on the phone this app is supposed to gate.
- ✅ Math-challenge dismissal fallback (for when walking isn't possible — injury, etc.): escalating-difficulty problems (`MathProblem.generate`), tracked in `AppViewModel`, with its own `AlarmView` branch. Configurable challenge type and problem count now live in Settings.
- ✅ "Pause for today" — two-step confirmation (`Settings` → destructive button → `confirmationDialog` requiring a second explicit tap) so it can't be hit by accident. Pausing skips the lockout/activity gate for the rest of the calendar day only; the alarm and its dismissal challenge still run regardless. Self-expiring — no separate "resume" step needed the next morning.
- ⬜ **Not compiled.** This was written without access to Xcode/macOS, so treat it as a first draft to open in Xcode and fix up against the real SDKs — particularly `AlarmScheduler.swift` (AlarmKit is new and its exact API surface should be checked against current docs) and the `.all(except:)` call in `AppShield.swift`. `ActivityMonitor`/`AppViewModel`'s activity-tracking logic is plain CoreMotion + state machine code and is the part of the scaffold I'd trust most to compile close to as-written.

## Setup

Editing the code doesn't require a Mac — it's plain Swift/SwiftUI, VS Code with a Swift extension (or even no extension) works fine for that. Two separate things *do* require Apple's toolchain, and there's no way around either — this isn't a tooling preference, it's how iOS code signing and the simulator/device build pipeline work:

1. **Compiling against the real SDKs.** AlarmKit and FamilyControls in this scaffold were written without access to Xcode, so they need to actually build once to find out what's wrong.
2. **Signing and installing to your iPhone.** Requires an Apple ID (and ideally the paid Developer Program, see below) and `codesign`/provisioning, which only exist inside Xcode's toolchain.

### No Mac at all: use CI for (1), a cloud Mac only when you need (2)

[`.github/workflows/morning-lockout-ios-build.yml`](../.github/workflows/morning-lockout-ios-build.yml) builds this app on GitHub's free macOS runners on every push to `morning-lockout/**` — no signing needed, since it targets the Simulator destination. Push a change, check the Actions tab: green means it compiles against the real AlarmKit/FamilyControls SDKs, red means the guessed API calls in `AlarmScheduler.swift`/`AppShield.swift` need fixing, with a real compiler error to go on instead of my best guess. This is genuinely the whole "does this compile" question answered without touching a Mac.

Getting it onto your actual iPhone (step 2) is a separate problem CI can't solve for free — signing needs your Apple ID's private key, which shouldn't live in CI secrets for a personal project. The practical options, cheapest first:
- **Borrow a Mac for 15 minutes** — you only need it long enough to open Xcode, sign in with your Apple ID, and do `xcodebuild -exportArchive`/plain "Run" once (or periodically, if you go the free-account 7-day-expiry route below).
- **Rent a cloud Mac by the hour** (e.g. MacinCloud, MacStadium) — a few dollars for a one-off session to build, sign, and install over USB or wireless debugging.
- **Automate signing in CI anyway**, using [Fastlane match](https://docs.fastlane.tools/actions/match/) to store an encrypted signing identity as a GitHub secret, then sideload the resulting `.ipa` with [AltStore](https://altstore.io) or [SideStore](https://sidestore.io) (both install from a Windows/Linux/Mac companion app, no Xcode needed for the *install* step, just for producing the signed build once). More setup, but means never touching a Mac again after the initial cert generation — worth it only if you want, e.g. automatic rebuilds when `alarmTime` logic changes.

### If you do have a Mac (even without Xcode installed yet)

Xcode is a free App Store install — after that, everything else is normal:

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
  Models/                          LockoutSettings, GateProgress, MathProblem
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

1. Push to `main` (or open a PR) and watch the `morning-lockout-ios-build` CI run — fix whatever doesn't compile against the real AlarmKit/FamilyControls SDKs. No Mac needed for this step.
2. Get the Family Controls picker + `.all(except:)` shield policy actually excluding this app's own token — that's the piece most likely to need a different exact API than what's sketched here.
3. Wire `AppViewModel.alarmDidFire(alarmID:)` up to whatever AlarmKit actually calls when the alarm fires/the app is opened from the alert — right now nothing invokes it, since that hook depends on confirming AlarmKit's real API in step 1.
4. Once CI is green, get the app onto your iPhone by one of the routes in Setup above (borrowed Mac, cloud Mac, or Fastlane match + AltStore/SideStore), enable the Developer Program if you haven't, and test one real morning end-to-end (alarm → dismissal challenge → gate → unlock) before trusting it daily. Simulator has no pedometer hardware, so the activity gate specifically can't be meaningfully tested until it's on a real device.
