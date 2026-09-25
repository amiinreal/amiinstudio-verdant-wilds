import { router } from 'expo-router';
import { forwardRef, type ReactNode } from 'react';
import {
  ActivityIndicator,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
  type PressableProps,
  type ScrollViewProps,
  type StyleProp,
  type TextInputProps,
  type TextProps,
  type TextStyle,
  type ViewStyle,
} from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { bandColors, colors, fonts, radius, space } from '@/lib/theme';

import { Icon, Logo } from './icons';

// ---------- Text ----------

type Variant = 'hero' | 'h1' | 'h2' | 'h3' | 'title' | 'body' | 'bodyStrong' | 'small' | 'label' | 'caption';

const text = StyleSheet.create({
  hero: { fontFamily: fonts.display, fontSize: 44, lineHeight: 46, letterSpacing: -1.3, color: colors.ink },
  h1: { fontFamily: fonts.display, fontSize: 32, lineHeight: 36, letterSpacing: -0.6, color: colors.ink },
  h2: { fontFamily: fonts.display, fontSize: 26, lineHeight: 30, letterSpacing: -0.4, color: colors.ink },
  h3: { fontFamily: fonts.display, fontSize: 22, lineHeight: 26, color: colors.ink },
  title: { fontFamily: fonts.bodySemi, fontSize: 18, lineHeight: 24, color: colors.ink },
  body: { fontFamily: fonts.body, fontSize: 16, lineHeight: 24, color: colors.ink },
  bodyStrong: { fontFamily: fonts.bodySemi, fontSize: 16, lineHeight: 24, color: colors.ink },
  small: { fontFamily: fonts.body, fontSize: 14, lineHeight: 20, color: colors.inkSoft },
  label: { fontFamily: fonts.body, fontSize: 13, lineHeight: 18, color: colors.inkSoft },
  caption: { fontFamily: fonts.body, fontSize: 12, lineHeight: 16, color: colors.inkSoft },
});

export function T({ v = 'body', style, ...rest }: TextProps & { v?: Variant }) {
  return <Text {...rest} style={[text[v], style]} />;
}

// ---------- Layout ----------

export function Band({ height = 5 }: { height?: number }) {
  // The design's repeating woven stripe, drawn as a row of blocks.
  const cycle = bandColors.reduce((s, b) => s + b.w, 0);
  const reps = Math.ceil(1600 / cycle);
  return (
    <View accessible={false} importantForAccessibility="no-hide-descendants" style={{ height, flexDirection: 'row', overflow: 'hidden' }}>
      {Array.from({ length: reps }).flatMap((_, i) =>
        bandColors.map((b, j) => <View key={`${i}-${j}`} style={{ width: b.w, height, backgroundColor: b.color }} />),
      )}
    </View>
  );
}

export function Screen({
  children,
  scroll = true,
  background = colors.white,
  edges = ['top'],
  contentStyle,
  footer,
  ...rest
}: {
  children: ReactNode;
  scroll?: boolean;
  background?: string;
  edges?: ('top' | 'bottom')[];
  contentStyle?: StyleProp<ViewStyle>;
  footer?: ReactNode;
} & ScrollViewProps) {
  return (
    <SafeAreaView edges={edges} style={{ flex: 1, backgroundColor: background }}>
      {scroll ? (
        <ScrollView keyboardShouldPersistTaps="handled" contentContainerStyle={[{ paddingBottom: 32 }, contentStyle]} {...rest}>
          {children}
        </ScrollView>
      ) : (
        <View style={[{ flex: 1 }, contentStyle]}>{children}</View>
      )}
      {footer}
    </SafeAreaView>
  );
}

export function TopBar({ title, onBack, right, band = true }: { title?: string; onBack?: (() => void) | false; right?: ReactNode; band?: boolean }) {
  const back = onBack === false ? null : onBack ?? (() => (router.canGoBack() ? router.back() : router.replace('/')));
  return (
    <View style={{ backgroundColor: colors.white }}>
      <View style={styles.topBar}>
        {back ? (
          <Pressable accessibilityRole="button" accessibilityLabel="Back" onPress={back} hitSlop={8} style={styles.iconBtn}>
            <Icon.Back color={colors.ink} strokeWidth={2} />
          </Pressable>
        ) : (
          <View style={{ width: 44 }} />
        )}
        <T v="title" numberOfLines={1} style={{ flex: 1, textAlign: 'center' }} accessibilityRole="header">
          {title}
        </T>
        <View style={{ minWidth: 44, alignItems: 'flex-end' }}>{right}</View>
      </View>
      {band && <Band />}
    </View>
  );
}

