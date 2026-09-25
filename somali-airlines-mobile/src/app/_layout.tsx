// Import single weights so only the fonts we use end up in the bundle.
import { BricolageGrotesque_500Medium } from '@expo-google-fonts/bricolage-grotesque/500Medium';
import { BricolageGrotesque_700Bold } from '@expo-google-fonts/bricolage-grotesque/700Bold';
import { IBMPlexSans_400Regular } from '@expo-google-fonts/ibm-plex-sans/400Regular';
import { IBMPlexSans_500Medium } from '@expo-google-fonts/ibm-plex-sans/500Medium';
import { IBMPlexSans_600SemiBold } from '@expo-google-fonts/ibm-plex-sans/600SemiBold';
import { useFonts } from 'expo-font';
import { Stack } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { StatusBar } from 'expo-status-bar';
import { useEffect } from 'react';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { AuthProvider } from '@/lib/auth';
import { DraftProvider } from '@/lib/draft';
import { PaymentsProvider } from '@/lib/payments';
import { colors } from '@/lib/theme';
import { TripsProvider } from '@/lib/trips';

SplashScreen.preventAutoHideAsync();

export default function RootLayout() {
  const [loaded, fontError] = useFonts({
    BricolageGrotesque_500Medium,
    BricolageGrotesque_700Bold,
    IBMPlexSans_400Regular,
    IBMPlexSans_500Medium,
    IBMPlexSans_600SemiBold,
  });

  useEffect(() => {
    if (loaded || fontError) SplashScreen.hideAsync();
  }, [loaded, fontError]);

  if (!loaded && !fontError) return null;

  return (
    <SafeAreaProvider>
      <PaymentsProvider>
        <AuthProvider>
          <TripsProvider>
            <DraftProvider>
              <StatusBar style="dark" />
              <Stack screenOptions={{ headerShown: false, contentStyle: { backgroundColor: colors.white } }}>
                <Stack.Screen name="(tabs)" />
                <Stack.Screen name="airports" options={{ presentation: 'modal' }} />
                <Stack.Screen name="auth/login" options={{ presentation: 'modal' }} />
                <Stack.Screen name="auth/register" options={{ presentation: 'modal' }} />
                <Stack.Screen name="auth/forgot" options={{ presentation: 'modal' }} />
              </Stack>
            </DraftProvider>
          </TripsProvider>
        </AuthProvider>
      </PaymentsProvider>
    </SafeAreaProvider>
  );
}
