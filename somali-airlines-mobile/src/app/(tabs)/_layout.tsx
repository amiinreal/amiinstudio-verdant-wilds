import { Tabs } from 'expo-router/js-tabs';
import { Platform } from 'react-native';

import { Icon } from '@/components/icons';
import { colors, fonts } from '@/lib/theme';

export default function TabsLayout() {
  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: colors.blue,
        tabBarInactiveTintColor: colors.inkSoft,
        tabBarLabelStyle: { fontFamily: fonts.bodyMedium, fontSize: 12 },
        // Web has no safe-area inset to pad the bar, so give the labels room.
        tabBarStyle: { borderTopColor: colors.lineSoft, backgroundColor: colors.white, ...(Platform.OS === 'web' ? { height: 64, paddingBottom: 8 } : null) },
      }}>
      <Tabs.Screen name="index" options={{ title: 'Book', tabBarIcon: ({ color }) => <Icon.Plane color={color} /> }} />
      <Tabs.Screen name="trips" options={{ title: 'Trips', tabBarIcon: ({ color }) => <Icon.Ticket color={color} /> }} />
      <Tabs.Screen name="status" options={{ title: 'Status', tabBarIcon: ({ color }) => <Icon.Clock color={color} /> }} />
      <Tabs.Screen name="info" options={{ title: 'Info', tabBarIcon: ({ color }) => <Icon.Info color={color} /> }} />
      <Tabs.Screen name="account" options={{ title: 'Account', tabBarIcon: ({ color }) => <Icon.User color={color} /> }} />
    </Tabs>
  );
}
