# Morning Lockout

A phone app that gates normal phone use behind two conditions every morning: a fixed lockout window (default 30 minutes) and a verified minimum amount of physical activity — plus a fail-safe alarm that requires completing a task, not a tap, to dismiss.

Full product spec: [`PRD.md`](./PRD.md). Read §5 ("Critical platform constraint") first — iOS and Android support fundamentally different levels of enforcement, and the PRD explains why and what that means for scope.

## Status

This is an early scaffold, not a working app yet:

- ✅ PRD
- ✅ TypeScript app shell: navigation (Home → Alarm → Gate → Settings), Zustand state store, and typed service interfaces for the three native-dependent capabilities (alarm, activity tracking, app lockout)
- ⬜ Native modules — `alarmService`, `activityService`, and `lockoutService` (see `src/services/`) are stubbed with `TODO`s. Making the app actually alarm/block/verify-steps requires bare-workflow native code per platform (Kotlin on Android, Swift on iOS) — see PRD §11 for the specific APIs each one needs.

The screens run today (in-memory, with a dev-only "+10 steps" button standing in for the real pedometer) so the flow and state machine can be reviewed and iterated on before native work starts.

## Setup

```bash
npm install
npx expo prebuild   # generates ios/ and android/ — required, this is NOT usable in Expo Go
npm run android      # or: npm run ios
```

`expo prebuild` is required (not `expo start` in Expo Go) because the accessibility-service overlay, exact alarm scheduling, and Screen Time integration all need native modules that Expo Go doesn't support.

## Project layout

```
PRD.md                    product spec — read this first
App.tsx                   entry point
src/
  navigation/              stack: Home, Alarm, Gate, Settings
  screens/                 one file per screen
  services/                platform-contract interfaces (alarmService, activityService, lockoutService) — currently stubbed, need native modules
  state/                   Zustand store: settings, current phase, gate progress
  types/                   shared types + the gate-satisfaction rule
```

## Next steps (in order)

1. Validate the iOS Screen Time / self-control app approval path early (TestFlight submission), since it's the biggest source of scope risk (PRD §10).
2. Build the Android native module first (`AccessibilityService` + overlay + `AlarmManager` + boot receiver) — it's the platform where "block everything" is actually achievable, and it's the deeper technical risk to de-risk first.
3. Wire real step counting (`Health Connect` / `CMPedometer`) into `activityService` to replace the dev-only step simulator on the Alarm screen.
4. Build the iOS native module (`AVAudioSession` + `FamilyControls`/`DeviceActivity`) as a best-effort companion.
