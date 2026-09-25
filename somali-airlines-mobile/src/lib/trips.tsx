import AsyncStorage from '@react-native-async-storage/async-storage';
import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from 'react';

import type { BookingRef } from './api';

// Bookings this device has opened, so guests can find their trips again
// without an account. Only the reference and a last name are kept.
const KEY = 'sa.trips.v1';

type TripsState = {
  refs: BookingRef[];
  ready: boolean;
  remember: (ref: BookingRef) => void;
  forget: (pnr: string) => void;
  refFor: (pnr: string) => BookingRef;
};

const TripsContext = createContext<TripsState | null>(null);

export function TripsProvider({ children }: { children: ReactNode }) {
  const [refs, setRefs] = useState<BookingRef[]>([]);
  const [ready, setReady] = useState(false);

  useEffect(() => {
    AsyncStorage.getItem(KEY)
      .then((raw) => raw && setRefs(JSON.parse(raw)))
      .finally(() => setReady(true));
  }, []);

  const save = useCallback((next: BookingRef[]) => {
    setRefs(next);
    void AsyncStorage.setItem(KEY, JSON.stringify(next));
  }, []);

  const remember = useCallback(
    (ref: BookingRef) => {
      const pnr = ref.pnr.toUpperCase();
      setRefs((cur) => {
        const next = [{ pnr, lastName: ref.lastName }, ...cur.filter((r) => r.pnr !== pnr)].slice(0, 30);
        void AsyncStorage.setItem(KEY, JSON.stringify(next));
        return next;
      });
    },
    [],
  );

  const forget = useCallback((pnr: string) => save(refs.filter((r) => r.pnr !== pnr)), [refs, save]);

  const refFor = useCallback(
    (pnr: string): BookingRef => refs.find((r) => r.pnr === pnr.toUpperCase()) ?? { pnr: pnr.toUpperCase(), lastName: '' },
    [refs],
  );

  const value = useMemo(() => ({ refs, ready, remember, forget, refFor }), [refs, ready, remember, forget, refFor]);
  return <TripsContext.Provider value={value}>{children}</TripsContext.Provider>;
}

export function useTrips() {
  const ctx = useContext(TripsContext);
  if (!ctx) throw new Error('useTrips outside TripsProvider');
  return ctx;
}
