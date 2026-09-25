import { router } from 'expo-router';
import { ScrollView, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Icon } from '@/components/icons';
import { BrandBar, Card, Divider, ListLink, T } from '@/components/ui';
import { ARTICLES, type Article } from '@/lib/info-content';
import { colors } from '@/lib/theme';

const ICONS: Record<string, (p: { color?: string }) => React.ReactElement> = {
  baggage: Icon.Bag,
  documents: Icon.Doc,
  checkin: Icon.Ticket,
  seats: Icon.Seat,
  children: Icon.Child,
  assistance: Icon.Heart,
  payments: Icon.Wallet,
  changes: Icon.Calendar,
  destinations: Icon.Map,
  story: Icon.Star,
  contact: Icon.Chat,
  conditions: Icon.Doc,
  privacy: Icon.Shield,
  accessibility: Icon.Info,
};

const GROUPS: Article['group'][] = ['Before you fly', 'At the airport', 'About us', 'Legal'];

export default function Info() {
  return (
    <SafeAreaView edges={['top']} style={{ flex: 1, backgroundColor: colors.page }}>
      <BrandBar />
      <ScrollView contentContainerStyle={{ padding: 16, gap: 16, paddingBottom: 40 }}>
        <T v="h1">Travel information</T>
        {GROUPS.map((g) => {
          const list = ARTICLES.filter((a) => a.group === g);
          return (
            <View key={g} style={{ gap: 8 }}>
              <T v="title">{g}</T>
              <Card style={{ padding: 0, gap: 0, overflow: 'hidden' }}>
                {list.map((a, i) => {
                  const I = ICONS[a.slug] ?? Icon.Info;
                  return (
                    <View key={a.slug}>
                      {i > 0 ? <Divider /> : null}
                      <ListLink icon={<I />} title={a.title} sub={a.summary} onPress={() => router.push({ pathname: '/info/[slug]', params: { slug: a.slug } })} />
                    </View>
                  );
                })}
              </Card>
            </View>
          );
        })}
        <T v="small">Concept app. Not an official Somali Airlines service.</T>
      </ScrollView>
    </SafeAreaView>
  );
}
