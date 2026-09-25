import { router } from 'expo-router';
import { useState } from 'react';
import { View } from 'react-native';

import { extraBagPrice, FARE_RULES } from '@core/pricing';
import type { Booking } from '@core/types';

import { Button, Card, Loading, Notice, Screen, Stepper, StickyFooter, T, TopBar } from '@/components/ui';
import { api, errorMessage, type BookingRef } from '@/lib/api';
import { formatUsd } from '@/lib/format';
import { colors } from '@/lib/theme';
import { useBooking } from '@/lib/use-booking';

export default function ManageBags() {
  const { pnr, ref, data: b } = useBooking();
  if (!b) return <Screen><TopBar title="Bags" /><Loading /></Screen>;
  return <BagsForm key={b.id} b={b} bookingRef={ref} pnr={pnr} />;
}

function BagsForm({ b, bookingRef: ref, pnr }: { b: Booking; bookingRef: BookingRef; pnr: string }) {
  const [bags, setBags] = useState<Record<string, number>>(() => Object.fromEntries(b.passengers.map((p) => [p.id, p.extraBags])));
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const rules = FARE_RULES[b.segments[0].fare];
  const each = b.segments.reduce((s, x) => s + extraBagPrice(x.flight.origin, x.flight.destination), 0);
  const added = b.passengers.reduce((s, p) => s + Math.max(0, (bags[p.id] ?? 0) - p.extraBags), 0);

  const save = async () => {
    setBusy(true);
    setError(null);
    try {
      const changes = b.passengers.filter((p) => p.type !== 'infant' && bags[p.id] !== p.extraBags).map((p) => ({ passengerId: p.id, extraBags: bags[p.id] }));
      if (changes.length === 0) return router.back();
      const updated = await api.updateBags(ref, changes);
      if (updated.paid > 0 && updated.price.total > updated.paid) router.replace({ pathname: '/pay/[pnr]', params: { pnr } });
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
          <Button title={added ? `Add bags, ${formatUsd(added * each)}` : 'Save'} loading={busy} onPress={save} />
        </StickyFooter>
      }>
      <TopBar title="Bags" />
      <View style={{ padding: 16, gap: 16 }}>
        <Card style={{ gap: 6 }}>
          <T v="h3">Included in your fare</T>
          <T>{`Cabin bag, ${rules.cabinBag}.`}</T>
          <T>{rules.checkedBags ? `${rules.checkedBags} × ${rules.checkedBagKg} kg checked bag per passenger.` : 'No checked bag.'}</T>
        </Card>
        <Card style={{ gap: 4 }}>
          <T v="h3">Extra 23 kg bags</T>
          <T v="small">{`${formatUsd(each)} per bag for the whole trip.`}</T>
          {b.passengers.map((p) =>
            p.type === 'infant' ? null : (
              <Stepper
                key={p.id}
                label={`${p.firstName} ${p.lastName}`}
                sub={p.extraBags ? `${p.extraBags} already paid` : undefined}
                value={bags[p.id] ?? 0}
                min={b.paid > 0 ? p.extraBags : 0}
                max={3}
                onChange={(n) => setBags((cur) => ({ ...cur, [p.id]: n }))}
              />
            ),
          )}
        </Card>
      </View>
    </Screen>
  );
}
