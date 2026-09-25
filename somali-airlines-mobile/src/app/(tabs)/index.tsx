import { router } from 'expo-router';
import { useState } from 'react';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { findAirport } from '@core/airports';
import { baseFare } from '@core/schedule';
import { addDays, todayAt } from '@core/time';

import { Calendar } from '@/components/calendar';
import { Scene } from '@/components/destinations';
import { HeroStar, Icon } from '@/components/icons';
import { Sheet } from '@/components/sheet';
import { BrandBar, Band, Button, Chip, FieldButton, Notice, Row, Segmented, Stepper, T } from '@/components/ui';
import { api } from '@/lib/api';
import { useDraft } from '@/lib/draft';
import { cityCode, formatUsd, shortDate } from '@/lib/format';
import { colors, fonts, radius } from '@/lib/theme';

const FEATURED = ['HGA', 'GGR', 'BSA', 'KMU', 'NBO', 'DXB'];

export default function Home() {
  const { draft, setQuery } = useDraft();
  const q = draft.query;
  const [dateSheet, setDateSheet] = useState<'depart' | 'return' | null>(null);
  const [paxSheet, setPaxSheet] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const today = todayAt(3);

  const travellers = [
    `${q.adults} adult${q.adults > 1 ? 's' : ''}`,
    q.children ? `${q.children} child${q.children > 1 ? 'ren' : ''}` : null,
    q.infants ? `${q.infants} infant${q.infants > 1 ? 's' : ''}` : null,
  ]
    .filter(Boolean)
    .join(', ');

  const search = () => {
    setError(null);
    if (q.origin === q.destination) return setError('Choose two different cities.');
    if (q.tripType === 'return' && (!q.returnDate || q.returnDate < q.date)) return setError('Choose a return date after the departure date.');
    router.push({ pathname: '/book/flights', params: { leg: 'out' } });
  };

  return (
    <SafeAreaView edges={['top']} style={{ flex: 1, backgroundColor: colors.white }}>
      <BrandBar
        right={
          api.mode === 'demo' ? (
            <View style={s.demo}>
              <T v="caption" style={{ color: colors.greenInk, fontFamily: fonts.bodySemi }}>Demo</T>
            </View>
          ) : null
        }
      />
      <ScrollView contentContainerStyle={{ paddingBottom: 0 }} keyboardShouldPersistTaps="handled">
        <View style={s.hero}>
          <View style={{ position: 'absolute', right: -120, top: -40 }} pointerEvents="none">
            <HeroStar size={380} />
          </View>
          <T accessibilityLanguage="so" style={{ color: colors.gold, fontFamily: fonts.bodyMedium, fontSize: 17 }}>Ku soo dhawoow</T>
          <T v="hero" style={{ color: colors.white }} accessibilityRole="header">The White Star is flying again.</T>
        </View>

        <View style={s.searchCard} accessibilityLabel="Find a flight">
          <Segmented
            label="Trip type"
            value={q.tripType}
            onChange={(tripType) => setQuery({ tripType, returnDate: tripType === 'return' ? q.returnDate ?? addDays(q.date, 7) : q.returnDate })}
            options={[
              { key: 'return', label: 'Return' },
              { key: 'oneway', label: 'One way' },
            ]}
          />
          <View style={{ gap: 8 }}>
            <FieldButton label="From" value={cityCode(q.origin)} onPress={() => router.push({ pathname: '/airports', params: { field: 'origin' } })} />
            <FieldButton label="To" value={cityCode(q.destination)} onPress={() => router.push({ pathname: '/airports', params: { field: 'destination' } })} />
            <Pressable
              accessibilityRole="button"
              accessibilityLabel="Swap origin and destination"
              onPress={() => setQuery({ origin: q.destination, destination: q.origin })}
              style={s.swap}>
              <Icon.Swap size={18} strokeWidth={2} />
            </Pressable>
          </View>
          <Row>
            <FieldButton style={{ flex: 1 }} label="Depart" value={shortDate(q.date)} onPress={() => setDateSheet('depart')} />
            {q.tripType === 'return' && (
              <FieldButton style={{ flex: 1 }} label="Return" value={q.returnDate ? shortDate(q.returnDate) : ''} placeholder="Add date" onPress={() => setDateSheet('return')} />
            )}
          </Row>
          <FieldButton
            label="Travellers and cabin"
            value={`${travellers}, ${q.cabin === 'business' ? 'Business' : 'Economy'}`}
            onPress={() => setPaxSheet(true)}
          />
          {error ? <Notice tone="error">{error}</Notice> : null}
          <Button title="Search flights" onPress={search} />
        </View>

        <View style={s.quick}>
          {[
            { label: 'My booking', icon: <Icon.Booking />, go: () => router.push('/trips') },
            { label: 'Check in', icon: <Icon.Ticket />, go: () => router.push('/trips') },
            { label: 'Flight status', icon: <Icon.Clock />, go: () => router.push('/status') },
            { label: 'Baggage', icon: <Icon.Bag />, go: () => router.push('/info/baggage') },
          ].map((l) => (
            <Pressable key={l.label} accessibilityRole="button" onPress={l.go} style={({ pressed }) => [s.quickItem, pressed && { opacity: 0.8 }]}>
              {l.icon}
              <T v="bodyStrong">{l.label}</T>
            </Pressable>
          ))}
        </View>

        <View style={{ paddingHorizontal: 16, paddingTop: 20 }}>
          <Notice>
            <T style={{ fontSize: 15, lineHeight: 22 }}>Travelling on a foreign passport? You need an approved eTAS before you board, children and infants too.</T>
            <Pressable accessibilityRole="button" onPress={() => router.push('/info/documents')}>
              <T style={{ color: colors.blue, fontFamily: fonts.bodySemi, fontSize: 15 }}>Check what you need</T>
            </Pressable>
          </Notice>
        </View>

        <View style={{ paddingTop: 40, gap: 16 }}>
          <View style={{ paddingHorizontal: 20, gap: 6 }}>
            <T v="h1" style={{ fontSize: 30 }} accessibilityRole="header">Where we’re heading</T>
            <T style={{ color: colors.inkSoft }}>Fly direct from Muqdisho.</T>
          </View>
          <ScrollView horizontal showsHorizontalScrollIndicator={false} contentContainerStyle={{ paddingHorizontal: 20, gap: 12 }}>
            {FEATURED.map((code) => {
              const a = findAirport(code)!;
              return (
                <View key={code} style={{ width: 220, gap: 10 }}>
                  <Scene code={code} />
                  <View>
                    <T v="h3">{a.city}</T>
                    <T v="small">{`${a.name}, ${a.code}`}</T>
                  </View>
                  <T v="small">{`One way from ${formatUsd(baseFare('MGQ', code) - 1)}`}</T>
                  <Button
                    small
                    kind="secondary"
                    title="Find flights"
                    style={{ alignSelf: 'flex-start', borderRadius: radius.pill }}
                    onPress={() => {
                      setQuery({ origin: 'MGQ', destination: code });
                      router.push({ pathname: '/book/flights', params: { leg: 'out' } });
                    }}
                  />
                </View>
              );
            })}
          </ScrollView>
        </View>

        <View style={[s.panel, { backgroundColor: colors.mist, marginTop: 40 }]}>
          <T v="h2" accessibilityRole="header">Pay the way you already pay</T>
          <T style={{ color: colors.inkSoft, fontSize: 15, lineHeight: 22 }}>EVC Plus, ZAAD, SAHAL, WAAFI or card. A relative can approve the payment on their own phone.</T>
          <Row style={{ flexWrap: 'wrap' }}>
            {['EVC Plus', 'ZAAD', 'SAHAL', 'WAAFI', 'Visa', 'Mastercard'].map((m) => (
              <View key={m} style={s.payPill}>
                <T v="small" style={{ color: colors.ink, fontFamily: fonts.bodySemi }}>{m}</T>
              </View>
            ))}
          </Row>
        </View>

        <View style={[s.panel, { borderWidth: 1, borderColor: colors.line, marginTop: 16 }]}>
          <T v="title" accessibilityRole="header">Need a hand?</T>
          <T style={{ color: colors.inkSoft, fontSize: 15, lineHeight: 22 }}>Write to us in Somali, English or Arabic. A person answers.</T>
          <Button kind="whatsapp" title="Message us on WhatsApp" onPress={() => router.push('/info/contact')} />
        </View>

        <View style={s.footer}>
          <Band />
          <View style={{ paddingHorizontal: 20, paddingTop: 12, flexDirection: 'row', flexWrap: 'wrap', rowGap: 14 }}>
            {[
              ['Travel documents', 'documents'],
              ['Special assistance', 'assistance'],
              ['Our story', 'story'],
              ['Conditions of carriage', 'conditions'],
              ['Privacy', 'privacy'],
              ['Accessibility', 'accessibility'],
            ].map(([label, slug]) => (
              <Pressable key={slug} accessibilityRole="button" onPress={() => router.push(`/info/${slug}`)} style={{ width: '50%', minHeight: 32, justifyContent: 'center' }}>
                <T style={{ color: colors.footerText, fontSize: 15 }}>{label}</T>
              </Pressable>
            ))}
          </View>
          <T v="caption" style={{ color: colors.inkFaint, paddingHorizontal: 20, fontSize: 13 }}>
            Concept app. Not an official Somali Airlines service.
          </T>
        </View>
      </ScrollView>

      <Sheet
        visible={dateSheet !== null}
        title={dateSheet === 'return' ? 'Return date' : 'Departure date'}
        onClose={() => setDateSheet(null)}>
        <Calendar
          value={dateSheet === 'return' ? q.returnDate ?? null : q.date}
          min={dateSheet === 'return' ? q.date : today}
          max={addDays(today, 330)}
          rangeFrom={dateSheet === 'return' ? q.date : null}
          onChange={(d) => {
            if (dateSheet === 'return') setQuery({ returnDate: d });
            else setQuery({ date: d, returnDate: q.returnDate && q.returnDate < d ? addDays(d, 7) : q.returnDate });
            setDateSheet(null);
          }}
        />
      </Sheet>

      <Sheet visible={paxSheet} title="Travellers and cabin" onClose={() => setPaxSheet(false)} footer={<Button title="Done" onPress={() => setPaxSheet(false)} />}>
        <Stepper label="Adults" sub="12 years and over" value={q.adults} min={1} max={9 - q.children} onChange={(adults) => setQuery({ adults, infants: Math.min(q.infants, adults) })} />
        <Stepper label="Children" sub="2 to 11 years" value={q.children} min={0} max={9 - q.adults} onChange={(children) => setQuery({ children })} />
        <Stepper label="Infants" sub="Under 2, on an adult's lap" value={q.infants} min={0} max={q.adults} onChange={(infants) => setQuery({ infants })} />
        <T v="bodyStrong" style={{ marginTop: 8 }}>Cabin</T>
        <Row>
          <Chip label="Economy" selected={q.cabin === 'economy'} onPress={() => setQuery({ cabin: 'economy' })} />
          <Chip label="Business" selected={q.cabin === 'business'} onPress={() => setQuery({ cabin: 'business' })} />
        </Row>
      </Sheet>
    </SafeAreaView>
  );
}

