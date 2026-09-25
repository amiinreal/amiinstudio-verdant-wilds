import { useState } from 'react';
import { TextInput, View } from 'react-native';

import { isValidDate, pad } from '@core/time';

import { colors, fonts, radius } from '@/lib/theme';

import { Row, T } from './ui';

/** Day / month / year boxes that produce YYYY-MM-DD, easier than a spinner for birth dates. */
export function DateInput({ label, value, onChange, error, hint }: { label: string; value: string; onChange: (v: string) => void; error?: string | null; hint?: string }) {
  // Local text so half-typed dates stay on screen; the parent only sees complete ones.
  const [parts, setParts] = useState(() => {
    if (!value) return { d: '', m: '', y: '' };
    const [vy, vm, vd] = value.split('-');
    return { d: String(Number(vd)), m: String(Number(vm)), y: vy };
  });

  const update = (patch: Partial<typeof parts>) => {
    const next = { ...parts, ...patch };
    setParts(next);
    const iso = `${next.y}-${pad(Number(next.m))}-${pad(Number(next.d))}`;
    onChange(next.y.length === 4 && next.m && next.d && isValidDate(iso) ? iso : '');
  };

  const box = (key: 'd' | 'm' | 'y', placeholder: string, max: number, flex: number) => (
    <TextInput
      value={parts[key]}
      onChangeText={(t) => update({ [key]: t.replace(/\D/g, '').slice(0, max) })}
      placeholder={placeholder}
      placeholderTextColor={colors.inkFaint}
      keyboardType="number-pad"
      accessibilityLabel={`${label}, ${placeholder}`}
      style={{
        flex,
        borderWidth: 1,
        borderColor: error ? colors.red : colors.lineStrong,
        borderRadius: radius.lg,
        paddingHorizontal: 14,
        paddingVertical: 14,
        fontSize: 17,
        fontFamily: fonts.body,
        color: colors.ink,
        textAlign: 'center',
      }}
    />
  );

  return (
    <View style={{ gap: 6 }}>
      <T v="bodyStrong" style={{ fontSize: 15 }}>{label}</T>
      <Row>
        {box('d', 'DD', 2, 1)}
        {box('m', 'MM', 2, 1)}
        {box('y', 'YYYY', 4, 1.6)}
      </Row>
      {error ? <T v="small" style={{ color: colors.red }}>{error}</T> : hint ? <T v="small">{hint}</T> : null}
    </View>
  );
}
