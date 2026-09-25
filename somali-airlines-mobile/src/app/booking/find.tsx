import { router } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, Platform, View } from 'react-native';

import { Button, Field, Notice, Screen, T, TopBar } from '@/components/ui';
import { api, errorMessage } from '@/lib/api';
import { useTrips } from '@/lib/trips';

export default function FindBooking() {
  const { remember } = useTrips();
  const [pnr, setPnr] = useState('');
  const [lastName, setLastName] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const find = async () => {
    setError(null);
    const ref = { pnr: pnr.trim().toUpperCase(), lastName: lastName.trim() };
    if (ref.pnr.length !== 6) return setError('The booking reference has 6 letters and numbers.');
    if (!ref.lastName) return setError('Enter the last name of one of the passengers.');
    setBusy(true);
    try {
      await api.getBooking(ref);
      remember(ref);
      router.replace({ pathname: '/booking/[pnr]', params: { pnr: ref.pnr } });
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <Screen>
        <TopBar title="Find a booking" />
        <View style={{ padding: 20, gap: 16 }}>
          <T v="h2">Manage a booking or check in</T>
          <T style={{ color: '#4A5B6E' }}>You find the booking reference in your ticket email, SMS or WhatsApp message.</T>
          <Field label="Booking reference" value={pnr} onChangeText={(t) => setPnr(t.toUpperCase())} autoCapitalize="characters" maxLength={6} placeholder="K7QX2M" autoCorrect={false} />
          <Field label="Last name" value={lastName} onChangeText={setLastName} autoCapitalize="words" placeholder="As on the booking" returnKeyType="go" onSubmitEditing={find} />
          {error ? <Notice tone="error">{error}</Notice> : null}
          <Button title="Find booking" loading={busy} onPress={find} />
        </View>
      </Screen>
    </KeyboardAvoidingView>
  );
}
