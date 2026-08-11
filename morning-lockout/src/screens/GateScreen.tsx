import React, { useEffect } from "react";
import { View, Text, StyleSheet } from "react-native";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import type { RootStackParamList } from "@/navigation/RootNavigator";
import { useAppStore } from "@/state/appStore";
import { lockoutService } from "@/services/lockoutService";
import { activityService } from "@/services/activityService";

type Props = NativeStackScreenProps<RootStackParamList, "Gate">;

/**
 * The 30-minute-lockout + activity-gate screen (PRD.md §6.2/§6.3). Shown
 * full-screen while the lockoutService shields other apps. Both the timer
 * and the activity target must be satisfied before "Unlocked" is reached.
 */
export function GateScreen({ navigation }: Props) {
  const settings = useAppStore((s) => s.settings);
  const progress = useAppStore((s) => s.progress);
  const setProgress = useAppStore((s) => s.setProgress);
  const gateSatisfied = useAppStore((s) => s.gateSatisfied);
  const setPhase = useAppStore((s) => s.setPhase);

  useEffect(() => {
    lockoutService.engage();
    activityService.startTracking(settings.activityType, settings.activityTarget);

    const unsubscribeActivity = activityService.onProgress((value) => {
      setProgress({ activityProgress: value });
    });

    const interval = setInterval(() => {
      setProgress({
        lockoutElapsedSeconds: useAppStore.getState().progress.lockoutElapsedSeconds + 1,
      });
    }, 1000);

    return () => {
      clearInterval(interval);
      unsubscribeActivity();
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  useEffect(() => {
    if (gateSatisfied()) {
      lockoutService.release();
      activityService.stopTracking();
      setPhase("unlocked");
      navigation.replace("Home");
    }
  }, [progress, gateSatisfied, lockoutService, activityService, setPhase, navigation]);

  const minutesLeft = Math.max(
    0,
    Math.ceil((progress.lockoutTargetSeconds - progress.lockoutElapsedSeconds) / 60)
  );
  const activityLeft = Math.max(0, progress.activityTarget - progress.activityProgress);

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Not yet.</Text>
      <Text style={styles.line}>{minutesLeft} min left in lockout</Text>
      <Text style={styles.line}>
        {activityLeft} more {settings.activityType === "steps" ? "steps" : "sec of motion"} needed
      </Text>
      <Text style={styles.footnote}>
        Other apps are shielded until both are done. Emergency dialing is never blocked.
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: "center", justifyContent: "center", padding: 24, gap: 16 },
  title: { fontSize: 32, fontWeight: "800" },
  line: { fontSize: 18, color: "#333" },
  footnote: { position: "absolute", bottom: 24, fontSize: 12, color: "#888", textAlign: "center" },
});
