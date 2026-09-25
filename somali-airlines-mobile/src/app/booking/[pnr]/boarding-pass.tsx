import AsyncStorage from '@react-native-async-storage/async-storage';
import { useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { ScrollView, useWindowDimensions, View } from 'react-native';

import type { BoardingPass } from '@core/service';
import { STATUS_LABEL } from '@core/status';

import { HeroStar, Icon, Logo } from '@/components/icons';
import { QRCode } from '@/components/qr';
import { Band, Loading, Notice, Row, Screen, T, TopBar } from '@/components/ui';
import { api } from '@/lib/api';
import { cityName, dayMonth } from '@/lib/format';
import { colors, fonts, radius } from '@/lib/theme';
import { useAsync } from '@/lib/use-async';
import { useTrips } from '@/lib/trips';

function Item({ label, value, big, span = 1 }: { label: string; value: string; big?: boolean; span?: number }) {
  return (
    <View style={{ width: `${(100 / 3) * span}%`, paddingRight: 8, paddingVertical: 8, gap: 2 }}>
      <T v="label">{label}</T>
      <T style={big ? { fontFamily: fonts.display, fontSize: 26 } : { fontFamily: fonts.bodySemi, fontSize: 18 }}>{value}</T>
    </View>
  );
}

export default function BoardingPassScreen() {
  const { pnr, segment = '0' } = useLocalSearchParams<{ pnr: string; segment: string }>();
  const { refFor } = useTrips();
  const ref = refFor(pnr);
  const passes = useAsync(async () => {
    // Keep a copy on the phone so the pass opens at the gate without signal.
    const key = `sa.pass.${pnr}.${segment}`;
    try {
      const fresh = await api.boardingPasses(ref, Number(segment));
      if (fresh.length) await AsyncStorage.setItem(key, JSON.stringify(fresh));
      return fresh;
    } catch (e) {
      const saved = await AsyncStorage.getItem(key);
      if (saved) return JSON.parse(saved) as BoardingPass[];
      throw e;
    }
  }, [pnr, segment]);
  const { width } = useWindowDimensions();
  const cardW = Math.min(width - 32, 420);
  const [page, setPage] = useState(0);

  return (
    <Screen background={colors.mist}>
      <TopBar
        title="Boarding pass"
        band={false}
        right={
          <View style={{ flexDirection: 'row', alignItems: 'center', gap: 6, paddingHorizontal: 10, paddingVertical: 6, borderRadius: radius.pill, backgroundColor: colors.greenSoft }}>
            <Icon.Check size={14} color={colors.greenInk} />
            <T v="caption" style={{ color: colors.greenInk, fontFamily: fonts.bodySemi }}>Saved</T>
          </View>
        }
      />
      {passes.loading ? <Loading /> : null}
      {passes.error ? <View style={{ padding: 16 }}><Notice tone="error">{passes.error}</Notice></View> : null}
      {passes.data && passes.data.length === 0 ? <View style={{ padding: 16 }}><Notice>No one is checked in on this flight yet.</Notice></View> : null}
      {passes.data && passes.data.length > 0 ? (
        <>
          {passes.data.length > 1 ? <T v="small" style={{ textAlign: 'center', paddingTop: 8 }}>{`Passenger ${page + 1} of ${passes.data.length}. Swipe for the next.`}</T> : null}
          <ScrollView
            horizontal
            pagingEnabled
            snapToInterval={cardW + 16}
            decelerationRate="fast"
            showsHorizontalScrollIndicator={false}
            onMomentumScrollEnd={(e) => setPage(Math.round(e.nativeEvent.contentOffset.x / (cardW + 16)))}
            contentContainerStyle={{ paddingHorizontal: (width - cardW) / 2, gap: 16, paddingVertical: 16 }}>
            {passes.data.map((bp) => (
              <View key={bp.barcode} style={{ width: cardW, backgroundColor: colors.white, borderRadius: 22, overflow: 'hidden', shadowColor: colors.navy, shadowOpacity: 0.2, shadowRadius: 20, shadowOffset: { width: 0, height: 14 }, elevation: 4 }}>
                <View style={{ backgroundColor: colors.blue, padding: 22, paddingTop: 20, gap: 18, overflow: 'hidden' }}>
                  <View style={{ position: 'absolute', right: -60, top: -50, opacity: 0.9 }} pointerEvents="none">
                    <HeroStar size={220} />
                  </View>
                  <Row gap={10}>
                    <Logo size={28} />
                    <T style={{ fontFamily: fonts.display, fontSize: 17, color: colors.white }}>Somali Airlines</T>
                  </Row>
                  <Row style={{ justifyContent: 'space-between', alignItems: 'flex-end' }}>
                    <View>
                      <T style={{ fontFamily: fonts.display, fontSize: 52, lineHeight: 54, color: colors.white }}>{bp.flight.origin}</T>
                      <T v="small" style={{ color: '#E6EEF8' }}>{cityName(bp.flight.origin)}</T>
                    </View>
                    <Icon.Plane size={30} color={colors.white} />
                    <View style={{ alignItems: 'flex-end' }}>
                      <T style={{ fontFamily: fonts.display, fontSize: 52, lineHeight: 54, color: colors.white }}>{bp.flight.destination}</T>
                      <T v="small" style={{ color: '#E6EEF8' }}>{cityName(bp.flight.destination)}</T>
                    </View>
                  </Row>
                </View>
                <View style={{ padding: 22, paddingBottom: 12, flexDirection: 'row', flexWrap: 'wrap' }}>
                  <Item label="Passenger" value={bp.passengerName + (bp.hasInfant ? ' + infant' : '')} span={3} />
                  <Item label="Flight" value={bp.flight.flightNumber} />
                  <Item label="Date" value={dayMonth(bp.flight.date)} />
                  <Item label="Departs" value={bp.flight.delayMin ? bp.flight.estDepartTime : bp.flight.departTime} />
                  <Item label="Boarding" value={bp.boardingTime} big />
                  <Item label="Gate" value={bp.gate ?? 'TBA'} big />
                  <Item label="Seat" value={bp.seat} big />
                  <Item label="Zone" value={bp.zone} />
                  <Item label="Class" value={bp.cabin === 'business' ? 'Business' : `Economy, ${bp.fareName}`} span={2} />
                </View>
                {bp.flight.status === 'delayed' || bp.flight.status === 'cancelled' ? (
                  <View style={{ paddingHorizontal: 22, paddingBottom: 8 }}>
                    <Notice tone="error">{`${STATUS_LABEL[bp.flight.status]}${bp.flight.note ? `: ${bp.flight.note}` : ''}`}</Notice>
                  </View>
                ) : null}
                <View style={{ height: 24, justifyContent: 'center' }} accessible={false}>
                  <View style={{ position: 'absolute', left: -12, width: 24, height: 24, borderRadius: 12, backgroundColor: colors.mist }} />
                  <View style={{ marginHorizontal: 20, borderTopWidth: 2, borderStyle: 'dashed', borderColor: colors.line }} />
                  <View style={{ position: 'absolute', right: -12, width: 24, height: 24, borderRadius: 12, backgroundColor: colors.mist }} />
                </View>
                <View style={{ padding: 22, paddingBottom: 24, alignItems: 'center', gap: 12 }}>
                  <View style={{ padding: 12, borderWidth: 1, borderColor: colors.lineSoft, borderRadius: radius.md }}>
                    <QRCode value={bp.barcode} size={Math.min(220, cardW - 100)} />
                  </View>
                  <T v="small">
                    Booking reference <T style={{ fontFamily: fonts.bodySemi, color: colors.ink, letterSpacing: 1.2 }}>{bp.pnr}</T>
                  </T>
                  {bp.ticketNumber ? <T v="caption">{`Ticket ${bp.ticketNumber}, sequence ${bp.sequence}`}</T> : null}
                </View>
                <Band height={6} />
              </View>
            ))}
          </ScrollView>
          <View style={{ paddingHorizontal: 16, gap: 12 }}>
            <Notice tone="info">{`This pass is saved on your phone and opens without internet. Gate closes at ${passes.data[0].gateClosesTime}.`}</Notice>
          </View>
        </>
      ) : null}
    </Screen>
  );
}
