import { useState } from 'react';
import { ScrollView, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { AIRPORTS } from '@core/airports';
import { destinationsFrom } from '@core/schedule';
import { STATUS_LABEL } from '@core/status';
import { addDays, todayAt } from '@core/time';
import type { FlightWithStatus } from '@core/types';

import { FlightTimes } from '@/components/booking';
import { Sheet } from '@/components/sheet';
import { BrandBar, Button, Card, Chip, Empty, Field, FieldButton, Loading, Notice, Row, Segmented, T } from '@/components/ui';
import { api } from '@/lib/api';
import { cityCode, shortDate } from '@/lib/format';
import { colors, fonts, radius } from '@/lib/theme';
import { useAsync } from '@/lib/use-async';

const TONE: Record<FlightWithStatus['status'], { bg: string; fg: string }> = {
  scheduled: { bg: colors.mist, fg: colors.ink },
  on_time: { bg: colors.greenSoft, fg: colors.greenInk },
  boarding: { bg: colors.greenSoft, fg: colors.greenInk },
  departed: { bg: colors.mist, fg: colors.blue },
  landed: { bg: colors.mist, fg: colors.blue },
  delayed: { bg: colors.sand, fg: '#7A4B00' },
  cancelled: { bg: colors.redSoft, fg: colors.red },
};

export default function Status() {
  const today = todayAt(3);
  const [mode, setMode] = useState<'route' | 'number'>('route');
  const [origin, setOrigin] = useState('MGQ');
  const [destination, setDestination] = useState('HGA');
  const [number, setNumber] = useState('');
  const [date, setDate] = useState(today);
  const [picker, setPicker] = useState<'origin' | 'destination' | null>(null);
  const [query, setQuery] = useState<{ origin?: string; destination?: string; flightNumber?: string; date: string }>({ origin: 'MGQ', destination: 'HGA', date: today });

  const result = useAsync(() => api.flightStatus(query), [JSON.stringify(query)]);

  const search = () =>
    setQuery(mode === 'number' ? { flightNumber: number, date } : { origin, destination, date });

  const pickList = picker === 'destination' ? AIRPORTS.filter((a) => destinationsFrom(origin).includes(a.code)) : AIRPORTS.filter((a) => destinationsFrom(a.code).length > 0);

  return (
    <SafeAreaView edges={['top']} style={{ flex: 1, backgroundColor: colors.page }}>
      <BrandBar />
      <ScrollView contentContainerStyle={{ padding: 16, gap: 14, paddingBottom: 40 }} keyboardShouldPersistTaps="handled">
        <T v="h1">Flight status</T>
        <Card style={{ gap: 12 }}>
          <Segmented label="Search by" value={mode} onChange={setMode} options={[{ key: 'route', label: 'Route' }, { key: 'number', label: 'Flight number' }]} />
          {mode === 'route' ? (
            <>
              <FieldButton label="From" value={cityCode(origin)} onPress={() => setPicker('origin')} />
              <FieldButton label="To" value={cityCode(destination)} onPress={() => setPicker('destination')} />
            </>
          ) : (
            <Field label="Flight number" value={number} onChangeText={setNumber} placeholder="HH 101" autoCapitalize="characters" />
          )}
          <Row style={{ flexWrap: 'wrap' }}>
            {[-1, 0, 1].map((d) => {
              const v = addDays(today, d);
              return <Chip key={d} label={d === 0 ? 'Today' : d === 1 ? 'Tomorrow' : 'Yesterday'} selected={date === v} onPress={() => setDate(v)} />;
            })}
          </Row>
          <Button title="Check status" onPress={search} />
        </Card>

        {result.loading ? <Loading label="Checking flights" /> : null}
        {result.error ? <Notice tone="error">{result.error}</Notice> : null}
        {result.data && result.data.length === 0 ? <Empty title="No flights found" body="Check the flight number and date." /> : null}
        {result.data?.map((f) => {
          const tone = TONE[f.status];
          return (
            <Card key={f.id} style={{ gap: 12 }}>
              <Row style={{ justifyContent: 'space-between' }}>
                <T v="title">{`${f.flightNumber}, ${shortDate(f.date)}`}</T>
                <View style={{ backgroundColor: tone.bg, paddingHorizontal: 12, paddingVertical: 5, borderRadius: radius.pill }}>
                  <T v="caption" style={{ color: tone.fg, fontFamily: fonts.bodySemi, fontSize: 13 }}>{STATUS_LABEL[f.status]}</T>
                </View>
              </Row>
              <FlightTimes flight={f} compact />
              <Row style={{ justifyContent: 'space-between' }}>
                <T v="small">{f.delayMin ? `New departure ${f.estDepartTime}, arrival ${f.estArriveTime}` : 'Times are local'}</T>
                <T v="small">{`Gate ${f.gate ?? 'TBA'}`}</T>
              </Row>
              {f.note ? <T v="small" style={{ color: colors.ink }}>{f.note}</T> : null}
            </Card>
          );
        })}
      </ScrollView>

      <Sheet visible={picker !== null} title={picker === 'origin' ? 'From' : 'To'} onClose={() => setPicker(null)}>
        {pickList.map((a) => (
          <Chip
            key={a.code}
            label={`${a.city} (${a.code})`}
            selected={(picker === 'origin' ? origin : destination) === a.code}
            onPress={() => {
              if (picker === 'origin') {
                setOrigin(a.code);
                if (!destinationsFrom(a.code).includes(destination)) setDestination(destinationsFrom(a.code)[0]);
              } else setDestination(a.code);
              setPicker(null);
            }}
            style={{ alignSelf: 'flex-start' }}
          />
        ))}
      </Sheet>
    </SafeAreaView>
  );
}