const s = StyleSheet.create({
  hero: { backgroundColor: colors.blue, overflow: 'hidden', paddingTop: 36, paddingHorizontal: 20, paddingBottom: 132, gap: 14 },
  searchCard: {
    marginTop: -104,
    marginHorizontal: 16,
    backgroundColor: colors.white,
    borderWidth: 1,
    borderColor: colors.cardLine,
    borderRadius: radius.xxl,
    padding: 20,
    gap: 12,
    shadowColor: colors.navy,
    shadowOpacity: 0.25,
    shadowRadius: 20,
    shadowOffset: { width: 0, height: 16 },
    elevation: 6,
  },
  swap: {
    position: 'absolute',
    right: 14,
    top: 42,
    width: 44,
    height: 44,
    borderRadius: radius.pill,
    borderWidth: 1,
    borderColor: colors.line,
    backgroundColor: colors.white,
    alignItems: 'center',
    justifyContent: 'center',
  },
  quick: { paddingHorizontal: 16, paddingTop: 24, flexDirection: 'row', flexWrap: 'wrap', gap: 10 },
  quickItem: {
    flexBasis: '47%',
    flexGrow: 1,
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    minHeight: 64,
    paddingHorizontal: 16,
    borderRadius: radius.xl,
    backgroundColor: colors.mist,
  },
  panel: { marginHorizontal: 16, padding: 20, paddingVertical: 24, borderRadius: 18, gap: 12 },
  payPill: { paddingHorizontal: 12, paddingVertical: 6, borderRadius: radius.pill, backgroundColor: colors.white, borderWidth: 1, borderColor: colors.line },
  footer: { marginTop: 40, backgroundColor: colors.navy, gap: 16, paddingBottom: 32 },
  demo: { backgroundColor: colors.greenSoft, paddingHorizontal: 10, paddingVertical: 4, borderRadius: radius.pill, marginRight: 8 },
});

