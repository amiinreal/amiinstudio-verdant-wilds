import { router } from 'expo-router';
import { useState } from 'react';
import { View } from 'react-native';

import { FARE_RULES } from '@core/pricing';
import { balanceDue } from '@core/service';
import { addDays, todayAt } from '@core/time';
import type { Booking } from '@core/types';

import { Calendar } from '@/components/calendar';
import { FlightTimes } from '@/components/booking';
import { Button, Card, Empty, Loading, Notice, Row, Screen, Segmented, T, TopBar } from '@/components/ui';
import { api, errorMessage, type BookingRef } from '@/lib/api';
import { cityName, formatUsd, longDate } from '@/lib/format';
import { colors } from '@/lib/theme';
import { useAsync } from '@/lib/use-async';
import { useBooking } from '@/lib/use-booking';

export default function ChangeFlight() {
  const { pnr, ref, data: b } = useBooking();
  if (!b) return <Screen><TopBar title="Change flight" /><Loading /></Screen>;
  return <ChangeForm key={b.id} b={b} bookingRef={ref} pnr={pnr} />;
}

function ChangeForm({ b, bookingRef: ref, pnr }: { b: Booking; bookingRef: BookingRef; pnr: string }) {
  const [seg, setSeg] = useState(0);
  const [date, setDate] = useState<string>(() => b.segments[0].flight.date);
  const [busy, setBusy] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const options = useAsync(() => api.changeOptions(ref, seg, date), [b.id, seg, date]);

  const s = b.segments[seg];
  const rules = FARE_RULES[s.fare];
  const today = todayAt(3);

  const change = async (flightId: string) => {
    setBusy(flightId);
    setError(null);
    try {
      const updated = await api.changeFlight(ref, seg, flightId);
      if (balanceDue(updated) > 0 && updated.status === 'confirmed') router.replace({ pathname: '/pay/[pnr]', params: { pnr } });
      else router.back();
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(null);
    }
  };

  return (
    <Screen background={colors.page}>
      <TopBar title="Change flight" />
      <View style={{ padding: 16, gap: 16 }}>
        {b.segments.length > 1 ? (
          <Segmented
            label="Flight to change"
            value={String(seg)}
            onChange={(k) => {
              setSeg(Number(k));
              setDate(b.segments[Number(k)].flight.date);
            }}
            options={b.segments.map((x, i) => ({ key: String(i), label: i === 0 ? 'Outbound' : 'Return' }))}
          />
        ) : null}
        <Card style={{ gap: 8 }}>
          <T v="label">Now booked</T>
          <T v="title">{`${s.flight.flightNumber}, ${longDate(s.flight.date)}`}</T>
          <T v="small">{`${cityName(s.flight.origin)} to ${cityName(s.flight.destination)}, ${s.flight.departTime}`}</T>
        </Card>
        {rules.changeFee === null ? (
          <Notice tone="error">This fare cannot be changed.</Notice>
        ) : (
          <>
            <T v="small">
              {rules.changeFee > 0
                ? `${rules.name} fares pay a ${formatUsd(rules.changeFee)} change fee per passenger, plus any fare difference.`
                : `${rules.name} fares change for free. You only pay any fare difference.`}
            </T>
            <Card>
              <Calendar
                value={date}
                onChange={setDate}
                min={seg === 1 ? b.segments[0].flight.date : today}
                max={seg === 0 && b.segments[1] ? b.segments[1].flight.date : addDays(today, 330)}
              />
            </Card>
            {options.loading ? <Loading label="Finding flights" /> : null}
            {options.error ? <Notice tone="error">{options.error}</Notice> : null}
            {options.data && options.data.length === 0 && !options.loading ? <Empty title="No other flights" body="Pick another date." /> : null}
            {options.data?.map((o) => (
              <Card key={o.flight.id} style={{ gap: 12 }}>
                <FlightTimes flight={o.flight} compact />
                <Row style={{ justifyContent: 'space-between' }}>
                  <T v="small">{o.flight.flightNumber}</T>
                  <T v="bodyStrong">{o.toPay > 0 ? `Pay ${formatUsd(o.toPay)}` : 'No extra cost'}</T>
                </Row>
                <Button small title="Move to this flight" loading={busy === o.flight.id} disabled={!!busy} onPress={() => change(o.flight.id)} />
              </Card>
            ))}
            <T v="small">Seats on the changed flight are cleared. Pick new ones after the change.</T>
          </>
        )}
        {error ? <Notice tone="error">{error}</Notice> : null}
      </View>
    </Screen>
  );
}
