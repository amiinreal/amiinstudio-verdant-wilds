import { router } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, Platform, View } from 'react-native';

import { Button, Field, Notice, Screen, T, TopBar } from '@/components/ui';
import { api, errorMessage } from '@/lib/api';

export default function Register() {
  const [form, setForm] = useState({ firstName: '', lastName: '', email: '', phone: '', password: '' });
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ tone: 'error' | 'success'; text: string } | null>(null);
  const set = (k: keyof typeof form) => (v: string) => setForm((f) => ({ ...f, [k]: v }));

  const submit = async () => {
    setMsg(null);
    if (!form.firstName.trim() || !form.lastName.trim()) return setMsg({ tone: 'error', text: 'Enter your name as in your passport.' });
    if (form.password.length < 8) return setMsg({ tone: 'error', text: 'Use at least 8 characters for the password.' });
    setBusy(true);
    try {
      await api.auth.signUp(form);
      router.back();
    } catch (e) {
      const code = (e as { code?: string }).code;
      setMsg({ tone: code === 'confirm_email' ? 'success' : 'error', text: errorMessage(e) });
    } finally {
      setBusy(false);
    }
  };

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <Screen edges={['top', 'bottom']}>
        <TopBar title="Create an account" />
        <View style={{ padding: 20, gap: 16 }}>
          <T v="h2">Join the White Star</T>
          <Field label="First name" value={form.firstName} onChangeText={set('firstName')} autoComplete="given-name" autoCapitalize="words" />
          <Field label="Last name" value={form.lastName} onChangeText={set('lastName')} autoComplete="family-name" autoCapitalize="words" />
          <Field label="Email" value={form.email} onChangeText={set('email')} keyboardType="email-address" autoCapitalize="none" autoComplete="email" />
          <Field label="Mobile number" value={form.phone} onChangeText={set('phone')} keyboardType="phone-pad" autoComplete="tel" placeholder="+252 61 555 0142" />
          <Field label="Password" value={form.password} onChangeText={set('password')} secureTextEntry autoComplete="new-password" textContentType="newPassword" hint="At least 8 characters." />
          {msg ? <Notice tone={msg.tone}>{msg.text}</Notice> : null}
          <Button title="Create account" loading={busy} onPress={submit} />
          <Button kind="ghost" title="I already have an account" onPress={() => router.replace('/auth/login')} />
        </View>
      </Screen>
    </KeyboardAvoidingView>
  );
}
