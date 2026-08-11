/**
 * Platform contract for blocking/shielding other apps during the gate.
 * Android: AccessibilityService detects foreground-app changes + a
 * SYSTEM_ALERT_WINDOW overlay bounces the user back. iOS: FamilyControls /
 * ManagedSettings / DeviceActivity shields the configured app set — a
 * best-effort equivalent, not a full-device lock. See PRD.md §5 for why
 * these two platforms cannot offer the same guarantee.
 */
export interface LockoutService {
  /** Engages the block/shield. Must never block the emergency dialer. */
  engage(): Promise<void>;

  /** Releases the block/shield once the gate is satisfied. */
  release(): Promise<void>;

  /** Whether this platform/device currently has the permissions needed to engage. */
  hasRequiredPermissions(): Promise<boolean>;

  /** Opens the OS settings screen for the permission this platform needs (Accessibility on Android, Screen Time on iOS). */
  requestPermissions(): Promise<void>;
}

// TODO: replace with native-module-backed implementation.
export const lockoutService: LockoutService = {
  async engage() {
    console.warn("[lockoutService] engage() not implemented — needs native module");
  },
  async release() {
    console.warn("[lockoutService] release() not implemented — needs native module");
  },
  async hasRequiredPermissions() {
    console.warn("[lockoutService] hasRequiredPermissions() not implemented — needs native module");
    return false;
  },
  async requestPermissions() {
    console.warn("[lockoutService] requestPermissions() not implemented — needs native module");
  },
};
