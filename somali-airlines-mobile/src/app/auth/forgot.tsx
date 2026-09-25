import { useState } from 'react';
import { View } from 'react-native';

import { Button, Field, Notice, Screen, T, TopBar } from '@/components/ui';
import { api, errorMessage } from '@/lib/api';

export default function Forgot() {
  const [email, setEmail] = useState('');
  const [busy, setBusy] = useState(false);
  const [msg, setMsg] = useState<{ tone: 'error' | 'success'; text: string } | null>(null);

  const submit = async () => {
    setBusy(true);
    setMsg(null);
    try {
      await api.auth.resetPassword(email);
      setMsg({
        tone: 'success',
        text: api.mode === 'demo' ? 'Demo accounts live on this phone only, so no email is sent. Create a new account instead.' : 'If there is an account for this email, a reset link is on its way.',
      });
    } catch (e) {
      setMsg({ tone: 'error', text: errorMessage(e) });
    } finally {
      setBusy(false);
    }
  };

  return (
    <Screen edges={['top', 'bottom']}>
      <TopBar title="Reset password" />
      <View style={{ padding: 20, gap: 16 }}>
        <T>Enter your email and we will send you a link to choose a new password.</T>
        <Field label="Email" value={email} onChangeText={setEmail} keyboardType="email-address" autoCapitalize="none" autoComplete="email" />
        {msg ? <Notice tone={msg.tone}>{msg.text}</Notice> : null}
        <Button title="Send reset link" loading={busy} onPress={submit} />
      </View>
    </Screen>
  );
}
