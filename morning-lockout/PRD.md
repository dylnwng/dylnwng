# Product Requirements Document: Morning Lockout

**Status:** Draft v2 — refocused on iOS, personal use only
**Author:** Dylan Wang (drafted with Claude)
**Last updated:** 2026-08-11

## 1. Problem

Phones get picked up within seconds of waking up, and that first scroll sets the tone (and the pace) for the rest of the day. This app forces a better first 30 minutes on my own phone: no apps, no notifications, no doomscrolling, until (a) a fixed lockout window has passed and (b) I've done some minimum amount of physical activity. Mornings only work if I actually get up, so it also needs an alarm that can't be casually swiped away or silenced.

## 2. Scope: personal use, iOS only

This is a single-user app for my own iPhone, sideloaded via Xcode with my personal Apple ID — **not** distributed on the App Store. That one decision simplifies almost everything:

- No App Review to pass, and no risk of Apple rejecting a "blocking" app or pulling it later — self-distribution isn't reviewed.
- No need to build or maintain an Android version. v1 is iOS-only.
- No need for React Native / cross-platform tooling. The features that matter (a real alarm, blocking other apps, verifying steps) are all iOS system frameworks — going straight native in Swift/SwiftUI means no JS-to-native bridge layer to build and debug for zero benefit.

The only real constraint left is the standard iOS provisioning tradeoff: a free Apple ID can sign and install the app to your own device, but the build expires after 7 days and has to be reinstalled from Xcode. Enrolling in the Apple Developer Program ($99/year) removes that limit (1-year signing) and is also what's needed to reliably use the Family Controls entitlement below — worth doing for something meant to run every single morning.

## 3. Goals

- Prevent normal phone use (apps, notifications) for a fixed window after the alarm fires — default 30 minutes, configurable.
- Require a minimum amount of verified physical activity (steps or sustained movement) before the lockout lifts, even if the 30 minutes have elapsed.
- An alarm that's very hard to defeat: ignores the silent switch and Focus/Do Not Disturb, escalates in volume, survives the app being force-closed or the phone rebooting, and requires an active dismissal task — not a tap — to stop.
- Configurable activity target, lockout duration, and alarm dismissal challenge.

## 4. Non-goals (v1)

- Not a fitness tracker — verifying "did movement happen," not workout metrics.
- Not blocking a curated list of app categories. v1 blocks everything except the app itself and the emergency dialer, because a partial block is trivially bypassed by opening a non-blocked app.
- Not App Store distribution, not multi-user, not Android.

## 5. Why iOS can do this now: AlarmKit + Family Controls

iOS has historically been the harder platform for exactly this kind of app — third-party apps can't overlay or freely block other apps, and a real "ignore silent mode, full-screen, must dismiss with an action" alarm required either the Critical Alerts entitlement (needs Apple approval, not guaranteed) or fragile local-notification tricks. Two things change that for a personal, sideloaded build:

**AlarmKit (new in iOS 26).** Apple shipped a dedicated framework for exactly this use case — third-party alarms that behave like the built-in Clock app: full volume through the silent switch and Focus modes, full-screen presentation even on the lock screen, survives the app being killed, and is dismissed via an explicit action (button/App Intent) rather than a swipe. This replaces the old "abuse notifications to fake an alarm" approach entirely and is the primary alarm mechanism for this app. **Caveat:** AlarmKit is a newer API and its exact type/method names should be confirmed against current Xcode documentation/autocomplete when implementing — the scaffold in this repo is written to the framework's known shape but hasn't been compiled against the real SDK.

**Family Controls / ManagedSettings / DeviceActivity.** This is Apple's Screen Time framework, and it's what shields other apps during the lockout window. The catch for third parties is normally the *distribution* entitlement — Apple has to approve your app for App Store release under this framework. **That approval is not needed here.** The *development* entitlement (added in Xcode under Signing & Capabilities → Family Controls) works on your own device with your own Apple ID / provisioning profile for apps you build and install yourself — no request-and-wait process. This is the whole reason personal-use-only is a meaningfully easier target than the original cross-platform plan.

Net effect: on a personal iOS build, this app can legitimately do both an unmissable alarm and a real app-blocking lockout, without waiting on Apple approval for anything. The main remaining risk is normal Apple SDK churn (entitlement behavior, exact AlarmKit surface) between now and when this gets built — verify both against current docs at implementation time.

## 6. Core features

