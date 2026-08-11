import { create } from "zustand";
import {
  AppPhase,
  DEFAULT_SETTINGS,
  GateProgress,
  LockoutSettings,
  isGateSatisfied,
} from "@/types";

interface AppState {
  settings: LockoutSettings;
  phase: AppPhase;
  progress: GateProgress;
  updateSettings(partial: Partial<LockoutSettings>): void;
  setPhase(phase: AppPhase): void;
  setProgress(partial: Partial<GateProgress>): void;
  gateSatisfied(): boolean;
}

export const useAppStore = create<AppState>((set, get) => ({
  settings: DEFAULT_SETTINGS,
  phase: "idle",
  progress: {
    lockoutElapsedSeconds: 0,
    lockoutTargetSeconds: DEFAULT_SETTINGS.lockoutMinutes * 60,
    activityProgress: 0,
    activityTarget: DEFAULT_SETTINGS.activityTarget,
  },
  updateSettings: (partial) =>
    set((state) => ({ settings: { ...state.settings, ...partial } })),
  setPhase: (phase) => set({ phase }),
  setProgress: (partial) =>
    set((state) => ({ progress: { ...state.progress, ...partial } })),
  gateSatisfied: () => isGateSatisfied(get().progress),
}));
