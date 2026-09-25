import { router } from 'expo-router';
import { useState } from 'react';
import { ScrollView, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { Icon } from '@/components/icons';
import { BrandBar, Button, Card, Divider, Field, ListLink, Notice, Row, T } from '@/components/ui';
import { api, errorMessage } from '@/lib/api';
import { useAuth } from '@/lib/auth';
import { colors, fonts, radius } from '@/lib/theme';

export default function Account() {
  const { user, ready } = useAuth();
  const [editing, setEditing] = useState(false);
  const [form, setForm] = useState({ firstName: '', lastName: '', phone: '' });
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ tone: 'error' | 'success'; text: string } | null>(null);

  const save = async () => {
    setBusy(true);
    setMsg(null);
    try {
      await api.auth.updateProfile(form);
      setEditing(false);
      setMsg({ tone: 'success', text: 'Saved.' });
    } catch (e) {
      setMsg({ tone: 'error', text: errorMessage(e) });
    } finally {
      setBusy(false);
    }
  };

  return (
    <SafeAreaView edges={['top']} style={{ flex: 1, backgroundColor: colors.page }}>
      <BrandBar />
      <ScrollView contentContainerStyle={{ padding: 16, gap: 16, paddingBottom: 40 }} keyboardShouldPersistTaps="handled">
        <T v="h1">Account</T>
        {!ready ? null : user ? (
          <>
            <Card tone="navy" style={{ gap: 6, padding: 20 }}>
              <T v="small" style={{ color: colors.footerText }}>White Star member</T>
              <T v="h2" style={{ color: colors.white }}>{`${user.firstName} ${user.lastName}`.trim() || user.email}</T>
              {user.loyaltyNumber ? (
                <Row>
                  <View style={{ backgroundColor: colors.gold, paddingHorizontal: 10, paddingVertical: 4, borderRadius: radius.pill }}>
                    <T v="caption" style={{ color: colors.navy, fontFamily: fonts.bodySemi, letterSpacing: 1 }}>{user.loyaltyNumber}</T>
                  </View>
                </Row>
              ) : null}
            </Card>

            <Card style={{ gap: 12 }}>
              <Row style={{ justifyContent: 'space-between' }}>
                <T v="title">Your details</T>
                {!editing ? (
                  <Button
                    small
                    kind="ghost"
                    title="Edit"
                    onPress={() => {
                      setForm({ firstName: user.firstName, lastName: user.lastName, phone: user.phone });
                      setEditing(true);
                    }}
                  />
                ) : null}
              </Row>
              {editing ? (
                <>
                  <Field label="First name" value={form.firstName} onChangeText={(firstName) => setForm({ ...form, firstName })} />
                  <Field label="Last name" value={form.lastName} onChangeText={(lastName) => setForm({ ...form, lastName })} />
                  <Field label="Mobile number" value={form.phone} keyboardType="phone-pad" onChangeText={(phone) => setForm({ ...form, phone })} />
                  <Row>
                    <Button title="Save" loading={busy} onPress={save} style={{ flex: 1 }} />
                    <Button kind="secondary" title="Cancel" onPress={() => setEditing(false)} style={{ flex: 1 }} />
                  </Row>
                </>
              ) : (
                <View style={{ gap: 4 }}>
                  <T>{user.email}</T>
                  <T v="small">{user.phone || 'No phone number'}</T>
                </View>
              )}
              {msg ? <Notice tone={msg.tone}>{msg.text}</Notice> : null}
            </Card>

            <Card style={{ padding: 0, gap: 0, overflow: 'hidden' }}>
              <ListLink icon={<Icon.Ticket />} title="My trips" onPress={() => router.navigate('/trips')} />
              <Divider />
              <ListLink icon={<Icon.Chat />} title="Contact us" onPress={() => router.push('/info/contact')} />
              <Divider />
              <ListLink icon={<Icon.Shield />} title="Privacy" onPress={() => router.push('/info/privacy')} />
            </Card>
            <Button kind="danger" title="Log out" icon={<Icon.Logout color={colors.red} />} onPress={() => api.auth.signOut()} />
          </>
        ) : (
          <>
            <Card style={{ gap: 12, padding: 20 }}>
              <T v="h3">Log in to Somali Airlines</T>
              <T style={{ color: colors.inkSoft }}>See all your trips on any phone, check in faster and keep your passenger details ready.</T>
              <Button title="Log in" onPress={() => router.push('/auth/login')} />
              <Button kind="secondary" title="Create an account" onPress={() => router.push('/auth/register')} />
            </Card>
            <Card style={{ padding: 0, gap: 0, overflow: 'hidden' }}>
              <ListLink icon={<Icon.Search />} title="Find a booking" sub="No account needed" onPress={() => router.push('/booking/find')} />
              <Divider />
              <ListLink icon={<Icon.Chat />} title="Contact us" onPress={() => router.push('/info/contact')} />
            </Card>
          </>
        )}
        {api.mode === 'demo' ? (
          <Notice tone="info" title="Demo mode">
            Bookings, accounts and payments stay on this device and no money moves. Connect Supabase and Stripe to go live (see the README).
          </Notice>
        ) : null}
      </ScrollView>
    </SafeAreaView>
  );
}
