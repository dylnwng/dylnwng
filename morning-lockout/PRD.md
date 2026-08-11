# Product Requirements Document: Morning Lockout

**Status:** Draft v1
**Author:** Dylan Wang (drafted with Claude)
**Last updated:** 2026-08-11

## 1. Problem

Phones get picked up within seconds of waking up, and that first scroll sets the tone (and the pace) for the rest of the day. The goal of this app is to force a better first 30 minutes: no notifications, no doomscrolling, no email, until (a) a fixed lockout window has passed and (b) the user has done some minimum amount of physical activity. On top of that, mornings only work if the person actually gets up — so the app needs an alarm that cannot be casually swiped away or silenced.

## 2. Goals

- Prevent normal phone use (apps, browser, notifications) for a fixed window after the alarm fires — default 30 minutes, user-configurable.
- Require a minimum amount of verified physical activity (steps, sustained movement, or an equivalent challenge) before the lockout lifts, even if the 30 minutes have elapsed.
- Ship an alarm that is very hard to defeat: it ignores silent/mute switches and Do Not Disturb, escalates in volume, survives the app being force-closed or the phone rebooting, and requires an active dismissal task (not a tap) to stop.
- Give the user an honest, low-friction setup: activity target, lockout duration, and alarm dismissal challenge are all configurable.

## 3. Non-goals (v1)

- Not a general-purpose screen-time / parental-control suite. No multi-user management, no remote (parent-controls-child) administration.
- Not a fitness tracker. We verify "did movement happen," not detailed workout metrics.
- Not a notification-management tool outside the lockout window — after the window and activity target are satisfied, the phone behaves normally.
- Not attempting to block a *specific list* of apps by category (social media, etc.) — v1 blocks everything except the app itself and true essentials (phone/emergency dialer), because partial blocking is trivially bypassed by opening a non-blocked app.

## 4. Target user

Someone who has already decided they want this friction — this is an opt-in, self-imposed constraint app, not a surveillance tool. Primary persona: a person who has tried habit-tracking or willpower-based approaches to "move before scrolling" and wants a hard technical enforcement layer instead.

## 5. Critical platform constraint — read this before scoping anything else

"Doesn't let me use anything until I do X" means blocking access to *other apps*, not just this app. That capability is deliberately and heavily restricted by both mobile OSes, and the two platforms are not equally capable. This determines what's actually buildable:

### Android
Feasible, with real device permissions the user must grant once:
- **Accessibility Service** — lets the app detect when another app comes to the foreground and immediately draw over it / bounce the user back.
- **`SYSTEM_ALERT_WINDOW` (draw over other apps)** — used to show the full-screen lockout/alarm UI on top of anything, including the lock screen.
- **Foreground Service + exact alarms (`AlarmManager` / `setAlarmClock`)** — required so the alarm fires reliably even if the app was killed, battery optimization is on, or the phone was rebooted (we also register a `BOOT_COMPLETED` receiver to reschedule).
- **Device Admin (optional, stronger)** — can prevent uninstalling the app during an active lockout, which closes the most obvious escape hatch ("just delete the app").
- Google Play policy note: `SYSTEM_ALERT_WINDOW` and Accessibility Service usage both require a clear in-app disclosure and a "why we need this" screen during onboarding, or the app risks rejection/removal. This is a real store-review risk to plan for, not just a permissions prompt.

