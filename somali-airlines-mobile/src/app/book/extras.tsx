import { Redirect, router } from 'expo-router';
import { useState } from 'react';
import { View } from 'react-native';

import { extraBagPrice, FARE_RULES } from '@core/pricing';

import { PriceSummary, Steps } from '@/components/booking';
import { Button, Card, Loading, Notice, Screen, Stepper, StickyFooter, T, TopBar } from '@/components/ui';
import { api, errorMessage } from '@/lib/api';
import { useDraft } from '@/lib/draft';
import { formatUsd } from '@/lib/format';
import { colors } from '@/lib/theme';
import { useTrips } from '@/lib/trips';
import { useAsync } from '@/lib/use-async';

export default function Extras() {
  const { draft, segments, updatePassenger, reset } = useDraft();
  const { remember } = useTrips();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const input = {
    segments: segments.map((s) => ({ flightId: s.flight.id, fare: s.fare })),
    passengers: draft.passengers,
    contact: draft.contact,
    hold: false,
  };
  const quote = useAsync(() => api.quote(input), [JSON.stringify(input)]);

  if (segments.length === 0 || draft.passengers.length === 0) return <Redirect href="/" />;

  const first = segments[0];
  const rules = FARE_RULES[first.fare];
  const bagPrice = segments.reduce((s, sg) => s + extraBagPrice(sg.flight.origin, sg.flight.destination), 0);

  const book = async () => {
    setBusy(true);
    setError(null);
    try {
      const b = await api.createBooking(input);
      const lead = b.passengers.find((p) => p.type === 'adult') ?? b.passengers[0];
      remember({ pnr: b.pnr, lastName: lead.lastName });
      reset();
      router.dismissAll();
      router.push({ pathname: '/pay/[pnr]', params: { pnr: b.pnr } });
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
          <Button title={quote.data ? `Continue to payment, ${formatUsd(quote.data.total)}` : 'Continue to payment'} loading={busy} onPress={book} />
        </StickyFooter>
      }>
      <TopBar title="Bags and extras" />
      <Steps current={4} />
      <View style={{ padding: 16, gap: 16 }}>
        <Card style={{ gap: 6 }}>
          <T v="h3">Your allowance</T>
          <T>{`Cabin bag, ${rules.cabinBag} per passenger.`}</T>
          <T>
            {rules.checkedBags > 0
              ? `${rules.checkedBags} checked bag${rules.checkedBags > 1 ? 's' : ''} of ${rules.checkedBagKg} kg per passenger with a seat.`
              : 'No checked bag on the Saver fare.'}
          </T>
          <T v="small">Infants get one extra 10 kg bag and a folding pushchair for free.</T>
        </Card>

        <Card style={{ gap: 4 }}>
          <T v="h3">Extra checked bags</T>
          <T v="small">{`23 kg each, ${formatUsd(bagPrice)} for the whole trip. Cheaper now than at the airport.`}</T>
          {draft.passengers.map((p, i) =>
            p.type === 'infant' ? null : (
              <Stepper
                key={i}
                label={`${p.firstName} ${p.lastName}`}
                sub={p.extraBags ? `${formatUsd(p.extraBags * bagPrice)}` : 'No extra bags'}
                value={p.extraBags}
                min={0}
                max={3}
                onChange={(extraBags) => updatePassenger(i, { extraBags })}
              />
            ),
          )}
        </Card>

        <Card>
          {quote.loading && !quote.data ? <Loading label="Pricing your trip" /> : null}
          {quote.error ? <Notice tone="error">{quote.error}</Notice> : null}
          {quote.data ? <PriceSummary price={quote.data} /> : null}
        </Card>
        <T v="small">We hold your seats for 30 minutes while you pay.</T>
      </View>
    </Screen>
  );
}
