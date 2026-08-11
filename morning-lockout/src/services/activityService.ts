import { ActivityVerificationType } from "@/types";

/**
 * Platform contract for verifying physical activity. Steps come from
 * CMPedometer (iOS) or Health Connect / TYPE_STEP_COUNTER (Android);
 * "motion" falls back to sustained accelerometer movement for devices/
 * permission states where step counting isn't available. See PRD.md §6.2.
 */
export interface ActivityService {
  /** Begins tracking toward the given target using the given verification method. */
  startTracking(type: ActivityVerificationType, target: number): Promise<void>;

  /** Stops tracking (e.g. once the gate is satisfied, or the user pauses for the day). */
  stopTracking(): Promise<void>;

  /** Registers a callback fired with the current progress value whenever it changes. */
  onProgress(callback: (progress: number) => void): () => void; // returns an unsubscribe fn
}

// TODO: replace with native sensor-backed implementation.
export const activityService: ActivityService = {
  async startTracking(_type, _target) {
    console.warn("[activityService] startTracking() not implemented — needs native module");
  },
  async stopTracking() {
    console.warn("[activityService] stopTracking() not implemented — needs native module");
  },
  onProgress(_callback) {
    console.warn("[activityService] onProgress() not implemented — needs native module");
    return () => {};
  },
};
