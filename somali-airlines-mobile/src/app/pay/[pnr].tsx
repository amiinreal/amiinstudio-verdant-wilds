import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { ActivityIndicator, Pressable, TextInput, View } from 'react-native';

import { balanceDue } from '@core/service';
import type { Booking } from '@core/types';

import { PriceSummary, Steps } from '@/components/booking';
import { Icon } from '@/components/icons';
import { Button, Card, Chip, Loading, Notice, Row, Screen, T, TopBar } from '@/components/ui';
import { api, errorMessage, type MobileWallet } from '@/lib/api';
import { cityName, countdown, formatUsd, shortDate } from '@/lib/format';
import { useCardPayment } from '@/lib/payments';
import { colors, fonts, radius } from '@/lib/theme';
import { useTrips } from '@/lib/trips';
import { useAsync, useNow } from '@/lib/use-async';

type Method = 'mobile' | 'card' | 'hold';

const WALLETS: { id: MobileWallet; label: string }[] = [
  { id: 'evc', label: 'EVC Plus' },
  { id: 'zaad', label: 'ZAAD' },
  { id: 'sahal', label: 'SAHAL' },
  { id: 'waafi', label: 'WAAFI' },
];

async function waitForConfirmation(ref: { pnr: string; lastName: string }): Promise<Booking | null> {
  // The webhook confirms the booking a moment after Stripe takes the money.
  for (let i = 0; i < 20; i++) {
    const b = await api.getBooking(ref);
    if (balanceDue(b) === 0 && b.status === 'confirmed') return b;
    await new Promise((r) => setTimeout(r, 1500));
  }
  return null;
}