export function BrandBar({ right }: { right?: ReactNode }) {
  return (
    <View style={{ backgroundColor: colors.white }}>
      <View style={[styles.topBar, { paddingLeft: 20 }]}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, flex: 1 }} accessibilityRole="header" accessibilityLabel="Somali Airlines">
          <Logo size={32} />
          <T style={{ fontFamily: fonts.display, fontSize: 19 }}>Somali Airlines</T>
        </View>
        {right}
      </View>
      <Band />
    </View>
  );
}

export function Section({ children, style }: { children: ReactNode; style?: StyleProp<ViewStyle> }) {
  return <View style={[{ paddingHorizontal: space.lg, gap: space.md }, style]}>{children}</View>;
}

export function Card({ children, style, tone = 'white' }: { children: ReactNode; style?: StyleProp<ViewStyle>; tone?: 'white' | 'mist' | 'sand' | 'navy' }) {
  const bg = { white: colors.white, mist: colors.mist, sand: colors.sand, navy: colors.navy }[tone];
  const border = { white: colors.line, mist: colors.mist, sand: colors.sandLine, navy: colors.navy }[tone];
  return <View style={[{ backgroundColor: bg, borderColor: border, borderWidth: 1, borderRadius: radius.xl, padding: space.lg, gap: space.md }, style]}>{children}</View>;
}

export function Row({ children, style, gap = space.sm }: { children: ReactNode; style?: StyleProp<ViewStyle>; gap?: number }) {
  return <View style={[{ flexDirection: 'row', alignItems: 'center', gap }, style]}>{children}</View>;
}

export function Divider({ style }: { style?: StyleProp<ViewStyle> }) {
  return <View style={[{ height: 1, backgroundColor: colors.lineSoft }, style]} />;
}

// ---------- Controls ----------

type BtnKind = 'primary' | 'secondary' | 'ghost' | 'navy' | 'danger' | 'whatsapp';

export function Button({
  title,
  kind = 'primary',
  loading,
  disabled,
  icon,
  style,
  small,
  ...rest
}: PressableProps & { title: string; kind?: BtnKind; loading?: boolean; icon?: ReactNode; style?: StyleProp<ViewStyle>; small?: boolean }) {
  const palette: Record<BtnKind, { bg: string; fg: string; border: string }> = {
    primary: { bg: colors.blue, fg: colors.white, border: colors.blue },
    secondary: { bg: colors.white, fg: colors.blue, border: colors.blue },
    ghost: { bg: 'transparent', fg: colors.blue, border: 'transparent' },
    navy: { bg: colors.navy, fg: colors.white, border: colors.navy },
    danger: { bg: colors.white, fg: colors.red, border: colors.red },
    whatsapp: { bg: colors.green, fg: colors.white, border: colors.green },
  };
  const p = palette[kind];
  const off = disabled || loading;
  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ disabled: !!off, busy: !!loading }}
      disabled={off}
      {...rest}
      style={({ pressed }) => [
        {
          minHeight: small ? 44 : 56,
          paddingHorizontal: small ? 16 : 24,
          borderRadius: small ? radius.md : radius.lg,
          backgroundColor: p.bg,
          borderColor: p.border,
          borderWidth: 1,
          alignItems: 'center',
          justifyContent: 'center',
          flexDirection: 'row',
          gap: 8,
          opacity: off ? 0.55 : pressed ? 0.85 : 1,
        },
        style,
      ]}>
      {loading ? <ActivityIndicator color={p.fg} /> : icon}
      <Text style={{ color: p.fg, fontFamily: fonts.bodySemi, fontSize: small ? 15 : 17 }}>{title}</Text>
    </Pressable>
  );
}

