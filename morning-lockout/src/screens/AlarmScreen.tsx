import React, { useEffect, useState } from "react";
import { View, Text, StyleSheet, Pressable } from "react-native";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import type { RootStackParamList } from "@/navigation/RootNavigator";
import { useAppStore } from "@/state/appStore";
import { alarmService } from "@/services/alarmService";

type Props = NativeStackScreenProps<RootStackParamList, "Alarm">;

/**
 * Full-screen, non-dismissable-by-tap alarm UI. Real dismissal happens by
 * completing the configured challenge (steps/QR/math) — see PRD.md §6.1.
 * This screen intentionally has no back button and no swipe-to-dismiss;
 * the native layer is responsible for keeping it on top of the lock screen
 * on Android and delivering it as a time-sensitive notification on iOS.
 */
export function AlarmScreen({ navigation }: Props) {
  const settings = useAppStore((s) => s.settings);
  const setPhase = useAppStore((s) => s.setPhase);
  const [stepsWalked, setStepsWalked] = useState(0);

  useEffect(() => {
    alarmService.startRinging();
    return () => {
      alarmService.stopRinging();
    };
  }, []);

  const challengeComplete =
    settings.dismissalChallenge === "steps"
      ? stepsWalked >= settings.dismissalStepTarget
      : false; // TODO: wire up QR-scan and math-challenge completion state

  const handleDismiss = async () => {
    if (!challengeComplete) return;
    await alarmService.stopRinging();
    setPhase("gated");
    navigation.replace("Gate");
  };

  return (
    <View style={styles.container}>
      <Text style={styles.time}>{settings.alarmTime}</Text>
      <Text style={styles.instructions}>
        Walk {settings.dismissalStepTarget} steps to stop the alarm.
      </Text>

      {/* Placeholder progress — real value comes from activityService via a native pedometer. */}
      <Text style={styles.progress}>
        {stepsWalked} / {settings.dismissalStepTarget} steps
      </Text>

      <Pressable
        style={styles.debugButton}
        onPress={() => setStepsWalked((n) => n + 10)}
      >
        <Text style={styles.debugButtonText}>+10 steps (dev-only simulator)</Text>
      </Pressable>

      <Pressable
        style={[styles.dismissButton, !challengeComplete && styles.dismissButtonDisabled]}
        disabled={!challengeComplete}
        onPress={handleDismiss}
      >
        <Text style={styles.dismissText}>
          {challengeComplete ? "Dismiss alarm" : "Keep moving..."}
        </Text>
      </Pressable>

      <Text style={styles.emergency}>Emergency call is always available from the lock screen.</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: "#B00020",
    alignItems: "center",
    justifyContent: "center",
    padding: 24,
    gap: 20,
  },
  time: { fontSize: 56, fontWeight: "800", color: "#fff" },
  instructions: { fontSize: 18, color: "#fff", textAlign: "center" },
  progress: { fontSize: 22, fontWeight: "700", color: "#fff" },
  debugButton: {
    paddingVertical: 8,
    paddingHorizontal: 16,
    borderRadius: 8,
    backgroundColor: "rgba(255,255,255,0.2)",
  },
  debugButtonText: { color: "#fff", fontSize: 12 },
  dismissButton: {
    marginTop: 20,
    paddingVertical: 16,
    paddingHorizontal: 32,
    borderRadius: 14,
    backgroundColor: "#fff",
  },
  dismissButtonDisabled: { opacity: 0.4 },
  dismissText: { color: "#B00020", fontSize: 18, fontWeight: "700" },
  emergency: { position: "absolute", bottom: 24, color: "rgba(255,255,255,0.8)", fontSize: 12 },
});
