import { router } from 'expo-router';
import { useState } from 'react';
import { KeyboardAvoidingView, Platform, View } from 'react-native';

import { Button, Field, Notice, Screen, T, TopBar } from '@/components/ui';
import { api, errorMessage } from '@/lib/api';

export default function Login() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const submit = async () => {
    setError(null);
    if (!email.trim() || !password) return setError('Enter your email and password.');
    setBusy(true);
    try {
      await api.auth.signIn(email, password);
      router.back();
    } catch (e) {
      setError(errorMessage(e));
    } finally {
      setBusy(false);
    }
  };

  return (
    <KeyboardAvoidingView style={{ flex: 1 }} behavior={Platform.OS === 'ios' ? 'padding' : undefined}>
      <Screen edges={['top', 'bottom']}>
        <TopBar title="Log in" />
        <View style={{ padding: 20, gap: 16 }}>
          <T v="h2">Welcome back</T>
          <Field label="Email" value={email} onChangeText={setEmail} keyboardType="email-address" autoCapitalize="none" autoComplete="email" textContentType="emailAddress" />
          <Field label="Password" value={password} onChangeText={setPassword} secureTextEntry autoComplete="current-password" textContentType="password" returnKeyType="go" onSubmitEditing={submit} />
          {error ? <Notice tone="error">{error}</Notice> : null}
          <Button title="Log in" loading={busy} onPress={submit} />
          <Button kind="ghost" title="Forgot your password?" onPress={() => router.push('/auth/forgot')} />
          <T style={{ textAlign: 'center' }}>No account yet?</T>
          <Button kind="secondary" title="Create an account" onPress={() => router.replace('/auth/register')} />
        </View>
      </Screen>
    </KeyboardAvoidingView>
  );
}
