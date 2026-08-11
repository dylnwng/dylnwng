import React from "react";
import { createNativeStackNavigator } from "@react-navigation/native-stack";
import { HomeScreen } from "@/screens/HomeScreen";
import { AlarmScreen } from "@/screens/AlarmScreen";
import { GateScreen } from "@/screens/GateScreen";
import { SettingsScreen } from "@/screens/SettingsScreen";

export type RootStackParamList = {
  Home: undefined;
  Alarm: undefined;
  Gate: undefined;
  Settings: undefined;
};

const Stack = createNativeStackNavigator<RootStackParamList>();

export function RootNavigator() {
  return (
    <Stack.Navigator initialRouteName="Home">
      <Stack.Screen name="Home" component={HomeScreen} options={{ title: "Morning Lockout" }} />
      <Stack.Screen name="Alarm" component={AlarmScreen} options={{ headerShown: false, gestureEnabled: false }} />
      <Stack.Screen name="Gate" component={GateScreen} options={{ headerShown: false, gestureEnabled: false }} />
      <Stack.Screen name="Settings" component={SettingsScreen} options={{ title: "Settings" }} />
    </Stack.Navigator>
  );
}
