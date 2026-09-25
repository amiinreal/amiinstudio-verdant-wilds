import { router, useFocusEffect } from 'expo-router';
import { useCallback, useState } from 'react';
import { Pressable, RefreshControl, ScrollView, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { departureInstant } from '@core/status';
import type { Booking } from '@core/types';

import { Icon } from '@/components/icons';
import { BrandBar, Button, Card, Empty, Loading, Notice, Row, T } from '@/components/ui';
import { api, errorMessage } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { useNow } from '@/lib/use-async';
import { cityName, shortDate } from '@/lib/format';
import { colors, fonts, radius } from '@/lib/theme';
import { useTrips } from '@/lib/trips';

const STATUS_TEXT: Record<Booking['status'], string> = {
  confirmed: 'Confirmed',
  pending_payment: 'Waiting for payment',
  held: 'Fare on hold',
  cancelled: 'Cancelled',
};

function TripCard({ b }: { b: Booking }) {
  const first = b.segments[0].flight;
  const last = b.segments[b.segments.length - 1].flight;
  const cancelled = b.status === 'cancelled';
  return (
    <Pressable
      accessibilityRole="button"
      onPress={() => router.push({ pathname: '/booking/[pnr]', params: { pnr: b.pnr } })}
      style={({ pressed }) => ({ opacity: pressed ? 0.85 : 1 })}>
      <Card style={{ gap: 8, padding: 18, opacity: cancelled ? 0.7 : 1 }}>
        <Row style={{ justifyContent: 'space-between' }}>
          <T v="label">{b.pnr}</T>
          <T v="caption" style={{ fontFamily: fonts.bodySemi, color: cancelled ? colors.red : b.status === 'confirmed' ? colors.greenInk : colors.clay }}>
            {STATUS_TEXT[b.status]}
          </T>
        </Row>
        <T v="h3">{`${cityName(first.origin)} to ${cityName(first.destination)}`}</T>
        <T v="small">
          {b.segments.length > 1 ? `${shortDate(first.date)} to ${shortDate(last.date)}, return` : `${shortDate(first.date)}, ${first.departTime}, ${first.flightNumber}`}
        </T>
        <T v="small">{b.passengers.map((p) => p.firstName).join(', ')}</T>
      </Card>
    </Pressable>
  );
}

export default function Trips() {
  const { user } = useAuth();
  const { refs, ready } = useTrips();
  const [bookings, setBookings] = useState<Booking[] | null>(null);
  const [errors, setErrors] = useState<string | null>(null);
  const [refreshing, setRefreshing] = useState(false);

  const load = useCallback(async () => {
    setErrors(null);
    const byPnr = new Map<string, Booking>();
    try {
      if (user) for (const b of await api.myBookings()) byPnr.set(b.pnr, b);
    } catch (e) {
      setErrors(errorMessage(e));
    }
    await Promise.all(
      refs
        .filter((r) => !byPnr.has(r.pnr))
        .map(async (r) => {
          try {
            byPnr.set(r.pnr, await api.getBooking(r));
          } catch {
            // A booking that can no longer be opened just drops off the list.
          }
        }),
    );
    setBookings([...byPnr.values()]);
  }, [user, refs]);

  useFocusEffect(
    useCallback(() => {
      if (ready) void load();
    }, [ready, load]),
  );

  const now = useNow();
  const upcoming = (bookings ?? [])
    .filter((b) => b.status !== 'cancelled' && b.segments.some((s) => departureInstant(s.flight) > now - 6 * 3600_000))
    .sort((a, b) => departureInstant(a.segments[0].flight) - departureInstant(b.segments[0].flight));
  const past = (bookings ?? []).filter((b) => !upcoming.includes(b));

  return (
    <SafeAreaView edges={['top']} style={{ flex: 1, backgroundColor: colors.page }}>
      <BrandBar />
      <ScrollView
        contentContainerStyle={{ padding: 16, gap: 14, paddingBottom: 40 }}
        refreshControl={
          <RefreshControl
            refreshing={refreshing}
            onRefresh={async () => {
              setRefreshing(true);
              await load();
              setRefreshing(false);
            }}
          />
        }>
        <T v="h1">My trips</T>
        <Pressable
          accessibilityRole="button"
          onPress={() => router.push('/booking/find')}
          style={{ flexDirection: 'row', alignItems: 'center', gap: 14, padding: 18, borderRadius: radius.xl, backgroundColor: colors.mist }}>
          <Icon.Search />
          <View style={{ flex: 1 }}>
            <T v="bodyStrong">Find a booking</T>
            <T v="small">Use the reference and a last name, to manage it or check in</T>
          </View>
          <Icon.Chevron color={colors.inkSoft} size={18} />
        </Pressable>

        {!user ? (
          <Notice tone="info" title="Keep your trips in one place">
            <T style={{ fontSize: 15 }}>Log in to see bookings made on any phone, and fill in passenger details faster.</T>
            <Button small kind="secondary" title="Log in or create an account" onPress={() => router.push('/auth/login')} style={{ marginTop: 8, alignSelf: 'flex-start' }} />
          </Notice>
        ) : null}

        {errors ? <Notice tone="error">{errors}</Notice> : null}
        {bookings === null ? <Loading label="Loading your trips" /> : null}
        {bookings && upcoming.length === 0 ? (
          <Empty title="No upcoming trips" body="Book a flight, or find a booking you made elsewhere." action={<Button small title="Book a flight" onPress={() => router.navigate('/')} />} />
        ) : null}
        {upcoming.map((b) => (
          <TripCard key={b.pnr} b={b} />
        ))}
        {past.length > 0 ? <T v="title" style={{ marginTop: 16 }}>Past and cancelled</T> : null}
        {past.map((b) => (
          <TripCard key={b.pnr} b={b} />
        ))}
      </ScrollView>
    </SafeAreaView>
  );
}
