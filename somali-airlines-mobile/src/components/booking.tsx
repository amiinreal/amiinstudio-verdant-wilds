import { Pressable, View } from 'react-native';

import { fareFeatures, FARE_RULES } from '@core/pricing';
import type { FareFamily, Flight, PriceBreakdown } from '@core/types';

import { cityName, duration, formatUsd } from '@/lib/format';
import { colors, fonts, radius } from '@/lib/theme';

import { Icon } from './icons';
import { Divider, Row, T } from './ui';

export const STEPS = ['Flights', 'Passengers', 'Seats', 'Bags and extras', 'Payment'];

export function Steps({ current }: { current: number }) {
  return (
    <View style={{ paddingHorizontal: 16, paddingVertical: 12, gap: 8, backgroundColor: colors.white }} accessibilityLabel={`Step ${current} of ${STEPS.length}, ${STEPS[current - 1]}`}>
      <Row style={{ justifyContent: 'space-between' }}>
        <T v="small" style={{ color: colors.ink, fontFamily: fonts.bodySemi }}>{`Step ${current} of ${STEPS.length}`}</T>
        <T v="small">{STEPS[current - 1]}</T>
      </Row>
      <Row gap={4}>
        {STEPS.map((_, i) => (
          <View key={i} style={{ flex: 1, height: 4, borderRadius: 2, backgroundColor: i < current ? (i === current - 1 ? colors.blue : colors.green) : colors.lineSoft }} />
        ))}
      </Row>
    </View>
  );
}

export function FlightTimes({ flight, compact }: { flight: Flight; compact?: boolean }) {
  const big = compact ? 26 : 32;
  return (
    <Row style={{ alignItems: 'center' }} gap={12}>
      <View>
        <T style={{ fontFamily: fonts.display, fontSize: big, fontVariant: ['tabular-nums'] }}>{flight.departTime}</T>
        <T v="small">{`${flight.origin} ${cityName(flight.origin)}`}</T>
      </View>
      <View style={{ flex: 1, alignItems: 'center', gap: 4 }}>
        <T v="caption">{duration(flight.durationMin)}</T>
        <Row gap={6} style={{ width: '100%' }}>
          <View style={{ flex: 1, height: 2, backgroundColor: colors.lineStrong }} />
          <Icon.Plane size={18} />
          <View style={{ flex: 1, height: 2, backgroundColor: colors.lineStrong }} />
        </Row>
        <T v="caption" style={{ color: colors.green, fontFamily: fonts.bodySemi }}>Direct</T>
      </View>
      <View style={{ alignItems: 'flex-end' }}>
        <T style={{ fontFamily: fonts.display, fontSize: big, fontVariant: ['tabular-nums'] }}>
          {flight.arriveTime}
          {flight.arriveDayOffset ? <T v="caption" style={{ color: colors.clay }}>{` +${flight.arriveDayOffset}`}</T> : null}
        </T>
        <T v="small">{`${flight.destination} ${cityName(flight.destination)}`}</T>
      </View>
    </Row>
  );
}

export function FareCard({ family, price, selected, onPick, disabled }: { family: FareFamily; price: number | null; selected: boolean; onPick: () => void; disabled?: boolean }) {
  const rules = FARE_RULES[family];
  const off = disabled || price == null;
  return (
    <View style={{ padding: 18, borderRadius: radius.xl, borderWidth: selected ? 2 : 1, borderColor: selected ? colors.blue : colors.line, backgroundColor: selected ? colors.mist : colors.white, gap: 12, opacity: off ? 0.5 : 1 }}>
      <Row style={{ justifyContent: 'space-between', alignItems: 'baseline' }}>
        <T v="h3">{rules.name}</T>
        <T v="title">{price == null ? 'Not sold' : formatUsd(price)}</T>
      </Row>
      <View style={{ gap: 8 }}>
        {fareFeatures(family).map((f) => (
          <Row key={f.text} gap={10} style={{ alignItems: 'flex-start' }}>
            <View style={{ marginTop: 2 }} accessibilityLabel={f.ok ? 'Included' : 'Not included'}>
              {f.ok ? <Icon.Check size={18} color={colors.green} /> : <Icon.Cross size={18} color={colors.lineStrong} />}
            </View>
            <T style={{ fontSize: 15, lineHeight: 21, flex: 1 }}>{f.text}</T>
          </Row>
        ))}
      </View>
      <Pressable
        accessibilityRole="radio"
        accessibilityState={{ selected, disabled: off }}
        disabled={off}
        onPress={onPick}
        style={{ minHeight: 48, borderRadius: radius.md, alignItems: 'center', justifyContent: 'center', backgroundColor: selected ? colors.blue : colors.white, borderWidth: 1, borderColor: colors.blue }}>
        <T style={{ fontFamily: fonts.bodySemi, color: selected ? colors.white : colors.blue }}>{selected ? 'Selected' : `Choose ${rules.name}`}</T>
      </Pressable>
    </View>
  );
}

export function PriceSummary({ price, paid, title = 'Price' }: { price: PriceBreakdown; paid?: number; title?: string }) {
  const due = paid != null ? Math.max(0, Math.round((price.total - paid) * 100) / 100) : null;
  return (
    <View style={{ gap: 10 }}>
      <T v="title">{title}</T>
      {price.lines.map((l) => (
        <Row key={l.label} style={{ justifyContent: 'space-between' }}>
          <T style={{ flex: 1, fontSize: 15 }}>{l.label}</T>
          <T style={{ fontSize: 15 }}>{formatUsd(l.amount)}</T>
        </Row>
      ))}
      <Divider />
      <Row style={{ justifyContent: 'space-between' }}>
        <T v="title">Total</T>
        <T v="title">{formatUsd(price.total)}</T>
      </Row>
      {paid != null && paid > 0 ? (
        <Row style={{ justifyContent: 'space-between' }}>
          <T v="small">Paid</T>
          <T v="small">{formatUsd(paid)}</T>
        </Row>
      ) : null}
      {due != null && due > 0 && paid! > 0 ? (
        <Row style={{ justifyContent: 'space-between' }}>
          <T v="bodyStrong" style={{ color: colors.clay }}>To pay</T>
          <T v="bodyStrong" style={{ color: colors.clay }}>{formatUsd(due)}</T>
        </Row>
      ) : null}
      <T v="small">The price includes all taxes and fees.</T>
    </View>
  );
}
