import * as Clipboard from 'expo-clipboard';
import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { Alert, Platform, Pressable, View } from 'react-native';

import { FARE_RULES } from '@core/pricing';
import { balanceDue } from '@core/service';
import { checkinWindow } from '@core/status';
import type { Booking } from '@core/types';

import { FlightTimes, PriceSummary } from '@/components/booking';
import { Icon } from '@/components/icons';
import { Button, Card, Divider, ListLink, Loading, Notice, Row, Screen, T, TopBar } from '@/components/ui';
import { api, errorMessage } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { countdown, dateTime, formatUsd, longDate } from '@/lib/format';
import { colors, fonts, radius } from '@/lib/theme';
import { useTrips } from '@/lib/trips';
import { useNow } from '@/lib/use-async';
import { useBooking } from '@/lib/use-booking';

const STATUS: Record<Booking['status'], { label: string; bg: string; fg: string }> = {
  confirmed: { label: 'Confirmed', bg: colors.greenSoft, fg: colors.greenInk },
  pending_payment: { label: 'Waiting for payment', bg: colors.sand, fg: colors.ink },
  held: { label: 'Fare on hold', bg: colors.sand, fg: colors.ink },
  cancelled: { label: 'Cancelled', bg: colors.redSoft, fg: colors.red },
};

function confirm(title: string, message: string, ok: string): Promise<boolean> {
  if (Platform.OS === 'web') return Promise.resolve(window.confirm(`${title}\n\n${message}`));
  return new Promise((resolve) =>
    Alert.alert(title, message, [
      { text: 'Keep booking', style: 'cancel', onPress: () => resolve(false) },
      { text: ok, style: 'destructive', onPress: () => resolve(true) },
    ]),
  );
}

