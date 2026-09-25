import { useCallback, useEffect, useState } from 'react';

import { errorMessage } from './api';

type State<T> = { key: string | null; data: T | null; error: string | null };

/**
 * Loads data whenever `deps` change. Keeps the previous data while reloading;
 * `reload` runs it again and `setData` swaps in a result from an update call.
 */
export function useAsync<T>(fn: () => Promise<T>, deps: unknown[]) {
  const [nonce, setNonce] = useState(0);
  const key = `${JSON.stringify(deps)}#${nonce}`;
  const [state, setState] = useState<State<T>>({ key: null, data: null, error: null });

  useEffect(() => {
    let alive = true;
    fn().then(
      (data) => alive && setState({ key, data, error: null }),
      (e) => alive && setState((s) => ({ key, data: s.data, error: errorMessage(e) })),
    );
    return () => {
      alive = false;
    };
    // `fn` is rebuilt every render; `key` captures what it depends on.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);

  const reload = useCallback(() => setNonce((n) => n + 1), []);
  const setData = useCallback((data: T) => setState((s) => ({ ...s, data })), []);

  return {
    data: state.data,
    error: state.key === key ? state.error : null,
    loading: state.key !== key,
    reload,
    setData,
  };
}

/** The current time, refreshed every `everyMs`, so screens can show countdowns without reading the clock during render. */
export function useNow(everyMs = 30_000) {
  const [now, setNow] = useState(() => Date.now());
  useEffect(() => {
    const t = setInterval(() => setNow(Date.now()), everyMs);
    return () => clearInterval(t);
  }, [everyMs]);
  return now;
}
