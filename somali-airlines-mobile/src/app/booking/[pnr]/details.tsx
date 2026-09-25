import { router } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, Platform, View } from 'react-native';

import type { Booking } from '@core/types';

import { DateInput } from '@/components/date-input';
import { Button, Card, Chip, Field, Loading, Notice, Row, Screen, StickyFooter, T, TopBar } from '@/components/ui';
import { api, errorMessage, type BookingRef } from '@/lib/api';
import { colors } from '@/lib/theme';
import { useBooking } from '@/lib/use-booking';

const ASSISTANCE = ['Wheelchair to the aircraft door', 'Wheelchair to the seat', 'Blind or low vision', 'Deaf or hard of hearing', 'Travelling with medical equipment'];

type Form = { nationality: string; passportNumber: string; passportExpiry: string; specialAssistance: string | null };

export default function PassengerDetails() {
  const { ref, data: b } = useBooking();
  if (!b) return <Screen><TopBar title="Passport and assistance" /><Loading /></Screen>;
  return <DetailsForm key={b.id} b={b} bookingRef={ref} />;
}

function DetailsForm({ b, bookingRef: ref }: { b: Booking; bookingRef: BookingRef }) {
  const [form, setForm] = useState<Record<string, Form>>(() =>
    Object.fromEntries(b.passengers.map((p) => [p.id, { nationality: p.nationality, passportNumber: p.passportNumber, passportExpiry: p.passportExpiry, specialAssistance: p.specialAssistance }])),
  );
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const set = (id: string, patch: Partial<Form>) => setForm((f) => ({ ...f, [id]: { ...f[id], ...patch } }));

  const save = async () => {
    setBusy(true);
    setError(null);
    try {
      await api.updatePassengerDetails(ref, b.passengers.map((p) => ({ passengerId: p.id, ...form[p.id] })));
      router.back();
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
            <Button title="Save" loading={busy} onPress={save} />
          </StickyFooter>
        }>
        <TopBar title="Passport and assistance" />
        <View style={{ padding: 16, gap: 16 }}>
          {b.passengers.map((p) => {
            const f = form[p.id];
            if (!f) return null;
            return (
              <Card key={p.id} style={{ gap: 14 }}>
                <T v="h3">{`${p.firstName} ${p.lastName}`}</T>
                <Field label="Nationality" value={f.nationality} onChangeText={(nationality) => set(p.id, { nationality })} />
                <Field label="Passport number" value={f.passportNumber} autoCapitalize="characters" onChangeText={(passportNumber) => set(p.id, { passportNumber: passportNumber.toUpperCase() })} />
                <DateInput label="Passport expiry" value={f.passportExpiry} onChange={(passportExpiry) => set(p.id, { passportExpiry })} />
                <T v="bodyStrong" style={{ fontSize: 15 }}>Special assistance</T>
                <Row style={{ flexWrap: 'wrap' }}>
                  <Chip label="None" selected={!f.specialAssistance} onPress={() => set(p.id, { specialAssistance: null })} />
                  {ASSISTANCE.map((a) => (
                    <Chip key={a} label={a} selected={f.specialAssistance === a} onPress={() => set(p.id, { specialAssistance: a })} />
                  ))}
                </Row>
              </Card>
            );
          })}
          <T v="small">Tell us about assistance at least 48 hours before you fly so the airport team is ready.</T>
        </View>
      </Screen>
    </KeyboardAvoidingView>
  );
}