export default function ManageBooking() {
  const { paid } = useLocalSearchParams<{ paid?: string }>();
  const { pnr, ref, data: b, error, loading, reload, setData } = useBooking();
  const { user } = useAuth();
  const { forget } = useTrips();
  const [busy, setBusy] = useState<string | null>(null);
  const [actionError, setActionError] = useState<string | null>(null);
  const [notice, setNotice] = useState<string | null>(null);
  const now = useNow();

  if (loading && !b) return <Screen><TopBar title={`Booking ${pnr}`} /><Loading /></Screen>;
  if (!b) {
    return (
      <Screen>
        <TopBar title={`Booking ${pnr}`} />
        <View style={{ padding: 16, gap: 12 }}>
          <Notice tone="error">{error ?? 'We could not open this booking.'}</Notice>
          <Button kind="secondary" title="Find a booking" onPress={() => router.replace('/booking/find')} />
        </View>
      </Screen>
    );
  }

  const due = balanceDue(b);
  const live = b.status !== 'cancelled';
  const status = STATUS[b.status];
  const expiresIn = b.holdExpiresAt ? Date.parse(b.holdExpiresAt) - now : 0;

  const cancel = async () => {
    setActionError(null);
    try {
      const q = await api.refundQuote(ref);
      const ok = await confirm(
        'Cancel this booking?',
        `${q.explanation} ${q.refund > 0 ? `You get ${formatUsd(q.refund)} back to the way you paid.` : ''}`.trim(),
        'Cancel booking',
      );
      if (!ok) return;
      setBusy('cancel');
      const res = await api.cancelBooking(ref);
      setData(res.booking);
      setNotice(res.refund > 0 ? `Cancelled. ${formatUsd(res.refund)} is on its way back to you.` : 'Your booking is cancelled.');
    } catch (e) {
      setActionError(errorMessage(e));
    } finally {
      setBusy(null);
    }
  };

  const claim = async () => {
    setBusy('claim');
    setActionError(null);
    try {
      setData(await api.claimBooking(ref));
      setNotice('Saved to your account.');
    } catch (e) {
      setActionError(errorMessage(e));
    } finally {
      setBusy(null);
    }
  };

  return (
    <Screen background={colors.page}>
      <TopBar title="Your booking" onBack={() => (router.canGoBack() ? router.back() : router.replace('/trips'))} />
      <View style={{ padding: 16, gap: 16 }}>
        {paid ? (
          <Notice tone="success" title={b.status === 'confirmed' ? "You're booked" : 'Payment received'}>
            {`Tickets are on their way to ${b.contact.email}. Check-in opens 24 hours before departure.`}
          </Notice>
        ) : null}
        {notice ? <Notice tone="success">{notice}</Notice> : null}

        <Card style={{ gap: 10 }}>
          <Row style={{ justifyContent: 'space-between' }}>
            <T v="label">Booking reference</T>
            <View style={{ backgroundColor: status.bg, paddingHorizontal: 10, paddingVertical: 4, borderRadius: radius.pill }}>
              <T v="caption" style={{ color: status.fg, fontFamily: fonts.bodySemi }}>{status.label}</T>
            </View>
          </Row>
          <Pressable
            accessibilityRole="button"
            accessibilityLabel={`Booking reference ${b.pnr}. Copy`}
            onPress={() => {
              void Clipboard.setStringAsync(b.pnr);
              setNotice('Booking reference copied.');
            }}
            style={{ flexDirection: 'row', alignItems: 'center', gap: 10 }}>
            <T style={{ fontFamily: fonts.display, fontSize: 36, letterSpacing: 3 }}>{b.pnr}</T>
            <Icon.Copy size={20} color={colors.inkSoft} />
          </Pressable>
          <T v="small">{`Booked ${dateTime(b.createdAt)}`}</T>
        </Card>

        {live && (b.status === 'pending_payment' || b.status === 'held') ? (
          <Notice tone="sand" title={b.status === 'held' ? 'Your fare is on hold' : 'Finish paying to get your tickets'}>
            <T style={{ fontSize: 15 }}>{expiresIn > 0 ? `Pay ${formatUsd(due)} within ${countdown(expiresIn)}, or the seats are released.` : 'The time to pay has run out.'}</T>
            <Button title={`Pay ${formatUsd(due)}`} onPress={() => router.push({ pathname: '/pay/[pnr]', params: { pnr: b.pnr } })} style={{ marginTop: 8 }} />
          </Notice>
        ) : null}
        {live && b.status === 'confirmed' && due > 0 ? (
          <Notice tone="sand" title="Balance to pay">
            <T style={{ fontSize: 15 }}>{`Pay ${formatUsd(due)} for your changes before check-in.`}</T>
            <Button title={`Pay ${formatUsd(due)}`} onPress={() => router.push({ pathname: '/pay/[pnr]', params: { pnr: b.pnr } })} style={{ marginTop: 8 }} />
          </Notice>
        ) : null}

        {b.segments.map((s, i) => {
          const win = checkinWindow(s.flight, now);
          const checked = b.passengers.filter((p) => p.checkedIn[i]).length;
          const seated = b.passengers.filter((p) => p.type !== 'infant');
          return (
            <Card key={s.flight.id} style={{ gap: 14, padding: 20, borderRadius: 20 }}>
              <Row style={{ justifyContent: 'space-between' }}>
                <T v="label">{i === 0 ? 'Outbound' : 'Return'}</T>
                <T v="label">{`${s.flight.flightNumber}, ${FARE_RULES[s.fare].name}`}</T>
              </Row>
              <T v="title">{longDate(s.flight.date)}</T>
              <FlightTimes flight={s.flight} compact />
              <T v="small">{`Seats: ${seated.map((p) => `${p.firstName} ${p.seats[i] ?? 'not chosen'}`).join(', ')}`}</T>
              {live && b.status === 'confirmed' ? (
                checked > 0 ? (
                  <Button title="Boarding passes" icon={<Icon.Ticket color={colors.white} />} onPress={() => router.push({ pathname: '/booking/[pnr]/boarding-pass', params: { pnr: b.pnr, segment: String(i) } })} />
                ) : win.state === 'open' ? (
                  <Button title="Check in" onPress={() => router.push({ pathname: '/booking/[pnr]/checkin', params: { pnr: b.pnr, segment: String(i) } })} />
                ) : win.state === 'not_open' ? (
                  <T v="small" style={{ color: colors.inkSoft }}>{`Online check-in opens ${dateTime(new Date(win.opensAt).toISOString())}.`}</T>
                ) : null
              ) : null}
              {checked > 0 && checked < b.passengers.length && win.state === 'open' ? (
                <Button kind="secondary" small title="Check in the others" onPress={() => router.push({ pathname: '/booking/[pnr]/checkin', params: { pnr: b.pnr, segment: String(i) } })} />
              ) : null}
            </Card>
          );
        })}

        {live ? (
          <Card style={{ padding: 0, gap: 0, overflow: 'hidden' }}>
            <T v="title" style={{ padding: 16, paddingBottom: 4 }}>Manage</T>
            <ListLink icon={<Icon.Seat />} title="Seats" sub="Choose or change seats" onPress={() => router.push({ pathname: '/booking/[pnr]/seats', params: { pnr: b.pnr } })} />
            <Divider />
            <ListLink icon={<Icon.Bag />} title="Bags" sub="Add checked bags" onPress={() => router.push({ pathname: '/booking/[pnr]/bags', params: { pnr: b.pnr } })} />
            <Divider />
            <ListLink icon={<Icon.Calendar />} title="Change flight" sub="Move to another date or time" onPress={() => router.push({ pathname: '/booking/[pnr]/change', params: { pnr: b.pnr } })} />
            <Divider />
            <ListLink icon={<Icon.Doc />} title="Passport and assistance" sub="Travel documents, wheelchair, medical needs" onPress={() => router.push({ pathname: '/booking/[pnr]/details', params: { pnr: b.pnr } })} />
          </Card>
        ) : null}

        <Card>
          <T v="title">Passengers</T>
          {b.passengers.map((p) => (
            <View key={p.id} style={{ gap: 2, paddingVertical: 6 }}>
              <T v="bodyStrong">{`${p.title ? p.title + ' ' : ''}${p.firstName} ${p.lastName}`}</T>
              <T v="small">
                {[
                  p.type === 'adult' ? 'Adult' : p.type === 'child' ? 'Child' : 'Infant',
                  p.extraBags ? `${p.extraBags} extra bag${p.extraBags > 1 ? 's' : ''}` : null,
                  p.ticketNumber ? `Ticket ${p.ticketNumber}` : null,
                ]
                  .filter(Boolean)
                  .join(', ')}
              </T>
            </View>
          ))}
        </Card>

        <Card>
          <PriceSummary price={b.price} paid={b.paid} />
          {b.refunded > 0 ? <T v="small">{`Refunded ${formatUsd(b.refunded)}`}</T> : null}
        </Card>

        <Card style={{ gap: 8 }}>
          <T v="title">History</T>
          {[...b.history].reverse().map((h, i) => (
            <View key={i}>
              <T style={{ fontSize: 15 }}>{h.text}</T>
              <T v="caption">{dateTime(h.at)}</T>
            </View>
          ))}
        </Card>

        {actionError ? <Notice tone="error">{actionError}</Notice> : null}

        {user && b.userId !== user.id ? <Button kind="secondary" title="Save to my account" loading={busy === 'claim'} onPress={claim} /> : null}
        {live ? <Button kind="danger" title="Cancel booking" loading={busy === 'cancel'} onPress={cancel} /> : null}
        <Button
          kind="ghost"
          title="Remove from this phone"
          onPress={() => {
            forget(b.pnr);
            router.replace('/trips');
          }}
        />
        <Button kind="ghost" title="Refresh" onPress={reload} />
        <T v="small" style={{ textAlign: 'center' }}>{`Need help? Quote ${b.pnr} when you contact us.`}</T>
      </View>
    </Screen>
  );
}
