import React from "react";
import { View, Text, StyleSheet, Pressable } from "react-native";
import type { NativeStackScreenProps } from "@react-navigation/native-stack";
import type { RootStackParamList } from "@/navigation/RootNavigator";
import { useAppStore } from "@/state/appStore";

type Props = NativeStackScreenProps<RootStackParamList, "Home">;

export function HomeScreen({ navigation }: Props) {
  const settings = useAppStore((s) => s.settings);

  return (
    <View style={styles.container}>
      <Text style={styles.title}>Morning Lockout</Text>
      <Text style={styles.subtitle}>
        Alarm at {settings.alarmTime} · {settings.lockoutMinutes} min lockout ·{" "}
        {settings.activityTarget} {settings.activityType === "steps" ? "steps" : "sec motion"}
      </Text>

      <Pressable style={styles.button} onPress={() => navigation.navigate("Settings")}>
        <Text style={styles.buttonText}>Settings</Text>
      </Pressable>

      <Pressable
        style={[styles.button, styles.secondary]}
        onPress={() => navigation.navigate("Alarm")}
      >
        <Text style={styles.buttonText}>Preview alarm screen</Text>
      </Pressable>
    </View>
  );
}

const styles = StyleSheet.create({
  container: { flex: 1, alignItems: "center", justifyContent: "center", padding: 24, gap: 16 },
  title: { fontSize: 28, fontWeight: "700" },
  subtitle: { fontSize: 14, color: "#666", textAlign: "center" },
  button: {
    marginTop: 12,
    paddingVertical: 14,
    paddingHorizontal: 24,
    borderRadius: 12,
    backgroundColor: "#111",
  },
  secondary: { backgroundColor: "#444" },
  buttonText: { color: "#fff", fontSize: 16, fontWeight: "600" },
});
