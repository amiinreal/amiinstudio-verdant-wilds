import { createContext, useContext, useEffect, useState, type ReactNode } from 'react';

import type { User } from '@core/types';

import { api } from './api';

type AuthState = { user: User | null; ready: boolean };

const AuthContext = createContext<AuthState>({ user: null, ready: false });

export function AuthProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<AuthState>({ user: null, ready: false });

  useEffect(() => {
    let alive = true;
    api.auth
      .current()
      .then((user) => alive && setState({ user, ready: true }))
      .catch(() => alive && setState({ user: null, ready: true }));
    const off = api.auth.onChange((user) => alive && setState({ user, ready: true }));
    return () => {
      alive = false;
      off();
    };
  }, []);

  return <AuthContext.Provider value={state}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  return useContext(AuthContext);
}