export function Chip({ label, selected, onPress, style }: { label: string; selected: boolean; onPress: () => void; style?: StyleProp<ViewStyle> }) {
  return (
    <Pressable
      accessibilityRole="radio"
      accessibilityState={{ selected }}
      onPress={onPress}
      style={[
        {
          minHeight: 44,
          paddingHorizontal: 18,
          borderRadius: radius.pill,
          borderWidth: 1,
          borderColor: selected ? colors.navy : colors.lineStrong,
          backgroundColor: selected ? colors.navy : colors.white,
          alignItems: 'center',
          justifyContent: 'center',
        },
        style,
      ]}>
      <Text style={{ fontFamily: fonts.bodySemi, fontSize: 15, color: selected ? colors.white : colors.ink }}>{label}</Text>
    </Pressable>
  );
}

export function Segmented<K extends string>({ options, value, onChange, label }: { options: { key: K; label: string }[]; value: K; onChange: (k: K) => void; label: string }) {
  return (
    <View accessibilityRole="radiogroup" accessibilityLabel={label} style={{ flexDirection: 'row', backgroundColor: colors.mist, borderRadius: radius.md, padding: 4 }}>
      {options.map((o) => {
        const on = o.key === value;
        return (
          <Pressable
            key={o.key}
            accessibilityRole="radio"
            accessibilityState={{ selected: on }}
            onPress={() => onChange(o.key)}
            style={{ flex: 1, minHeight: 40, borderRadius: radius.sm, backgroundColor: on ? colors.navy : 'transparent', alignItems: 'center', justifyContent: 'center' }}>
            <Text style={{ fontFamily: on ? fonts.bodySemi : fonts.body, fontSize: 14, color: on ? colors.white : colors.ink }}>{o.label}</Text>
          </Pressable>
        );
      })}
    </View>
  );
}

/** A bordered box with a small label on top, like the design's search fields. */
export function FieldButton({ label, value, placeholder, onPress, style }: { label: string; value?: string; placeholder?: string; onPress: () => void; style?: StyleProp<ViewStyle> }) {
  return (
    <Pressable accessibilityRole="button" accessibilityLabel={`${label}: ${value || placeholder}`} onPress={onPress} style={[styles.field, style]}>
      <T v="label">{label}</T>
      <Text numberOfLines={1} style={{ fontFamily: fonts.bodySemi, fontSize: 17, color: value ? colors.ink : colors.inkFaint }}>
        {value || placeholder}
      </Text>
    </Pressable>
  );
}

export const Field = forwardRef<TextInput, TextInputProps & { label: string; error?: string | null; hint?: string; containerStyle?: StyleProp<ViewStyle>; inputStyle?: StyleProp<TextStyle> }>(
  function Field({ label, error, hint, containerStyle, inputStyle, ...rest }, ref) {
    return (
      <View style={[{ gap: 6 }, containerStyle]}>
        <T v="bodyStrong" style={{ fontSize: 15 }} nativeID={`${label}-label`}>
          {label}
        </T>
        <TextInput
          ref={ref}
          accessibilityLabel={label}
          placeholderTextColor={colors.inkFaint}
          {...rest}
          style={[
            {
              borderWidth: 1,
              borderColor: error ? colors.red : colors.lineStrong,
              borderRadius: radius.lg,
              paddingHorizontal: 16,
              paddingVertical: 14,
              fontSize: 17,
              fontFamily: fonts.body,
              color: colors.ink,
              backgroundColor: colors.white,
            },
            inputStyle,
          ]}
        />
        {error ? <T v="small" style={{ color: colors.red }}>{error}</T> : hint ? <T v="small">{hint}</T> : null}
      </View>
    );
  },
);

export function Stepper({ label, sub, value, min, max, onChange }: { label: string; sub?: string; value: number; min: number; max: number; onChange: (n: number) => void }) {
  return (
    <Row style={{ justifyContent: 'space-between', paddingVertical: 8 }}>
      <View style={{ flex: 1 }}>
        <T v="bodyStrong">{label}</T>
        {sub ? <T v="small">{sub}</T> : null}
      </View>
      <Row gap={14}>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={`Fewer ${label}`}
          disabled={value <= min}
          onPress={() => onChange(value - 1)}
          style={[styles.round, value <= min && { opacity: 0.35 }]}>
          <Icon.Minus size={18} strokeWidth={2.2} />
        </Pressable>
        <T v="title" style={{ minWidth: 22, textAlign: 'center' }} accessibilityLiveRegion="polite">
          {value}
        </T>
        <Pressable
          accessibilityRole="button"
          accessibilityLabel={`More ${label}`}
          disabled={value >= max}
          onPress={() => onChange(value + 1)}
          style={[styles.round, value >= max && { opacity: 0.35 }]}>
          <Icon.Plus size={18} strokeWidth={2.2} />
        </Pressable>
      </Row>
    </Row>
  );
}

