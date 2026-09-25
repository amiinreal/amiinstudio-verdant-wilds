import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from 'react';

import { addDays, todayAt } from '@core/time';
import type { Flight, FareFamily, PassengerInput, PassengerType, SearchQuery } from '@core/types';

// The booking the customer is building, from search to payment.

export type Picked = { flight: Flight; fare: FareFamily };

export type Draft = {
  query: SearchQuery;
  outbound: Picked | null;
  inbound: Picked | null;
  passengers: PassengerInput[];
  contact: { email: string; phone: string };
};

function blankPassenger(type: PassengerType, segments: number): PassengerInput {
  return {
    type,
    title: '',
    firstName: '',
    lastName: '',
    dateOfBirth: '',
    nationality: '',
    passportNumber: '',
    passportExpiry: '',
    seats: Array.from({ length: segments }, () => null),
    extraBags: 0,
  };
}

export function passengersFor(q: SearchQuery, segments: number, existing: PassengerInput[] = []): PassengerInput[] {
  const want: PassengerType[] = [
    ...Array<PassengerType>(q.adults).fill('adult'),
    ...Array<PassengerType>(q.children).fill('child'),
    ...Array<PassengerType>(q.infants).fill('infant'),
  ];
  const pool = [...existing];
  return want.map((type) => {
    const i = pool.findIndex((p) => p.type === type);
    const p = i >= 0 ? pool.splice(i, 1)[0] : blankPassenger(type, segments);
    return { ...p, seats: Array.from({ length: segments }, (_, s) => p.seats[s] ?? null) };
  });
}

function initialQuery(): SearchQuery {
  const today = todayAt(3);
  return {
    origin: 'MGQ',
    destination: 'HGA',
    date: addDays(today, 14),
    returnDate: addDays(today, 28),
    tripType: 'return',
    adults: 1,
    children: 0,
    infants: 0,
    cabin: 'economy',
  };
}

type DraftCtx = {
  draft: Draft;
  setQuery: (patch: Partial<SearchQuery>) => void;
  pick: (leg: 'out' | 'in', p: Picked | null) => void;
  /** Changing the return date keeps the chosen outbound flight. */
  setReturnDate: (date: string) => void;
  setPassengers: (p: PassengerInput[]) => void;
  updatePassenger: (i: number, patch: Partial<PassengerInput>) => void;
  setContact: (c: Draft['contact']) => void;
  segments: Picked[];
  reset: () => void;
};

const Ctx = createContext<DraftCtx | null>(null);

export function DraftProvider({ children }: { children: ReactNode }) {
  const [draft, setDraft] = useState<Draft>(() => ({
    query: initialQuery(),
    outbound: null,
    inbound: null,
    passengers: [],
    contact: { email: '', phone: '' },
  }));

  const setQuery = useCallback((patch: Partial<SearchQuery>) => {
    setDraft((d) => ({ ...d, query: { ...d.query, ...patch }, outbound: null, inbound: null }));
  }, []);

  const pick = useCallback((leg: 'out' | 'in', p: Picked | null) => {
    setDraft((d) => (leg === 'out' ? { ...d, outbound: p, inbound: null } : { ...d, inbound: p }));
  }, []);

  const setReturnDate = useCallback((returnDate: string) => {
    setDraft((d) => ({ ...d, query: { ...d.query, returnDate }, inbound: null }));
  }, []);

  const setPassengers = useCallback((passengers: PassengerInput[]) => setDraft((d) => ({ ...d, passengers })), []);

  const updatePassenger = useCallback((i: number, patch: Partial<PassengerInput>) => {
    setDraft((d) => ({ ...d, passengers: d.passengers.map((p, j) => (j === i ? { ...p, ...patch } : p)) }));
  }, []);

  const setContact = useCallback((contact: Draft['contact']) => setDraft((d) => ({ ...d, contact })), []);

  const reset = useCallback(() => {
    setDraft((d) => ({ ...d, outbound: null, inbound: null, passengers: [], contact: d.contact }));
  }, []);

  const segments = useMemo(
    () => [draft.outbound, draft.query.tripType === 'return' ? draft.inbound : null].filter((x): x is Picked => !!x),
    [draft.outbound, draft.inbound, draft.query.tripType],
  );

  const value = useMemo(
    () => ({ draft, setQuery, pick, setReturnDate, setPassengers, updatePassenger, setContact, segments, reset }),
    [draft, setQuery, pick, setReturnDate, setPassengers, updatePassenger, setContact, segments, reset],
  );
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>;
}

export function useDraft() {
  const c = useContext(Ctx);
  if (!c) throw new Error('useDraft outside DraftProvider');
  return c;
}
