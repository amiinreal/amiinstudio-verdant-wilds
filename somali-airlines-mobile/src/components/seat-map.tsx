import { Pressable, Text, View } from 'react-native';

import type { Cabin, SeatMap as SeatMapT } from '@core/types';

import { formatUsd } from '@/lib/format';
import { colors, fonts, radius } from '@/lib/theme';

import { Row, T } from './ui';

type Props = {
  map: SeatMapT;
  cabin: Cabin;
  /** Seats chosen by this booking: seat -> passenger initials */
  mine: Record<string, string>;
  active: string | null;
  free: boolean;
  onPick: (seat: string) => void;
};

const SIZE = 40;

export function SeatMap({ map, cabin, mine, active, free, onPick }: Props) {
  const rows = map.rows.filter((r) => r.cabin === cabin);
  return (
    <View style={{ gap: 12 }}>
      <Row style={{ flexWrap: 'wrap', gap: 14 }}>
        <Legend color={colors.white} border={colors.lineStrong} label={free ? 'Free' : 'Available'} />
        <Legend color={colors.blue} border={colors.blue} label="Your seats" />
        <Legend color={colors.lineSoft} border={colors.lineSoft} label="Taken" />
        {cabin === 'economy' ? <Legend color={colors.sand} border={colors.sandLine} label="Extra legroom" /> : null}
      </Row>
      <View style={{ alignSelf: 'center', backgroundColor: colors.white, borderRadius: 40, borderWidth: 1, borderColor: colors.line, paddingVertical: 24, paddingHorizontal: 14, gap: 6 }}>
        {rows.map((r) => {
          const groups = cabin === 'business' ? [r.seats.slice(0, 2), r.seats.slice(2)] : [r.seats.slice(0, 3), r.seats.slice(3)];
          return (
            <View key={r.row} style={{ gap: 4 }}>
              {r.exit ? <T v="caption" style={{ textAlign: 'center', color: colors.clay }}>Exit row</T> : null}
              <Row gap={6}>
                {groups.map((g, gi) => (
                  <Row key={gi} gap={6}>
                    {gi === 1 ? <Text style={{ width: 24, textAlign: 'center', fontFamily: fonts.body, fontSize: 12, color: colors.inkSoft }}>{r.row}</Text> : null}
                    {g.map((s) => {
                      const who = mine[s.id];
                      const taken = s.state !== 'free' && !who;
                      const isActive = s.id === active;
                      const extra = s.kind === 'exit' || s.kind === 'front';
                      return (
                        <Pressable
                          key={s.id}
                          accessibilityRole="button"
                          accessibilityState={{ disabled: taken, selected: !!who }}
                          accessibilityLabel={`Seat ${s.id}${taken ? ', taken' : who ? `, ${who}` : free || !s.price ? ', free' : `, ${formatUsd(s.price)}`}`}
                          disabled={taken}
                          onPress={() => onPick(s.id)}
                          style={{
                            width: cabin === 'business' ? SIZE + 8 : SIZE,
                            height: SIZE + 4,
                            borderRadius: radius.sm,
                            borderWidth: isActive ? 2 : 1,
                            borderColor: who ? colors.blue : taken ? colors.lineSoft : extra ? colors.sandLine : colors.lineStrong,
                            backgroundColor: who ? colors.blue : taken ? colors.lineSoft : extra ? colors.sand : colors.white,
                            alignItems: 'center',
                            justifyContent: 'center',
                          }}>
                          <Text style={{ fontFamily: fonts.bodySemi, fontSize: 12, color: who ? colors.white : taken ? colors.inkFaint : colors.ink }}>
                            {who || s.letter}
                          </Text>
                        </Pressable>
                      );
                    })}
                  </Row>
                ))}
              </Row>
            </View>
          );
        })}
      </View>
    </View>
  );
}

function Legend({ color, border, label }: { color: string; border: string; label: string }) {
  return (
    <Row gap={6}>
      <View style={{ width: 18, height: 18, borderRadius: 5, backgroundColor: color, borderWidth: 1, borderColor: border }} />
      <T v="small">{label}</T>
    </Row>
  );
}

export function initials(first: string, last: string) {
  return `${first.trim()[0] ?? ''}${last.trim()[0] ?? ''}`.toUpperCase() || '?';
}