### iOS
Fundamentally more restricted. Apple does not allow third-party apps to block or overlay other apps the way Android allows. The closest official mechanism is the **Screen Time / Family Controls / DeviceActivity framework**, which:
- Can restrict specific apps/categories on the device, but the entitlement is intended for parental-control use cases and is subject to App Review scrutiny for "self-control" apps (Apple has approved some, e.g. Opal, One Sec — so it's possible, not guaranteed).
- Cannot fully replicate "block absolutely everything except this app" — it's a shield over selected apps, not a full-device lock.
- **Guided Access** exists but is a manual accessibility feature the user toggles themselves; it can't be triggered/released programmatically by our app, so it's not a real enforcement mechanism for this product.
- Alarm reliability on iOS is more constrained too: full silent-switch-bypass audio is achievable (`AVAudioSession` category `.playback` ignores the mute switch), but **Critical Alerts** (bypass Do Not Disturb / Focus entirely) require a special Apple-granted entitlement that is not guaranteed to be approved for a non-medical/non-safety app.

**Recommendation:** build Android first as the "real" enforcement experience (full lockout + hard-to-kill alarm), and ship iOS as a best-effort companion (Screen Time-based app shielding + non-Critical-Alert loud alarm) with onboarding copy that's honest about the gap. Do not promise "blocks everything" as an iOS claim in the App Store listing — it would misrepresent what's technically possible and risks rejection.

## 6. Core features

### 6.1 Fail-safe alarm
- Fires at a user-set time; survives force-quit and reboot (re-registered via native alarm scheduling + boot receiver on Android; local notifications + background audio session on iOS).
- Ignores the mute/silent switch and ramps from low to full volume over ~60 seconds.
- Full-screen takeover UI on top of the lock screen (Android) / full-screen local notification (iOS) — no swipe-to-dismiss.
- **Dismissal requires a task, not a tap.** Configurable dismissal challenges for v1:
  - Walk a set number of steps within N minutes (uses the same pedometer check as §6.2, so the alarm dismissal *is* the start of the activity gate).
  - Scan a QR code the user has printed/placed somewhere deliberately inconvenient (bathroom, kitchen) — forces physically getting up and going there.
  - Solve N escalating math problems.
- If the dismissal task is abandoned partway, the alarm resumes after a short grace period (default 2 minutes) rather than silencing permanently — this is the "no snooze-and-forget" guarantee.
- A single, clearly-labeled emergency override exists (e.g., a long-press "Emergency call only" affordance) so the app never blocks access to 911/emergency dialing — this is a legal/safety requirement, not optional.

### 6.2 Morning activity gate
- After the alarm is dismissed, the app tracks physical activity toward a configurable target (default: 300 steps within 20 minutes, using device pedometer/step-counter APIs — `CMPedometer` on iOS, `Health Connect`/`SensorManager` step counter on Android).
- Alternative verification modes for users without reliable step-counter hardware/permissions: sustained-accelerometer-motion detection, or a manual "confirm with a photo" fallback (lower trust, flagged as such in-app).
- The gate only lifts when **both** conditions are met: lockout timer elapsed AND activity target hit. If activity finishes first, the countdown for the remaining lockout time is shown; if the timer finishes first, the app shows remaining activity needed.

### 6.3 30-minute hard lockout
- Independent of activity — even a very fast walk cannot unlock the phone in under the configured minimum (default 30 min, floor of 5 min / ceiling of 90 min in settings).
- During lockout: Android shows a full-screen block over any app switch attempt (via Accessibility Service, §5); iOS shields the configured app set via Screen Time.
- Notifications are held (not delivered/shown) during the lockout window where the platform allows deferring them, and released once the gate lifts.

### 6.4 Onboarding & settings
- One-time setup flow: alarm time, activity target + type, lockout duration, dismissal challenge type, and — critically — an explicit permissions walkthrough explaining *why* each OS permission is requested (this doubles as the store-review disclosure copy).
- Settings screen to adjust all of the above, plus a "pause for today" affordance that requires a deliberate two-step confirmation (travel days, sickness, etc.) so it isn't a one-tap escape hatch that defeats the app's purpose.

## 7. User flow (happy path)

1. Alarm fires at set time, ignoring silent mode, full volume ramp.
2. User must complete the dismissal challenge (e.g., walk 50 steps) to stop the alarm.
3. Dismissing the alarm starts the 30-minute lockout + activity-gate screen simultaneously.
4. App blocks/shields other apps; home screen shows live progress ("18 / 30 min · 140 / 300 steps").
5. Once both thresholds are met, the app releases the lock, delivers any held notifications, and returns the phone to normal.

## 8. Success metrics

- % of mornings the alarm is dismissed only via the intended challenge (vs. force-quit/uninstall/OS-level workaround detected).
- Average time-to-first-unlock-app-usage after alarm (directionally, should sit near the lockout floor + activity time, not spike immediately after alarm dismissal — a spike indicates a bypass).
- 7-day and 30-day retention of the lockout feature being left enabled (not paused/disabled).
- Crash-free rate for the alarm-scheduling path specifically (this is the feature that cannot be allowed to silently fail).

## 9. MVP scope

**In:** Android full implementation (alarm, lockout, accessibility-service app-block, step-based activity gate, QR/step/math dismissal challenges), iOS best-effort implementation (alarm without Critical Alerts, Screen Time app shielding, step-based activity gate), onboarding, settings, emergency-call override.

**Out of MVP, later phases:** widgets/lock-screen complications, activity history/stats dashboard, social/accountability features (streaks shared with friends), Apple Watch / Wear OS companion for step verification without carrying the phone, Critical Alerts entitlement application to Apple.

## 10. Risks & open questions

- **App Store approval risk (iOS):** self-control apps using Screen Time have been approved before, but review outcomes for "blocking" behavior are not guaranteed and can change. Needs validation with a TestFlight submission early, not after full build-out.
- **Android battery optimization:** OEM-specific "aggressive battery saver" modes (Xiaomi, Huawei, some Samsung configs) can kill background/foreground services despite correct API usage. Needs device-specific testing and in-app guidance to whitelist the app.
- **Bypass paths to close explicitly:** airplane mode, uninstall-during-lockout, second device, factory reset, SIM removal. v1 cannot prevent all of these (this is a self-imposed-friction tool, not device-management-grade lockdown) — PRD explicitly scopes to deterring casual bypass, not defeating a determined user with full device access. This should be stated in-app so expectations are set correctly.
- **Accessibility/step-counter permission denial:** need a graceful degraded mode (manual confirmation, clearly marked lower-trust) rather than the app becoming unusable if a permission is refused.
- **Open question:** should the activity target adapt (e.g., lower on days with a logged workout already, or weather-aware for outdoor activity types) — deferred, flagged for v1.1 discussion.

## 11. Technical approach (high level)

Cross-platform app shell in React Native (Expo, bare/prebuild workflow — not managed Expo Go, since native modules for Accessibility Service, foreground services, exact alarms, and Screen Time are required and are outside what managed Expo exposes). Native modules needed per platform:

- **Android:** Kotlin native module wrapping `AccessibilityService`, `SYSTEM_ALERT_WINDOW` overlay, `AlarmManager`/`setAlarmClock`, `BOOT_COMPLETED` receiver, foreground `Service`, step counter via `Health Connect` (fallback `TYPE_STEP_COUNTER` sensor).
- **iOS:** Swift native module wrapping `AVAudioSession` (playback category), local notifications with a full-screen intent-equivalent (time-sensitive interruption level), `FamilyControls`/`ManagedSettings`/`DeviceActivity` for app shielding, `CMPedometer` for steps.
- Shared TypeScript app layer: navigation, state (alarm config, lockout state machine, activity progress), UI.

This repo currently contains the PRD and a scaffolded TypeScript/React Native app shell (screens, state, and typed service interfaces) reflecting this architecture. The native-module implementations are stubbed with clear TODOs — they require a bare React Native project (not Expo Go) and platform-specific native code that should be built next, per platform, starting with Android as scoped in §5.
