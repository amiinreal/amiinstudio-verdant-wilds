import { router, useLocalSearchParams } from 'expo-router';
import { useMemo, useState } from 'react';
import { FlatList, Pressable, TextInput, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { AIRPORTS } from '@core/airports';
import { allOrigins, destinationsFrom } from '@core/schedule';

import { Icon } from '@/components/icons';
import { T, TopBar } from '@/components/ui';
import { useDraft } from '@/lib/draft';
import { colors, fonts, radius } from '@/lib/theme';

export default function AirportPicker() {
  const { field } = useLocalSearchParams<{ field: 'origin' | 'destination' }>();
  const { draft, setQuery } = useDraft();
  const [text, setText] = useState('');

  const list = useMemo(() => {
    const allowed = field === 'destination' ? destinationsFrom(draft.query.origin) : allOrigins();
    const t = text.trim().toLowerCase();
    return AIRPORTS.filter((a) => allowed.includes(a.code)).filter(
      (a) => !t || a.city.toLowerCase().includes(t) || a.code.toLowerCase().includes(t) || a.name.toLowerCase().includes(t) || a.country.toLowerCase().includes(t),
    );
  }, [field, draft.query.origin, text]);

  const choose = (code: string) => {
    if (field === 'origin') {
      const dest = destinationsFrom(code);
      setQuery({ origin: code, destination: dest.includes(draft.query.destination) ? draft.query.destination : dest[0] });
    } else {
      setQuery({ destination: code });
    }
    router.back();
  };

  return (
    <SafeAreaView edges={['top', 'bottom']} style={{ flex: 1, backgroundColor: colors.white }}>
      <TopBar title={field === 'origin' ? 'Flying from' : 'Flying to'} band={false} />
      <View style={{ paddingHorizontal: 16, paddingBottom: 8 }}>
        <View style={{ flexDirection: 'row', alignItems: 'center', gap: 10, borderWidth: 1, borderColor: colors.lineStrong, borderRadius: radius.lg, paddingHorizontal: 14 }}>
          <Icon.Search color={colors.inkSoft} />
          <TextInput
            autoFocus
            value={text}
            onChangeText={setText}
            placeholder="City or airport"
            placeholderTextColor={colors.inkFaint}
            accessibilityLabel="City or airport"
            style={{ flex: 1, paddingVertical: 14, fontSize: 17, fontFamily: fonts.body, color: colors.ink }}
          />
        </View>
      </View>
      <FlatList
        data={list}
        keyExtractor={(a) => a.code}
        keyboardShouldPersistTaps="handled"
        ListEmptyComponent={<T style={{ padding: 20, color: colors.inkSoft }}>We don’t fly there yet.</T>}
        renderItem={({ item: a }) => (
          <Pressable
            accessibilityRole="button"
            onPress={() => choose(a.code)}
            style={({ pressed }) => ({ flexDirection: 'row', alignItems: 'center', gap: 14, paddingHorizontal: 20, paddingVertical: 14, backgroundColor: pressed ? colors.mist : colors.white })}>
            <View style={{ width: 52, height: 40, borderRadius: radius.md, backgroundColor: colors.mist, alignItems: 'center', justifyContent: 'center' }}>
              <T style={{ fontFamily: fonts.bodySemi, color: colors.blue }}>{a.code}</T>
            </View>
            <View style={{ flex: 1 }}>
              <T v="bodyStrong">{a.city}</T>
              <T v="small">{`${a.name}, ${a.country}`}</T>
            </View>
          </Pressable>
        )}
      />
    </SafeAreaView>
  );
}
