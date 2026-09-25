import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { Pressable, ScrollView, View } from 'react-native';

import { faresForCabin, paxLabel, PAX_FARE_SHARE } from '@core/pricing';
import type { FareFamily } from '@core/types';

import { FareCard, FlightTimes, Steps } from '@/components/booking';
import { Button, Card, Empty, Loading, Notice, Row, Screen, StickyFooter, T, TopBar } from '@/components/ui';
import { api } from '@/lib/api';
import { useDraft } from '@/lib/draft';
import { cityName, dayMonth, dayName, formatUsd, shortDate } from '@/lib/format';
import { colors, fonts, radius } from '@/lib/theme';
import { useAsync } from '@/lib/use-async';

export default function Flights() {
  const { leg = 'out' } = useLocalSearchParams<{ leg: 'out' | 'in' }>();
  const { draft, setQuery, setReturnDate, pick } = useDraft();
  const q = draft.query;
  const inbound = leg === 'in';
  const origin = inbound ? q.destination : q.origin;
  const destination = inbound ? q.origin : q.destination;
  const date = inbound ? q.returnDate! : q.date;
  const picked = inbound ? draft.inbound : draft.outbound;
  const [open, setOpen] = useState<string | null>(picked?.flight.id ?? null);

  const results = useAsync(() => api.searchFlights({ ...q, tripType: 'oneway', origin, destination, date, returnDate: null }), [origin, destination, date, q.adults, q.children, q.infants, q.cabin]);
  const strip = useAsync(() => api.datePrices(origin, destination, date, q.cabin), [origin, destination, date, q.cabin]);

  const families = faresForCabin(q.cabin);
  const paxShare = q.adults * PAX_FARE_SHARE.adult + q.children * PAX_FARE_SHARE.child + q.infants * PAX_FARE_SHARE.infant;
  const who = [paxLabel('adult', q.adults), q.children ? paxLabel('child', q.children) : null, q.infants ? paxLabel('infant', q.infants) : null].filter(Boolean).join(', ');

  const choose = (flightId: string, fare: FareFamily) => {
    const f = results.data?.outbound.find((x) => x.id === flightId);
    if (f) pick(inbound ? 'in' : 'out', { flight: f, fare });
  };

  const next = () => {
    if (!inbound && q.tripType === 'return') router.push({ pathname: '/book/flights', params: { leg: 'in' } });
    else router.push('/book/passengers');
  };

  const pickDate = (d: string) => {
    if (inbound) setReturnDate(d);
    else setQuery({ date: d, returnDate: q.returnDate && q.returnDate < d ? d : q.returnDate });
  };

  const minDate = inbound && draft.outbound ? draft.outbound.flight.date : undefined;

  return (
    <Screen
      background={colors.page}
      footer={
        picked ? (
          <StickyFooter>
            <Row style={{ justifyContent: 'space-between' }}>
              <T v="small">{`${picked.flight.flightNumber}, ${picked.fare[0].toUpperCase()}${picked.fare.slice(1)}, ${who}`}</T>
              <T v="bodyStrong">{formatUsd(Math.round(picked.flight.fares[picked.fare]! * paxShare))}</T>
            </Row>
            <Button title={!inbound && q.tripType === 'return' ? 'Choose return flight' : 'Continue'} onPress={next} />
          </StickyFooter>
        ) : null
      }
      stickyHeaderIndices={[0]}>
      <View>
        <TopBar title={inbound ? 'Return flight' : 'Outbound flight'} />
        <Steps current={1} />
      </View>

      <View style={{ backgroundColor: colors.blue, paddingHorizontal: 20, paddingVertical: 20, gap: 6 }}>
        <T v="h2" style={{ color: colors.white }}>{`${cityName(origin)} to ${cityName(destination)}`}</T>
        <T style={{ color: '#E6EEF8', fontSize: 15 }}>
          {`${q.tripType === 'return' ? 'Return' : 'One way'}, ${shortDate(q.date)}${q.tripType === 'return' && q.returnDate ? ` to ${shortDate(q.returnDate)}` : ''}, ${who}, ${q.cabin === 'business' ? 'Business' : 'Economy'}`}
        </T>
        <Pressable accessibilityRole="button" onPress={() => router.navigate('/')} style={{ alignSelf: 'flex-start', marginTop: 6, paddingHorizontal: 14, minHeight: 40, justifyContent: 'center', borderWidth: 1, borderColor: colors.white, borderRadius: radius.md }}>
          <T style={{ color: colors.white, fontFamily: fonts.bodySemi, fontSize: 15 }}>Change search</T>
        </Pressable>
      </View>

      <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ padding: 16, gap: 8 }} accessibilityLabel="Departure date">
        {(strip.data ?? []).map((d) => {
          const sel = d.date === date;
          const off = d.cheapest == null || (!!minDate && d.date < minDate);
          return (
            <Pressable
              key={d.date}
              accessibilityRole="button"
              accessibilityState={{ selected: sel, disabled: off }}
              disabled={off}
              onPress={() => pickDate(d.date)}
              style={{ width: 84, paddingVertical: 12, alignItems: 'center', gap: 2, borderRadius: radius.lg, borderWidth: 1, borderColor: sel ? colors.navy : colors.line, backgroundColor: sel ? colors.navy : colors.white, opacity: off ? 0.5 : 1 }}>
              <T v="small" style={{ color: sel ? colors.white : colors.inkSoft }}>{dayName(d.date)}</T>
              <T style={{ fontFamily: fonts.bodySemi, fontSize: 17, color: sel ? colors.white : colors.ink }}>{dayMonth(d.date)}</T>
              <T v="small" style={{ color: sel ? colors.gold : colors.inkSoft }}>{d.cheapest == null ? 'No flights' : formatUsd(d.cheapest)}</T>
            </Pressable>
          );
        })}
      </ScrollView>

      <View style={{ paddingHorizontal: 16, gap: 12 }}>
        <T v="h2">{inbound ? 'Choose your return flight' : 'Choose your outbound flight'}</T>
        {results.loading ? <Loading label="Finding flights" /> : null}
        {results.error ? <Notice tone="error">{results.error}</Notice> : null}
        {results.data && results.data.outbound.length === 0 ? (
          <Empty title="No flights this day" body="Try another date in the strip above." />
        ) : null}
        {results.data?.outbound.map((f) => {
          const isOpen = open === f.id;
          const soldOut = f.cheapest == null;
          return (
            <Card key={f.id} style={{ borderRadius: 20, padding: 20, gap: 16, borderColor: picked?.flight.id === f.id ? colors.blue : colors.line }}>
              <FlightTimes flight={f} />
              <Row style={{ justifyContent: 'space-between' }}>
                <View>
                  <T v="small">{`${f.flightNumber}, ${f.aircraft}`}</T>
                  {f.seatsLeft[q.cabin] < 10 && !soldOut ? (
                    <T v="small" style={{ color: colors.clay, fontFamily: fonts.bodySemi }}>{`${f.seatsLeft[q.cabin]} seats left`}</T>
                  ) : null}
                </View>
                <View style={{ alignItems: 'flex-end' }}>
                  <T v="small">{soldOut ? '' : 'from'}</T>
                  <T v="title">{soldOut ? 'Sold out' : formatUsd(f.cheapest!)}</T>
                </View>
              </Row>
              {!soldOut ? (
                <Button small kind={isOpen ? 'ghost' : 'secondary'} title={isOpen ? 'Hide fares' : 'See fares'} onPress={() => setOpen(isOpen ? null : f.id)} />
              ) : null}
              {isOpen
                ? families.map((fam) => (
                    <FareCard
                      key={fam}
                      family={fam}
                      price={f.fares[fam]}
                      selected={picked?.flight.id === f.id && picked.fare === fam}
                      onPick={() => choose(f.id, fam)}
                    />
                  ))
                : null}
            </Card>
          );
        })}
        <T v="small">Fares are per adult, one way, before taxes. Children pay 75% of the fare, infants 10%.</T>
      </View>
    </Screen>
  );
}
