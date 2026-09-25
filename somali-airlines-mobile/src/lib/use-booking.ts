import { useLocalSearchParams } from 'expo-router';

import { api } from './api';
import { useTrips } from './trips';
import { useAsync } from './use-async';

/** The booking named in the route (`[pnr]`), found by the saved last name or the logged-in account. */
export function useBooking() {
  const { pnr } = useLocalSearchParams<{ pnr: string }>();
  const { refFor } = useTrips();
  const ref = refFor(pnr);
  const state = useAsync(() => api.getBooking(ref), [pnr, ref.lastName]);
  return { pnr: ref.pnr, ref, ...state };
}
