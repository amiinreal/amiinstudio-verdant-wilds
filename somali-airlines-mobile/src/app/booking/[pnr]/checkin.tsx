import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, Platform, Pressable, View } from 'react-native';

import { isDomestic } from '@core/airports';
import type { Booking } from '@core/types';

import { FlightTimes } from '@/components/booking';
import { DateInput } from '@/components/date-input';
import { Icon } from '@/components/icons';
import { Button, Card, Field, Loading, Notice, Row, Screen, StickyFooter, T, TopBar } from '@/components/ui';
import { api, errorMessage, type BookingRef } from '@/lib/api';
import { longDate } from '@/lib/format';
import { colors, radius } from '@/lib/theme';
import { useBooking } from '@/lib/use-booking';

type Docs = { nationality: string; passportNumber: string; passportExpiry: string };

function Check({ on, label, onPress }: { on: boolean; label: string; onPress: () => void }) {
  return (
    <Pressable accessibilityRole="checkbox" accessibilityState={{ checked: on }} onPress={onPress} style={{ flexDirection: 'row', alignItems: 'center', gap: 12, minHeight: 44 }}>
      <View style={{ width: 26, height: 26, borderRadius: 7, borderWidth: 2, borderColor: on ? colors.blue : colors.lineStrong, backgroundColor: on ? colors.blue : colors.white, alignItems: 'center', justifyContent: 'center' }}>
        {on ? <Icon.Check size={16} color={colors.white} /> : null}
      </View>
      <T style={{ flex: 1 }}>{label}</T>
    </Pressable>
  );
}

export default function CheckIn() {
  const { segment = '0' } = useLocalSearchParams<{ segment: string }>();
  const seg = Number(segment);
  const { pnr, ref, data: b } = useBooking();
  if (!b) return <Screen><TopBar title="Check in" /><Loading /></Screen>;
  return <CheckInForm key={`${b.id}-${seg}`} b={b} seg={seg} bookingRef={ref} pnr={pnr} />;
}

function CheckInForm({ b, seg, bookingRef: ref, pnr }: { b: Booking; seg: number; bookingRef: BookingRef; pnr: string }) {
  const [selected, setSelected] = useState<string[]>(() => b.passengers.filter((p) => !p.checkedIn[seg]).map((p) => p.id));
  const [docs, setDocs] = useState<Record<string, Docs>>(() =>
    Object.fromEntries(b.passengers.map((p) => [p.id, { nationality: p.nationality, passportNumber: p.passportNumber, passportExpiry: p.passportExpiry }])),
  );
  const [agree, setAgree] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const s = b.segments[seg];
  const international = !isDomestic(s.flight.origin, s.flight.destination);
  const todo = b.passengers.filter((p) => !p.checkedIn[seg]);

  const go = async () => {
    setError(null);
    if (!agree) return setError('Confirm the safety declaration to continue.');
    setBusy(true);
    try {
      await api.checkIn(
        ref,
        seg,
        selected,
        selected.map((id) => ({ passengerId: id, ...docs[id] })),
      );
      router.replace({ pathname: '/booking/[pnr]/boarding-pass', params: { pnr, segment: String(seg) } });
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
            <Button title={`Check in ${selected.length} passenger${selected.length === 1 ? '' : 's'}`} disabled={selected.length === 0} loading={busy} onPress={go} />
          </StickyFooter>
        }>
        <TopBar title="Check in" />
        <View style={{ padding: 16, gap: 16 }}>
          <Card style={{ gap: 10 }}>
            <T v="title">{`${s.flight.flightNumber}, ${longDate(s.flight.date)}`}</T>
            <FlightTimes flight={s.flight} compact />
          </Card>

          <Card style={{ gap: 4 }}>
            <T v="title">Who is checking in?</T>
            {todo.map((p) => (
              <Check
                key={p.id}
                on={selected.includes(p.id)}
                label={`${p.firstName} ${p.lastName}${p.type === 'infant' ? ' (infant)' : ''}`}
                onPress={() => setSelected((cur) => (cur.includes(p.id) ? cur.filter((x) => x !== p.id) : [...cur, p.id]))}
              />
            ))}
          </Card>

          {selected.map((id) => {
            const p = b.passengers.find((x) => x.id === id)!;
            const d = docs[id];
            if (!d) return null;
            const set = (patch: Partial<Docs>) => setDocs((cur) => ({ ...cur, [id]: { ...cur[id], ...patch } }));
            return (
              <Card key={id} style={{ gap: 12 }}>
                <T v="title">{`${p.firstName} ${p.lastName}`}</T>
                <Field label="Nationality" value={d.nationality} onChangeText={(nationality) => set({ nationality })} />
                <Field label={international ? 'Passport number' : 'Passport or national ID number'} autoCapitalize="characters" value={d.passportNumber} onChangeText={(passportNumber) => set({ passportNumber: passportNumber.toUpperCase() })} />
                {international ? <DateInput label="Passport expiry" value={d.passportExpiry} onChange={(passportExpiry) => set({ passportExpiry })} /> : null}
              </Card>
            );
          })}

          {international ? (
            <Notice>On a foreign passport you need an approved eTAS for Somalia before you board. We check it at the airport.</Notice>
          ) : null}

          <Card style={{ gap: 8 }}>
            <T v="title">Safety declaration</T>
            <T v="small">Lithium batteries, power banks and e-cigarettes go in your cabin bag only. No flammable, toxic or explosive items in any bag.</T>
            <View style={{ borderRadius: radius.md }}>
              <Check on={agree} onPress={() => setAgree(!agree)} label="I have read this and my bags follow the rules." />
            </View>
          </Card>
          <Row>
            <T v="small">Passengers without a seat get a free one now. Gate closes 20 minutes before departure.</T>
          </Row>
        </View>
      </Screen>
    </KeyboardAvoidingView>
  );
}
