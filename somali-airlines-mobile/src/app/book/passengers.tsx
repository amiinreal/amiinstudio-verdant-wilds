import { Redirect, router } from 'expo-router';
import { useEffect, useState } from 'react';
import { KeyboardAvoidingView, Platform, View } from 'react-native';

import { isDomestic } from '@core/airports';
import type { PassengerInput } from '@core/types';

import { Steps } from '@/components/booking';
import { DateInput } from '@/components/date-input';
import { Button, Card, Chip, Field, Notice, Row, Screen, StickyFooter, T, TopBar } from '@/components/ui';
import { api, errorMessage } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { passengersFor, useDraft } from '@/lib/draft';
import { colors } from '@/lib/theme';

const TITLES: Record<PassengerInput['type'], PassengerInput['title'][]> = {
  adult: ['Mr', 'Ms', 'Mrs'],
  child: ['Mstr', 'Miss'],
  infant: ['Mstr', 'Miss'],
};

const TYPE_LABEL = { adult: 'Adult', child: 'Child, 2 to 11', infant: 'Infant, under 2' };

export default function Passengers() {
  const { draft, segments, setPassengers, updatePassenger, setContact } = useDraft();
  const { user } = useAuth();
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const list = passengersFor(draft.query, segments.length, draft.passengers);
    if (user && !list[0].firstName) {
      list[0] = { ...list[0], firstName: user.firstName, lastName: user.lastName };
    }
    setPassengers(list);
    if (user && !draft.contact.email) setContact({ email: user.email, phone: user.phone });
    // Build the list once when the screen opens.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (segments.length === 0) return <Redirect href="/" />;

  const international = segments.some((s) => !isDomestic(s.flight.origin, s.flight.destination));

  const next = async () => {
    setError(null);
    const missing = draft.passengers.findIndex((p) => !p.firstName.trim() || !p.lastName.trim() || !p.dateOfBirth);
    if (missing >= 0) return setError(`Passenger ${missing + 1}: add the name as in the passport and the date of birth.`);
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(draft.contact.email.trim())) return setError('Enter an email address for your tickets.');
    if (draft.contact.phone.replace(/\D/g, '').length < 7) return setError('Enter a phone number we can reach you on.');
    setBusy(true);
    try {
      // The server checks ages against the travel dates.
      await api.quote({ segments: segments.map((s) => ({ flightId: s.flight.id, fare: s.fare })), passengers: draft.passengers, contact: draft.contact, hold: false });
      router.push('/book/seats');
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <Screen
        background={colors.page}
        footer={
          <StickyFooter>
            {error ? <Notice tone="error">{error}</Notice> : null}
            <Button title="Continue to seats" loading={busy} onPress={next} />
          </StickyFooter>
        }>
        <TopBar title="Passengers" />
        <Steps current={2} />
        <View style={{ padding: 16, gap: 16 }}>
          <T v="small">Enter names exactly as they appear in each passport.</T>
          {draft.passengers.map((p, i) => (
            <Card key={i} style={{ gap: 14 }}>
              <T v="h3">{`Passenger ${i + 1}`}</T>
              <T v="small" style={{ marginTop: -10 }}>{TYPE_LABEL[p.type]}</T>
              <Row style={{ flexWrap: 'wrap' }}>
                {TITLES[p.type].map((t) => (
                  <Chip key={t} label={t} selected={p.title === t} onPress={() => updatePassenger(i, { title: t })} />
                ))}
              </Row>
              <Field label="First name" value={p.firstName} onChangeText={(firstName) => updatePassenger(i, { firstName })} autoCapitalize="words" autoComplete={i === 0 ? 'given-name' : 'off'} />
              <Field label="Last name" value={p.lastName} onChangeText={(lastName) => updatePassenger(i, { lastName })} autoCapitalize="words" autoComplete={i === 0 ? 'family-name' : 'off'} />
              <DateInput label="Date of birth" value={p.dateOfBirth} onChange={(dateOfBirth) => updatePassenger(i, { dateOfBirth })} />
              <Field label="Nationality" value={p.nationality} onChangeText={(nationality) => updatePassenger(i, { nationality })} placeholder="Somali" />
              <Field
                label={international ? 'Passport number' : 'Passport or national ID number'}
                value={p.passportNumber}
                onChangeText={(passportNumber) => updatePassenger(i, { passportNumber: passportNumber.toUpperCase() })}
                autoCapitalize="characters"
                hint="You can also add this at check-in."
              />
              {international ? (
                <DateInput label="Passport expiry" value={p.passportExpiry} onChange={(passportExpiry) => updatePassenger(i, { passportExpiry })} hint="Must be valid for 6 months after you arrive." />
              ) : null}
            </Card>
          ))}

          <Card style={{ gap: 14 }}>
            <T v="h3">Contact details</T>
            <T v="small" style={{ marginTop: -8 }}>We send tickets and flight changes here, by email, SMS and WhatsApp.</T>
            <Field label="Email" value={draft.contact.email} onChangeText={(email) => setContact({ ...draft.contact, email })} keyboardType="email-address" autoCapitalize="none" autoComplete="email" />
            <Field label="Mobile number" value={draft.contact.phone} onChangeText={(phone) => setContact({ ...draft.contact, phone })} keyboardType="phone-pad" autoComplete="tel" placeholder="+252 61 555 0142" />
          </Card>
        </View>
      </Screen>
    </KeyboardAvoidingView>
  );
}
