import React from "react";
import { View, Text, StyleSheet, Pressable } from "react-native";
import { useAppStore } from "@/state/appStore";

/**
 * Minimal settings scaffold. Real version needs proper inputs (time picker,
 * sliders/steppers) — left as plain +/- controls here since the point of
 * this pass is the data flow (updateSettings -> store -> rest of app),
 * not final UI polish.
 */
export function SettingsScreen() {
  const settings = useAppStore((s) => s.settings);
  const updateSettings = useAppStore((s) => s.updateSettings);

  return (
    <View style={styles.container}>
      <Row label="Alarm time" value={settings.alarmTime} />

      <Row
        label="Lockout minutes"
        value={String(settings.lockoutMinutes)}
        onDecrement={() =>
          updateSettings({ lockoutMinutes: Math.max(5, settings.lockoutMinutes - 5) })
        }
        onIncrement={() =>
          updateSettings({ lockoutMinutes: Math.min(90, settings.lockoutMinutes + 5) })
        }
      />

      <Row
        label="Activity target (steps)"
        value={String(settings.activityTarget)}
        onDecrement={() =>
          updateSettings({ activityTarget: Math.max(50, settings.activityTarget - 50) })
        }
        onIncrement={() => updateSettings({ activityTarget: settings.activityTarget + 50 })}
      />

      <Row
        label="Alarm dismissal steps"
        value={String(settings.dismissalStepTarget)}
        onDecrement={() =>
          updateSettings({ dismissalStepTarget: Math.max(10, settings.dismissalStepTarget - 10) })
        }
        onIncrement={() =>
          updateSettings({ dismissalStepTarget: settings.dismissalStepTarget + 10 })
        }
      />
    </View>
  );
}

function Row({
  label,
  value,
  onDecrement,
  onIncrement,
}: {
  label: string;
  value: string;
  onDecrement?: () => void;
  onIncrement?: () => void;
}) {
  return (
    <View style={styles.row}>
      <Text style={styles.label}>{label}</Text>
      <View style={styles.controls}>
        {onDecrement && (
          <Pressable style={styles.stepper} onPress={onDecrement}>
            <Text style={styles.stepperText}>-</Text>
          </Pressable>
        )}
        <Text style={styles.value}>{value}</Text>
        {onIncrement && (
          <Pressable style={styles.stepper} onPress={onIncrement}>
            <Text style={styles.stepperText}>+</Text>
          </Pressable>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, padding: 20, gap: 20 },
  row: { flexDirection: "row", justifyContent: "space-between", alignItems: "center" },
  label: { fontSize: 16 },
  controls: { flexDirection: "row", alignItems: "center", gap: 12 },
  stepper: {
    width: 32,
    height: 32,
    borderRadius: 8,
    backgroundColor: "#eee",
    alignItems: "center",
    justifyContent: "center",
  },
  stepperText: { fontSize: 18, fontWeight: "700" },
  value: { fontSize: 16, minWidth: 40, textAlign: "center" },
});
