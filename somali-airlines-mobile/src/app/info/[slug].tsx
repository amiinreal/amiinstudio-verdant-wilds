import { useLocalSearchParams } from 'expo-router';
import { View } from 'react-native';

import { Card, Divider, Empty, Notice, Row, Screen, T, TopBar } from '@/components/ui';
import { article } from '@/lib/info-content';
import { colors } from '@/lib/theme';

export default function InfoPage() {
  const { slug } = useLocalSearchParams<{ slug: string }>();
  const a = article(slug);

  if (!a) {
    return (
      <Screen>
        <TopBar title="Travel information" />
        <Empty title="Page not found" />
      </Screen>
    );
  }

  return (
    <Screen background={colors.page}>
      <TopBar title={a.title} />
      <View style={{ padding: 20, gap: 14 }}>
        <T v="h1">{a.title}</T>
        {a.blocks.map((b, i) => {
          switch (b.kind) {
            case 'h':
              return <T key={i} v="h3" style={{ marginTop: 10 }} accessibilityRole="header">{b.text}</T>;
            case 'p':
              return <T key={i}>{b.text}</T>;
            case 'note':
              return <Notice key={i}>{b.text}</Notice>;
            case 'list':
              return (
                <View key={i} style={{ gap: 8 }}>
                  {b.items.map((it) => (
                    <Row key={it} gap={10} style={{ alignItems: 'flex-start' }}>
                      <View style={{ width: 6, height: 6, borderRadius: 3, backgroundColor: colors.blue, marginTop: 9 }} />
                      <T style={{ flex: 1 }}>{it}</T>
                    </Row>
                  ))}
                </View>
              );
            case 'table':
              return (
                <Card key={i} style={{ padding: 0, gap: 0 }}>
                  {b.rows.map(([k, v], j) => (
                    <View key={k}>
                      {j > 0 ? <Divider /> : null}
                      <Row style={{ padding: 14, alignItems: 'flex-start', gap: 12 }}>
                        <T v="bodyStrong" style={{ flex: 1, fontSize: 15 }}>{k}</T>
                        <T style={{ flex: 1.3, fontSize: 15 }}>{v}</T>
                      </Row>
                    </View>
                  ))}
                </Card>
              );
          }
        })}
      </View>
    </Screen>
  );
}
