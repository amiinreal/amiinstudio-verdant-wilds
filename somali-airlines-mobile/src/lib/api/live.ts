import 'react-native-url-polyfill/auto';

import AsyncStorage from '@react-native-async-storage/async-storage';
import { createClient, type User as SupabaseUser } from '@supabase/supabase-js';
import { Platform } from 'react-native';

import { AirlineError, type User } from '@core/types';

import { config } from '../config';
import type { AirlineApi } from './types';

// Live mode: every airline action runs in the `airline` Edge Function, which
// owns pricing, seat inventory and Stripe. The app never decides a price.

export const supabase = createClient(config.supabaseUrl || 'http://localhost', config.supabaseAnonKey || 'anon', {
  auth: {
    storage: AsyncStorage,
    autoRefreshToken: true,
    persistSession: true,
    detectSessionInUrl: Platform.OS === 'web',
  },
});

async function call<T>(action: string, args: Record<string, unknown> = {}): Promise<T> {
  const { data, error } = await supabase.functions.invoke('airline', { body: { action, args } });
  if (error) {
    let message = 'Something went wrong. Try again.';
    let code = 'error';
    try {
      const body = await (error as { context?: Response }).context?.json();
      if (body?.error) {
        message = body.error.message;
        code = body.error.code;
      }
    } catch {
      // Network errors have no body.
      message = 'We could not reach Somali Airlines. Check your connection.';
    }
    throw new AirlineError(code, message);
  }
  return data as T;
}

async function toUser(u: SupabaseUser | null): Promise<User | null> {
  if (!u) return null;
  const { data } = await supabase.from('profiles').select('first_name,last_name,phone,loyalty_number').eq('id', u.id).maybeSingle();
  return {
    id: u.id,
    email: u.email ?? '',
    firstName: data?.first_name ?? u.user_metadata?.first_name ?? '',
    lastName: data?.last_name ?? u.user_metadata?.last_name ?? '',
    phone: data?.phone ?? u.user_metadata?.phone ?? '',
    loyaltyNumber: data?.loyalty_number ?? '',
  };
}

function authError(e: { message: string } | null): never | void {
  if (e) throw new AirlineError('auth', e.message);
}

export const liveApi: AirlineApi = {
  mode: 'live',

  searchFlights: (q) => call('searchFlights', { q }),
  datePrices: (origin, destination, date, cabin) => call('datePrices', { origin, destination, date, cabin }),
  getFlight: (id) => call('getFlight', { id }),
  seatMap: (flightId, pnr) => call('seatMap', { flightId, pnr }),
  flightStatus: (q) => call('flightStatus', { q }),

  quote: (input) => call('quote', { input }),
  createBooking: (input) => call('createBooking', { input }),
  getBooking: (ref) => call('getBooking', { ref }),
  myBookings: () => call('myBookings'),
  claimBooking: (ref) => call('claimBooking', { ref }),
  updateSeats: (ref, changes) => call('updateSeats', { ref, changes }),
  updateBags: (ref, bags) => call('updateBags', { ref, bags }),
  updatePassengerDetails: (ref, details) => call('updatePassengerDetails', { ref, details }),
  changeOptions: (ref, segmentIndex, date) => call('changeOptions', { ref, segmentIndex, date }),
  changeFlight: (ref, segmentIndex, flightId) => call('changeFlight', { ref, segmentIndex, flightId }),
  refundQuote: (ref) => call('refundQuote', { ref }),
  cancelBooking: (ref) => call('cancelBooking', { ref }),
  checkIn: (ref, segmentIndex, passengerIds, docs) => call('checkIn', { ref, segmentIndex, passengerIds, docs }),
  boardingPasses: (ref, segmentIndex) => call('boardingPasses', { ref, segmentIndex }),

  holdFare: (ref) => call('holdFare', { ref }),
  startCardPayment: (ref) =>
    call('startCardPayment', {
      ref,
      platform: Platform.OS,
      returnUrl: Platform.OS === 'web' && typeof window !== 'undefined' ? window.location.origin : `${config.urlScheme}://`,
    }),
  startMobileMoney: (ref, wallet, msisdn) => call('startMobileMoney', { ref, wallet, msisdn }),
  completeDemoPayment: async () => {
    throw new AirlineError('live', 'Simulated payments are only available in demo mode.');
  },

  auth: {
    async current() {
      const { data } = await supabase.auth.getSession();
      return toUser(data.session?.user ?? null);
    },
    async signIn(email, password) {
      const { data, error } = await supabase.auth.signInWithPassword({ email: email.trim(), password });
      authError(error);
      return (await toUser(data.user))!;
    },
    async signUp(input) {
      const { data, error } = await supabase.auth.signUp({
        email: input.email.trim(),
        password: input.password,
        options: { data: { first_name: input.firstName.trim(), last_name: input.lastName.trim(), phone: input.phone.trim() } },
      });
      authError(error);
      if (!data.session) {
        throw new AirlineError('confirm_email', 'Check your email and tap the link to finish creating your account.');
      }
      return (await toUser(data.user))!;
    },
    async signOut() {
      await supabase.auth.signOut();
    },
    async resetPassword(email) {
      const { error } = await supabase.auth.resetPasswordForEmail(email.trim());
      authError(error);
    },
    async updateProfile(p) {
      const { data } = await supabase.auth.getUser();
      if (!data.user) throw new AirlineError('auth', 'Log in first.');
      const { error } = await supabase
        .from('profiles')
        .update({ first_name: p.firstName, last_name: p.lastName, phone: p.phone })
        .eq('id', data.user.id);
      authError(error);
      return (await toUser(data.user))!;
    },
    onChange(cb) {
      const { data } = supabase.auth.onAuthStateChange((_event, session) => {
        // Supabase warns against awaiting other calls inside this callback.
        setTimeout(() => void toUser(session?.user ?? null).then(cb), 0);
      });
      return () => data.subscription.unsubscribe();
    },
  },
};