// ---------- Feedback ----------

export function Notice({ children, tone = 'sand', title }: { children: ReactNode; tone?: 'sand' | 'error' | 'success' | 'info'; title?: string }) {
  const t = {
    sand: { bg: colors.sand, border: colors.sandLine, fg: colors.ink },
    error: { bg: colors.redSoft, border: '#F4B5AE', fg: colors.red },
    success: { bg: colors.greenSoft, border: '#A9D8BF', fg: colors.greenInk },
    info: { bg: colors.mist, border: '#9AB9DE', fg: colors.ink },
  }[tone];
  return (
    <View
      accessibilityRole={tone === 'error' ? 'alert' : undefined}
      style={{ backgroundColor: t.bg, borderColor: t.border, borderWidth: 1, borderRadius: radius.xl, padding: space.lg, gap: 6 }}>
      {title ? <T v="bodyStrong" style={{ color: t.fg }}>{title}</T> : null}
      {typeof children === 'string' ? <T style={{ color: t.fg, fontSize: 15, lineHeight: 22 }}>{children}</T> : children}
    </View>
  );
}

export function Loading({ label = 'Loading' }: { label?: string }) {
  return (
    <View style={{ padding: 48, alignItems: 'center', gap: 12 }} accessibilityLabel={label}>
      <ActivityIndicator color={colors.blue} size="large" />
      <T v="small">{label}</T>
    </View>
  );
}

export function Empty({ title, body, action }: { title: string; body?: string; action?: ReactNode }) {
  return (
    <View style={{ padding: 32, alignItems: 'center', gap: 10 }}>
      <T v="h3" style={{ textAlign: 'center' }}>{title}</T>
      {body ? <T v="small" style={{ textAlign: 'center', fontSize: 15 }}>{body}</T> : null}
      {action}
    </View>
  );
}

export function StickyFooter({ children }: { children: ReactNode }) {
  return <View style={styles.footer}>{children}</View>;
}

export function ListLink({ icon, title, sub, onPress }: { icon?: ReactNode; title: string; sub?: string; onPress: () => void }) {
  return (
    <Pressable accessibilityRole="button" onPress={onPress} style={({ pressed }) => [styles.listLink, pressed && { backgroundColor: colors.mist }]}>
      {icon}
      <View style={{ flex: 1 }}>
        <T v="bodyStrong">{title}</T>
        {sub ? <T v="small">{sub}</T> : null}
      </View>
      <Icon.Chevron size={18} color={colors.inkSoft} />
    </Pressable>
  );
}

export const styles = StyleSheet.create({
  topBar: { height: 60, flexDirection: 'row', alignItems: 'center', paddingHorizontal: 8, gap: 4 },
  iconBtn: { width: 44, height: 44, alignItems: 'center', justifyContent: 'center', borderRadius: radius.md },
  field: {
    borderWidth: 1,
    borderColor: colors.line,
    borderRadius: radius.lg,
    paddingHorizontal: 16,
    paddingVertical: 12,
    gap: 2,
    backgroundColor: colors.white,
  },
  round: {
    width: 44,
    height: 44,
    borderRadius: radius.pill,
    borderWidth: 1,
    borderColor: colors.line,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: colors.white,
  },
  footer: {
    borderTopWidth: 1,
    borderTopColor: colors.lineSoft,
    backgroundColor: colors.white,
    paddingHorizontal: space.lg,
    paddingTop: space.md,
    paddingBottom: space.md,
    gap: space.sm,
  },
  listLink: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 14,
    minHeight: 64,
    paddingHorizontal: space.lg,
    paddingVertical: 10,
  },
});