### 6.1 Fail-safe alarm (AlarmKit)
- Fires at a user-set time via `AlarmManager`/`AlarmKit` scheduling; survives force-quit and reboot because the OS — not the app process — owns alarm delivery.
- Full volume, ignores silent switch and Focus modes; full-screen presentation on the lock screen.
- **Dismissal requires a task, not a tap.** v1 dismissal challenges:
  - Walk a set number of steps within N minutes (same pedometer check as §6.2 — dismissing the alarm *is* the start of the activity gate).
  - Solve N escalating math problems (fallback for when walking isn't possible, e.g. injury).
- If the dismissal flow is abandoned partway, the alarm resumes after a short grace period (default 2 minutes) — no snooze-and-forget.
- Emergency calling is never blocked by anything in this app; iOS itself guarantees this at the OS level (emergency SOS is always reachable from the lock screen regardless of any app state).

### 6.2 Morning activity gate (CMPedometer / HealthKit)
- After the alarm is dismissed, tracks physical activity toward a configurable target (default: 300 steps within 20 minutes) using `CMPedometer`.
- Fallback verification mode (sustained accelerometer motion via `CMMotionActivityManager`) for cases where step data is delayed or unavailable.
- The gate only lifts when **both** the lockout timer has elapsed **and** the activity target is hit.

### 6.3 30-minute hard lockout (Family Controls / DeviceActivity)
- Independent of activity — a fast walk can't unlock the phone in under the configured minimum (default 30 min, floor 5 / ceiling 90 in settings).
- Implemented via `ManagedSettings` app shields covering all apps except this one, applied through a `DeviceActivityMonitor` extension that engages at alarm-dismiss time and releases when the gate is satisfied.
- Notifications from other apps are held (Screen Time communication/notification limits) during lockout and released once the gate lifts.

### 6.4 Onboarding & settings
- One-time setup: alarm time, activity target, lockout duration, dismissal challenge type, and a permissions walkthrough (Family Controls, Motion & Fitness, Notifications) explaining why each is requested.
- Settings to adjust all of the above, plus a "pause for today" toggle that requires a deliberate two-step confirmation (travel, sickness) so it isn't a one-tap escape hatch.

## 7. User flow (happy path)

1. Alarm fires at set time via AlarmKit — full volume, ignores silent mode, full-screen on lock screen.
2. Dismissal requires completing the challenge (e.g., walk 50 steps).
3. Dismissing the alarm engages the Family Controls shield and starts the 30-minute + activity-gate countdown simultaneously.
4. Live progress shown in-app ("18 / 30 min · 140 / 300 steps") while other apps are shielded.
5. Once both thresholds are met, the shield lifts and the phone returns to normal.

## 8. Success metrics (personal, informal)

Since this is single-user, "metrics" are really just self-check questions:
- Did the alarm actually wake me up and get dismissed only via the real challenge (not a workaround)?
- Did I end up using the phone before both thresholds were met on any morning (a bypass, worth investigating how)?
- Did the app survive reboots/force-quits without needing manual re-setup?

## 9. MVP scope

**In:** AlarmKit-based alarm with steps/math dismissal challenge, Family Controls app shield for the lockout window, CMPedometer-based activity gate, onboarding/permissions flow, settings.

**Out of v1:** Live Activity/Dynamic Island polish beyond what AlarmKit provides by default, Apple Watch companion for step verification without carrying the phone, activity history/stats, Android (not planned at all now).

## 10. Risks & open questions

- **AlarmKit is new** (iOS 26) — exact API surface should be verified against current Xcode docs when implementing; treat the scaffold's `AlarmScheduler` as a best-effort sketch, not verified-working code.
- **Minimum iOS version is 26** — fine for a personal device you control, but means this can't be built for an older iPhone without falling back to the weaker local-notification approach.
- **Family Controls development entitlement** — expected to work without Apple's approval process for a self-signed build, but Apple's entitlement behavior has changed before and should be double-checked at build time (Signing & Capabilities → Family Controls, development profile).
- **Bypass paths this doesn't try to close:** a second device, deleting the app then reinstalling from a backup that predates lockout, restoring the phone, airplane-mode-then-back edge cases in DeviceActivity scheduling. This is a self-imposed-friction tool against casual bypass (rolling out of bed and scrolling), not a device-management-grade lock against a fully determined attempt to defeat your own phone.
- **7-day free provisioning** — if not enrolled in the paid Developer Program, the build needs manual reinstall from Xcode weekly, which will break the "every morning" reliability goal. Recommend enrolling.

## 11. Technical approach

Native Swift/SwiftUI app, iOS 26+ deployment target, single Xcode project (this repo includes an `XcodeGen` `project.yml` so the `.xcodeproj` doesn't need to be hand-maintained/committed — run `xcodegen generate` to produce it).

- **Alarm:** `AlarmScheduler` wraps AlarmKit — schedule, cancel, and the dismissal-action wiring.
- **Activity:** `ActivityMonitor` wraps `CMPedometer` (primary) and `CMMotionActivityManager` (fallback).
- **Lockout/shield:** `AppShield` wraps `FamilyControls` authorization, `ManagedSettings` app shielding, and a `DeviceActivityMonitor` extension target that owns engaging/releasing the shield on its own schedule (so it works even if the main app isn't running).
- **App layer:** SwiftUI views (`HomeView`, `AlarmView`, `GateView`, `SettingsView`, `OnboardingView`) backed by a single `AppViewModel` (`ObservableObject`) and a `LockoutSettings` model persisted via `UserDefaults`/`AppStorage`.

This repo contains the PRD and a Swift/SwiftUI scaffold matching this architecture: models, an `AppViewModel`, SwiftUI views for the full flow, and service protocols (`AlarmScheduling`, `ActivityMonitoring`, `AppShielding`) with best-effort implementations against AlarmKit/CMPedometer/FamilyControls. It has not been compiled — there's no macOS/Xcode toolchain available in the environment this was written in — so the next step is opening it in Xcode on a Mac, fixing whatever doesn't compile against the real SDKs, and building to a physical device (Family Controls and real alarm-while-locked behavior can't be fully verified in Simulator).