export default function Pay() {
  const { pnr } = useLocalSearchParams<{ pnr: string }>();
  const { refFor } = useTrips();
  const ref = refFor(pnr);
  const booking = useAsync(() => api.getBooking(ref), [pnr]);
  const payCard = useCardPayment();
  const [method, setMethod] = useState<Method>('mobile');
  const [wallet, setWallet] = useState<MobileWallet>('evc');
  const [msisdn, setMsisdn] = useState('');
  const [busy, setBusy] = useState(false);
  const [waiting, setWaiting] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);
  const now = useNow(1000);

  const b = booking.data;
  const due = b ? balanceDue(b) : 0;
  const walletName = WALLETS.find((w) => w.id === wallet)!.label;
  const done = () => router.replace({ pathname: '/booking/[pnr]', params: { pnr, paid: '1' } });

  const card = async () => {
    if (!b) return;
    setBusy(true);
    setError(null);
    try {
      const start = await api.startCardPayment(ref);
      if (start.kind === 'demo') {
        await api.completeDemoPayment(ref, 'card');
        return done();
      }
      const result = await payCard(start, b.contact.email);
      if (result === 'canceled' || result === 'redirected') return;
      setWaiting('Confirming your payment');
      const confirmed = await waitForConfirmation(ref);
      if (confirmed) return done();
      setError('Your payment went through but we are still issuing tickets. Check My trips in a minute.');
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
      setWaiting(null);
    }
  };

  const mobile = async () => {
    setError(null);
    if (msisdn.replace(/\D/g, '').length < 7) return setError('Enter the mobile number that will pay.');
    setBusy(true);
    try {
      await api.startMobileMoney(ref, wallet, `+252${msisdn.replace(/\D/g, '')}`);
      setWaiting(`Waiting for approval on the phone ending ${msisdn.replace(/\D/g, '').slice(-2)}`);
      if (api.mode === 'demo') {
        // Simulates the phone owner entering their PIN.
        await new Promise((r) => setTimeout(r, 3000));
        await api.completeDemoPayment(ref, 'mobile_money');
        return done();
      }
      const confirmed = await waitForConfirmation(ref);
      if (confirmed) return done();
      setError('The request expired. Send it again.');
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
      setWaiting(null);
    }
  };

  const hold = async () => {
    setBusy(true);
    setError(null);
    try {
      await api.holdFare(ref);
      router.replace({ pathname: '/booking/[pnr]', params: { pnr } });
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  if (booking.loading && !b) return <Screen><TopBar title="Payment" /><Loading /></Screen>;
  if (booking.error || !b) {
    return (
      <Screen>
        <TopBar title="Payment" />
        <View style={{ padding: 16 }}><Notice tone="error">{booking.error ?? 'Booking not found.'}</Notice></View>
      </Screen>
    );
  }

  const expiresIn = b.holdExpiresAt ? Date.parse(b.holdExpiresAt) - now : null;
  const first = b.segments[0].flight;
  const last = b.segments[b.segments.length - 1].flight;

  return (
    <Screen background={colors.page}>
      <TopBar title="Payment" onBack={() => router.replace({ pathname: '/booking/[pnr]', params: { pnr } })} />
      {b.status === 'pending_payment' ? <Steps current={5} /> : null}
      <View style={{ padding: 16, gap: 16 }}>
        <View style={{ gap: 6 }}>
          <T v="h1">Pay for your trip</T>
          {b.status === 'cancelled' ? null : expiresIn != null && expiresIn > 0 ? (
            <T style={{ color: colors.inkSoft }}>{`We hold your seats for ${countdown(expiresIn)}.`}</T>
          ) : b.status === 'confirmed' ? (
            <T style={{ color: colors.inkSoft }}>Pay the balance for the changes you made.</T>
          ) : null}
        </View>

        {b.status === 'cancelled' ? <Notice tone="error">This booking was released because it was not paid in time. Search again to book.</Notice> : null}
        {due === 0 && b.status !== 'cancelled' ? <Notice tone="success">This booking is paid.</Notice> : null}
        {api.mode === 'demo' && due > 0 ? <Notice tone="info">Demo mode: no money moves. Payments complete instantly.</Notice> : null}

        {due > 0 && b.status !== 'cancelled' ? (
          <>
            <View accessibilityRole="radiogroup" accessibilityLabel="Payment method" style={{ gap: 10 }}>
              {(
                [
                  { id: 'mobile', label: 'Mobile money', sub: 'EVC Plus, ZAAD, SAHAL, WAAFI', icon: <Icon.Phone /> },
                  { id: 'card', label: 'Card', sub: 'Visa, Mastercard, Apple Pay, Google Pay', icon: <Icon.Card /> },
                  ...(b.status === 'pending_payment' ? [{ id: 'hold', label: 'Hold and pay later', sub: 'Keep this price, pay within 48 hours', icon: <Icon.Hourglass /> }] : []),
                ] as { id: Method; label: string; sub: string; icon: React.ReactNode }[]
              ).map((m) => {
                const sel = method === m.id;
                return (
                  <Pressable
                    key={m.id}
                    accessibilityRole="radio"
                    accessibilityState={{ selected: sel }}
                    onPress={() => setMethod(m.id)}
                    style={{ flexDirection: 'row', alignItems: 'center', gap: 14, padding: 18, borderRadius: radius.xl, borderWidth: sel ? 2 : 1, borderColor: sel ? colors.blue : colors.line, backgroundColor: sel ? colors.mist : colors.white }}>
                    {m.icon}
                    <View style={{ flex: 1 }}>
                      <T v="title">{m.label}</T>
                      <T v="small">{m.sub}</T>
                    </View>
                  </Pressable>
                );
              })}
            </View>

            {method === 'mobile' ? (
              <Card style={{ gap: 16, padding: 20 }}>
                <T v="bodyStrong">Choose your wallet</T>
                <Row style={{ flexWrap: 'wrap' }}>
                  {WALLETS.map((w) => (
                    <Chip key={w.id} label={w.label} selected={wallet === w.id} onPress={() => setWallet(w.id)} />
                  ))}
                </Row>
                <View style={{ gap: 6 }}>
                  <T v="bodyStrong">Mobile number</T>
                  <View style={{ flexDirection: 'row', borderWidth: 1, borderColor: colors.lineStrong, borderRadius: radius.lg, overflow: 'hidden' }}>
                    <View style={{ paddingHorizontal: 16, justifyContent: 'center', backgroundColor: colors.mist, borderRightWidth: 1, borderRightColor: colors.line }}>
                      <T style={{ fontFamily: fonts.bodySemi, fontSize: 18 }}>+252</T>
                    </View>
                    <TextInput
                      value={msisdn}
                      onChangeText={setMsisdn}
                      keyboardType="phone-pad"
                      placeholder="61 555 0142"
                      placeholderTextColor={colors.inkFaint}
                      accessibilityLabel="Mobile number"
                      style={{ flex: 1, padding: 16, fontSize: 18, fontFamily: fonts.body, color: colors.ink }}
                    />
                  </View>
                  <T v="small">The number can be yours or a relative’s. The owner of the phone approves the payment.</T>
                </View>
                {[
                  'We send a payment request to the phone',
                  `The phone owner approves it with their ${walletName} PIN`,
                  'Your tickets arrive by SMS, WhatsApp and email',
                ].map((t, i) => (
                  <Row key={t} gap={12} style={{ alignItems: 'flex-start' }}>
                    <T style={{ fontFamily: fonts.display, fontSize: 22, color: colors.blue, width: 20 }}>{i + 1}</T>
                    <T style={{ flex: 1, fontSize: 15 }}>{t}</T>
                  </Row>
                ))}
                <Button title={`Send payment request, ${formatUsd(due)}`} loading={busy && !waiting} disabled={busy} onPress={mobile} />
              </Card>
            ) : null}

            {method === 'card' ? (
              <Card style={{ gap: 12, padding: 20 }}>
                <T>Pay securely with Stripe. Your card details never touch our servers.</T>
                <Button title={`Pay ${formatUsd(due)}`} loading={busy && !waiting} disabled={busy} onPress={card} />
              </Card>
            ) : null}

            {method === 'hold' ? (
              <Card style={{ gap: 12, padding: 20 }}>
                <T v="title">Hold this price</T>
                <T style={{ color: colors.inkSoft }}>Keep the fare while you collect money from family. Pay later with mobile money, card or cash at a sales office. If you don’t pay in time, the booking is released.</T>
                <Button title="Hold my fare" loading={busy} onPress={hold} />
              </Card>
            ) : null}

            {waiting ? (
              <View accessibilityRole="alert" style={{ flexDirection: 'row', gap: 16, alignItems: 'center', padding: 20, borderRadius: radius.xl, backgroundColor: colors.mist, borderWidth: 1, borderColor: '#9AB9DE' }}>
                <ActivityIndicator color={colors.blue} />
                <View style={{ flex: 1 }}>
                  <T v="bodyStrong">{waiting}</T>
                  {method === 'mobile' ? <T v="small">{`Enter the ${walletName} PIN on that phone.`}</T> : null}
                </View>
              </View>
            ) : null}
            {error ? <Notice tone="error">{error}</Notice> : null}
          </>
        ) : null}

        <Card style={{ padding: 0, overflow: 'hidden', gap: 0 }}>
          <View style={{ backgroundColor: colors.navy, padding: 20, gap: 4 }}>
            <T v="small" style={{ color: colors.footerText }}>{b.segments.length > 1 ? 'Return trip' : 'One way'}</T>
            <T v="h2" style={{ color: colors.white }}>{`${first.origin} to ${first.destination}`}</T>
            <T style={{ color: colors.footerText, fontSize: 15 }}>
              {b.segments.length > 1 ? `${shortDate(first.date)} to ${shortDate(last.date)}` : `${shortDate(first.date)}, ${cityName(first.origin)} to ${cityName(first.destination)}`}
            </T>
          </View>
          <View style={{ padding: 20, gap: 16 }}>
            {b.passengers.map((p) => (
              <Row key={p.id} style={{ justifyContent: 'space-between' }}>
                <T>{`${p.firstName} ${p.lastName}`}</T>
                <T v="small">{`${p.type[0].toUpperCase()}${p.type.slice(1)}${p.seats[0] ? `, ${p.seats[0]}` : ''}`}</T>
              </Row>
            ))}
            <PriceSummary price={b.price} paid={b.paid} />
            <T v="small">{`Booking reference ${b.pnr}. By paying you accept the conditions of carriage and the fare rules.`}</T>
          </View>
        </Card>
      </View>
    </Screen>
  );
}
