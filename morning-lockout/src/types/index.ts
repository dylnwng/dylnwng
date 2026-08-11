export type DismissalChallengeType = "steps" | "qr" | "math";

export type ActivityVerificationType = "steps" | "motion" | "manual";

export interface LockoutSettings {
  alarmTime: string; // "HH:mm", 24h local time
  lockoutMinutes: number; // default 30, floor 5, ceiling 90
  activityTarget: number; // e.g. steps count, or motion-seconds
  activityType: ActivityVerificationType;
  dismissalChallenge: DismissalChallengeType;
  dismissalStepTarget: number; // steps required to silence the alarm itself
  dismissalGraceMinutes: number; // how long before an abandoned dismissal resumes the alarm
  qrCodePayload?: string; // expected payload when dismissalChallenge === "qr"
}

export const DEFAULT_SETTINGS: LockoutSettings = {
  alarmTime: "06:30",
  lockoutMinutes: 30,
  activityTarget: 300,
  activityType: "steps",
  dismissalChallenge: "steps",
  dismissalStepTarget: 50,
  dismissalGraceMinutes: 2,
};

export type AppPhase =
  | "idle" // before alarm time, normal phone use
  | "alarming" // alarm is sounding, dismissal challenge in progress
  | "gated" // alarm dismissed, lockout timer + activity gate running
  | "unlocked"; // both thresholds met, normal phone use restored

export interface GateProgress {
  lockoutElapsedSeconds: number;
  lockoutTargetSeconds: number;
  activityProgress: number;
  activityTarget: number;
}

export function isGateSatisfied(progress: GateProgress): boolean {
  return (
    progress.lockoutElapsedSeconds >= progress.lockoutTargetSeconds &&
    progress.activityProgress >= progress.activityTarget
  );
}
