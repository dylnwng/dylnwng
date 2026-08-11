import { LockoutSettings } from "@/types";

/**
 * Platform contract for the fail-safe alarm. The concrete implementation
 * needs native modules (Android: AlarmManager + foreground Service +
 * BOOT_COMPLETED receiver; iOS: AVAudioSession playback category +
 * time-sensitive local notifications) — see PRD.md §11. This interface
 * is what the rest of the app codes against so the native layer can be
 * swapped in without touching UI/state code.
 */
export interface AlarmService {
  /** Schedules the alarm so it fires (and re-fires after reboot/force-quit) at settings.alarmTime. */
  schedule(settings: LockoutSettings): Promise<void>;

  /** Cancels any scheduled alarm, e.g. when the user disables the feature. */
  cancel(): Promise<void>;

  /** Starts audio playback at ramping volume, bypassing the silent switch. Called when the alarm fires. */
  startRinging(): Promise<void>;

  /** Stops audio playback. Only call this after the dismissal challenge is actually completed. */
  stopRinging(): Promise<void>;
}

// TODO: replace with a native-module-backed implementation. This stub exists
// so the TypeScript app layer, navigation, and state machine can be built
// and typechecked before the native modules land.
export const alarmService: AlarmService = {
  async schedule(_settings) {
    console.warn("[alarmService] schedule() not implemented — needs native module");
  },
  async cancel() {
    console.warn("[alarmService] cancel() not implemented — needs native module");
  },
  async startRinging() {
    console.warn("[alarmService] startRinging() not implemented — needs native module");
  },
  async stopRinging() {
    console.warn("[alarmService] stopRinging() not implemented — needs native module");
  },
};
