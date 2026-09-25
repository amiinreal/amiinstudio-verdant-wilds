import { useState } from 'react';
import { Pressable, Text, View } from 'react-native';

import { addDays, dayOfWeek, pad, parseDate } from '@core/time';

import { longDate, monthName } from '@/lib/format';
import { colors, fonts, radius } from '@/lib/theme';

import { Icon } from './icons';
import { Row, T } from './ui';

const WEEK = ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];

function daysIn(y: number, m: number) {
  return new Date(Date.UTC(y, m, 0)).getUTCDate();
}

/** Month calendar. Dates before `min` or after `max` cannot be picked. */
export function Calendar({
  value,
  onChange,
  min,
  max,
  rangeFrom,
  prices,
}: {
  value: string | null;
  onChange: (d: string) => void;
  min: string;
  max?: string;
  rangeFrom?: string | null;
  prices?: Record<string, string>;
}) {
  const start = parseDate(value ?? min);
  const [ym, setYm] = useState({ y: start.y, m: start.m });
  const first = `${ym.y}-${pad(ym.m)}-01`;
  const lead = (dayOfWeek(first) + 6) % 7;
  const count = daysIn(ym.y, ym.m);
  const cells: (string | null)[] = [...Array(lead).fill(null), ...Array.from({ length: count }, (_, i) => addDays(first, i))];
  while (cells.length % 7) cells.push(null);

  const minYm = parseDate(min);
  const canPrev = ym.y > minYm.y || (ym.y === minYm.y && ym.m > minYm.m);
  const shift = (n: number) => {
    const d = new Date(Date.UTC(ym.y, ym.m - 1 + n, 1));
    setYm({ y: d.getUTCFullYear(), m: d.getUTCMonth() + 1 });
  };

  return (
    <View style={{ gap: 10 }}>
      <Row style={{ justifyContent: 'space-between' }}>
        <Pressable accessibilityRole="button" accessibilityLabel="Previous month" disabled={!canPrev} onPress={() => shift(-1)} style={{ width: 44, height: 44, alignItems: 'center', justifyContent: 'center', opacity: canPrev ? 1 : 0.3 }}>
          <Icon.ChevronLeft color={colors.ink} />
        </Pressable>
        <T v="title" accessibilityRole="header">{`${monthName(ym.m)} ${ym.y}`}</T>
        <Pressable accessibilityRole="button" accessibilityLabel="Next month" onPress={() => shift(1)} style={{ width: 44, height: 44, alignItems: 'center', justifyContent: 'center' }}>
          <Icon.Chevron color={colors.ink} />
        </Pressable>
      </Row>
      <View style={{ flexDirection: 'row' }}>
        {WEEK.map((w) => (
          <T key={w} v="label" style={{ flex: 1, textAlign: 'center' }}>{w}</T>
        ))}
      </View>
      <View style={{ flexDirection: 'row', flexWrap: 'wrap' }}>
        {cells.map((d, i) => {
          if (!d) return <View key={`e${i}`} style={{ width: `${100 / 7}%`, height: 52 }} />;
          const off = d < min || (!!max && d > max);
          const sel = d === value;
          const inRange = !!rangeFrom && !!value && d > rangeFrom && d < value;
          const isFrom = d === rangeFrom;
          return (
            <View key={d} style={{ width: `${100 / 7}%`, height: 52, padding: 2 }}>
              <Pressable
                accessibilityRole="button"
                accessibilityState={{ selected: sel, disabled: off }}
                accessibilityLabel={`${longDate(d)}${prices?.[d] ? `, ${prices[d]}` : ''}`}
                disabled={off}
                onPress={() => onChange(d)}
                style={{
                  flex: 1,
                  borderRadius: radius.md,
                  alignItems: 'center',
                  justifyContent: 'center',
                  backgroundColor: sel ? colors.navy : isFrom ? colors.blue : inRange ? colors.mist : 'transparent',
                }}>
                <Text style={{ fontFamily: sel || isFrom ? fonts.bodySemi : fonts.body, fontSize: 16, color: sel || isFrom ? colors.white : off ? colors.inkFaint : colors.ink }}>
                  {parseDate(d).d}
                </Text>
                {prices?.[d] && !off ? (
                  <Text style={{ fontFamily: fonts.body, fontSize: 10, color: sel ? colors.gold : colors.inkSoft }}>{prices[d]}</Text>
                ) : null}
              </Pressable>
            </View>
          );
        })}
      </View>
    </View>
  );
}
