import { Redirect, router } from 'expo-router';
import { useState } from 'react';
import { View } from 'react-native';

import { FARE_RULES } from '@core/pricing';
import { seatPrice } from '@core/seats';

import { Steps } from '@/components/booking';
import { initials, SeatMap } from '@/components/seat-map';
import { Button, Chip, Loading, Notice, Row, Screen, Segmented, StickyFooter, T, TopBar } from '@/components/ui';
import { api } from '@/lib/api';
import { useDraft } from '@/lib/draft';
import { cityName, formatUsd } from '@/lib/format';
import { colors } from '@/lib/theme';
import { useAsync } from '@/lib/use-async';

export default function Seats() {
  const { draft, segments, updatePassenger } = useDraft();
  const [seg, setSeg] = useState(0);
  const [who, setWho] = useState(0);
  const current = segments[seg];
  const map = useAsync(() => (current ? api.seatMap(current.flight.id) : Promise.resolve(null)), [current?.flight.id]);

  if (!current || draft.passengers.length === 0) return <Redirect href="/" />;

  const seated = draft.passengers.map((p, i) => ({ p, i })).filter(({ p }) => p.type !== 'infant');
  const activeIdx = seated.some((s) => s.i === who) ? who : seated[0].i;
  const free = FARE_RULES[current.fare].freeSeat;
  const mine: Record<string, string> = {};
  draft.passengers.forEach((p) => {
    const s = p.seats[seg];
    if (s) mine[s] = initials(p.firstName, p.lastName);
  });

  const total = segments.reduce(
    (sum, sg, si) => sum + (FARE_RULES[sg.fare].freeSeat ? 0 : draft.passengers.reduce((a, p) => a + (p.seats[si] ? seatPrice(p.seats[si]!) : 0), 0)),
    0,
  );

  const onPick = (seat: string) => {
    const owner = draft.passengers.findIndex((p) => p.seats[seg] === seat);
    const p = draft.passengers[activeIdx];
    const seats = [...p.seats];
    if (owner === activeIdx) {
      seats[seg] = null;
      updatePassenger(activeIdx, { seats });
      return;
    }
    if (owner >= 0) return;
    seats[seg] = seat;
    updatePassenger(activeIdx, { seats });
    // Move on to the next passenger without a seat.
    const nextFree = seated.find(({ p: q, i }) => i !== activeIdx && !q.seats[seg]);
    if (nextFree) setWho(nextFree.i);
  };

  const activeSeat = draft.passengers[activeIdx]?.seats[seg] ?? null;

  return (
    <Screen
      background={colors.page}
      footer={
        <StickyFooter>
          <Row style={{ justifyContent: 'space-between' }}>
            <T v="small">Seats are optional. We assign free seats at check-in.</T>
          </Row>
          <Button title={total > 0 ? `Continue, seats ${formatUsd(total)}` : 'Continue'} onPress={() => router.push('/book/extras')} />
        </StickyFooter>
      }>
      <TopBar title="Seats" />
      <Steps current={3} />
      <View style={{ padding: 16, gap: 14 }}>
        {segments.length > 1 ? (
          <Segmented
            label="Flight"
            value={String(seg)}
            onChange={(k) => setSeg(Number(k))}
            options={segments.map((s, i) => ({ key: String(i), label: `${cityName(s.flight.origin)} to ${cityName(s.flight.destination)}` }))}
          />
        ) : null}
        <T v="title">{`${current.flight.flightNumber}, ${cityName(current.flight.origin)} to ${cityName(current.flight.destination)}`}</T>
        {free ? <Notice tone="success">{`Seat choice is included in your ${FARE_RULES[current.fare].name} fare.`}</Notice> : null}
        <T v="small">Choosing a seat for</T>
        <Row style={{ flexWrap: 'wrap' }}>
          {seated.map(({ p, i }) => (
            <Chip
              key={i}
              label={`${p.firstName || `Passenger ${i + 1}`}${p.seats[seg] ? ` · ${p.seats[seg]}` : ''}`}
              selected={i === activeIdx}
              onPress={() => setWho(i)}
            />
          ))}
        </Row>
        {activeSeat ? (
          <T v="small">{`Tap ${activeSeat} again to remove it.`}</T>
        ) : (
          <T v="small">{free ? 'Tap a free seat.' : 'Standard seats USD 10, front rows USD 15, exit rows USD 25.'}</T>
        )}
        {map.loading ? <Loading label="Loading seat map" /> : null}
        {map.error ? <Notice tone="error">{map.error}</Notice> : null}
        {map.data ? <SeatMap map={map.data} cabin={FARE_RULES[current.fare].cabin} mine={mine} active={activeSeat} free={free} onPick={onPick} /> : null}
        {FARE_RULES[current.fare].cabin === 'economy' ? <T v="small">Exit row seats are for adults able to help in an emergency.</T> : null}
      </View>
    </Screen>
  );
}
