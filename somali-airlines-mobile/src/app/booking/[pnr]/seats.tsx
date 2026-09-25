import { router } from 'expo-router';
import { useState } from 'react';
import { View } from 'react-native';

import { FARE_RULES } from '@core/pricing';
import type { Booking } from '@core/types';

import { initials, SeatMap } from '@/components/seat-map';
import { Button, Chip, Loading, Notice, Row, Screen, Segmented, StickyFooter, T, TopBar } from '@/components/ui';
import { api, errorMessage, type BookingRef } from '@/lib/api';
import { cityName } from '@/lib/format';
import { colors } from '@/lib/theme';
import { useAsync } from '@/lib/use-async';
import { useBooking } from '@/lib/use-booking';

export default function ManageSeats() {
  const { pnr, ref, data: b } = useBooking();
  if (!b) return <Screen><TopBar title="Seats" /><Loading /></Screen>;
  return <SeatsForm key={b.id} b={b} bookingRef={ref} pnr={pnr} />;
}

function SeatsForm({ b, bookingRef: ref, pnr }: { b: Booking; bookingRef: BookingRef; pnr: string }) {
  const [seg, setSeg] = useState(0);
  const [who, setWho] = useState<string | null>(() => b.passengers.find((p) => p.type !== 'infant')?.id ?? null);
  const [seats, setSeats] = useState<Record<string, (string | null)[]>>(() => Object.fromEntries(b.passengers.map((p) => [p.id, [...p.seats]])));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const flightId = b.segments[seg].flight.id;
  const map = useAsync(() => api.seatMap(flightId, pnr), [flightId, pnr]);

  const s = b.segments[seg];
  const seated = b.passengers.filter((p) => p.type !== 'infant' && !p.checkedIn[seg]);
  const free = FARE_RULES[s.fare].freeSeat;
  const mine: Record<string, string> = {};
  b.passengers.forEach((p) => {
    const x = seats[p.id]?.[seg];
    if (x) mine[x] = initials(p.firstName, p.lastName);
  });
  const active = who ? seats[who]?.[seg] ?? null : null;

  const onPick = (seat: string) => {
    if (!who) return;
    const owner = Object.entries(seats).find(([, v]) => v[seg] === seat)?.[0];
    if (owner && owner !== who) return;
    setSeats((cur) => {
      const next = { ...cur, [who]: [...cur[who]] };
      next[who][seg] = owner === who ? null : seat;
      return next;
    });
  };

  const save = async () => {
    setBusy(true);
    setError(null);
    try {
      const changes = b.passengers.flatMap((p) =>
        b.segments.map((_, i) => ({ passengerId: p.id, segmentIndex: i, seat: seats[p.id]?.[i] ?? null })).filter((c) => c.seat !== p.seats[c.segmentIndex] && !p.checkedIn[c.segmentIndex]),
      );
      if (changes.length === 0) return router.back();
      const updated = await api.updateSeats(ref, changes);
      if (updated.price.total > updated.paid && updated.paid > 0) router.replace({ pathname: '/pay/[pnr]', params: { pnr } });
      else router.back();
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <Screen
      background={colors.page}
      footer={
        <StickyFooter>
          {error ? <Notice tone="error">{error}</Notice> : null}
          <Button title="Save seats" loading={busy} onPress={save} />
        </StickyFooter>
      }>
      <TopBar title="Seats" />
      <View style={{ padding: 16, gap: 14 }}>
        {b.segments.length > 1 ? (
          <Segmented
            label="Flight"
            value={String(seg)}
            onChange={(k) => setSeg(Number(k))}
            options={b.segments.map((x, i) => ({ key: String(i), label: `${cityName(x.flight.origin)} to ${cityName(x.flight.destination)}` }))}
          />
        ) : null}
        {free ? <Notice tone="success">Seat choice is included in your fare.</Notice> : <T v="small">You pay for new seats before check-in. Seats you already paid for are not refunded.</T>}
        {seated.length === 0 ? <Notice>Everyone is checked in on this flight. Ask at the gate to change seats.</Notice> : null}
        <Row style={{ flexWrap: 'wrap' }}>
          {seated.map((p) => (
            <Chip key={p.id} label={`${p.firstName}${seats[p.id]?.[seg] ? ` · ${seats[p.id][seg]}` : ''}`} selected={who === p.id} onPress={() => setWho(p.id)} />
          ))}
        </Row>
        {map.loading ? <Loading label="Loading seat map" /> : null}
        {map.error ? <Notice tone="error">{map.error}</Notice> : null}
        {map.data && seated.length > 0 ? <SeatMap map={map.data} cabin={s.cabin} mine={mine} active={active} free={free} onPick={onPick} /> : null}
      </View>
    </Screen>
  );
}
