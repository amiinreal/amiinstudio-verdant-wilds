import AsyncStorage from '@react-native-async-storage/async-storage';
import * as Crypto from 'expo-crypto';

import { MemoryStore } from '@core/memory-store';
import { AirlineService } from '@core/service';
import { AirlineError, type Booking, type User } from '@core/types';

import type { AirlineApi, BookingRef, SignUpInput } from './types';

// Demo mode: the airline backend runs on the device and keeps its data in
// AsyncStorage. Nothing leaves the phone and payments are simulated.

const BOOKINGS_KEY = 'sa.demo.bookings.v1';
const USERS_KEY = 'sa.demo.users.v1';
const SESSION_KEY = 'sa.demo.session.v1';

type StoredUser = User & { passwordHash: string };

const store = new MemoryStore(Date.now, async (all) => {
  await AsyncStorage.setItem(BOOKINGS_KEY, JSON.stringify(all));
});

const service = new AirlineService(store, {
  demo: true,
  now: Date.now,
  randomInt: (n) => Crypto.getRandomBytes(1)[0] % n,
  paymentHoldMinutes: 30,
  fareHoldHours: 48,
});

let ready: Promise<void> | null = null;
function init(): Promise<void> {
  ready ??= (async () => {
    const raw = await AsyncStorage.getItem(BOOKINGS_KEY);
    if (raw) store.load(JSON.parse(raw) as Booking[]);
  })();
  return ready;
}

async function users(): Promise<Record<string, StoredUser>> {
  const raw = await AsyncStorage.getItem(USERS_KEY);
  return raw ? JSON.parse(raw) : {};
}

async function hashPassword(email: string, password: string) {
  return Crypto.digestStringAsync(Crypto.CryptoDigestAlgorithm.SHA256, `${email.toLowerCase()}:${password}`);
}

function publicUser(u: StoredUser): User {
  const { passwordHash: _ignored, ...rest } = u;
  return rest;
}

const listeners = new Set<(u: User | null) => void>();
async function currentUser(): Promise<User | null> {
  const id = await AsyncStorage.getItem(SESSION_KEY);
  if (!id) return null;
  const all = await users();
  const u = Object.values(all).find((x) => x.id === id);
  return u ? publicUser(u) : null;
}
async function uid(): Promise<string | null> {
  return (await currentUser())?.id ?? null;
}
function emit(u: User | null) {
  listeners.forEach((l) => l(u));
}

async function run<T>(fn: () => Promise<T>): Promise<T> {
  await init();
  return fn();
}

const ref = async (r: BookingRef) => [r.pnr, r.lastName || null, await uid()] as const;

export const demoApi: AirlineApi = {
  mode: 'demo',

  searchFlights: (q) => run(() => service.searchFlights(q)),
  datePrices: (o, d, date, cabin) => run(() => service.datePrices(o, d, date, cabin)),
  getFlight: (id) => run(() => service.getFlight(id)),
  seatMap: (id, pnr) => run(() => service.seatMap(id, pnr)),
  flightStatus: (q) => run(() => service.flightStatus(q)),

  quote: (input) => run(() => service.quote(input)),
  createBooking: (input) => run(async () => service.createBooking(input, await uid())),
  getBooking: (r) => run(async () => service.getBooking(...(await ref(r)))),
  myBookings: () =>
    run(async () => {
      const id = await uid();
      return id ? service.myBookings(id) : [];
    }),
  claimBooking: (r) =>
    run(async () => {
      const id = await uid();
      if (!id) throw new AirlineError('auth', 'Log in to save bookings to your account.');
      return service.claimBooking(r.pnr, r.lastName, id);
    }),
  updateSeats: (r, c) => run(async () => service.updateSeats(...(await ref(r)), c)),
  updateBags: (r, b) => run(async () => service.updateBags(...(await ref(r)), b)),
  updatePassengerDetails: (r, d) => run(async () => service.updatePassengerDetails(...(await ref(r)), d)),
  changeOptions: (r, i, date) => run(async () => service.changeOptions(...(await ref(r)), i, date)),
  changeFlight: (r, i, f) => run(async () => service.changeFlight(...(await ref(r)), i, f)),
  refundQuote: (r) => run(async () => service.refundQuote(await service.getBooking(...(await ref(r))))),
  cancelBooking: (r) =>
    run(async () => {
      const res = await service.cancelBooking(...(await ref(r)));
      if (res.refund > 0) {
        const b = await service.recordRefund(res.booking.id, res.refund, 'demo-refund');
        return { booking: b, refund: res.refund };
      }
      return res;
    }),
  checkIn: (r, i, ids, docs) => run(async () => service.checkIn(...(await ref(r)), i, ids, docs)),
  boardingPasses: (r, i) => run(async () => service.boardingPasses(...(await ref(r)), i)),

  holdFare: (r) => run(async () => service.holdFare(...(await ref(r)))),
  startCardPayment: (r) =>
    run(async () => {
      const b = await service.getBooking(...(await ref(r)));
      return { kind: 'demo', amount: Math.max(0, b.price.total - b.paid) };
    }),
  startMobileMoney: async () => ({ requestId: `demo-${Date.now()}` }),
  completeDemoPayment: (r, method) =>
    run(async () => {
      const b = await service.getBooking(...(await ref(r)));
      const amount = Math.round((b.price.total - b.paid) * 100) / 100;
      if (amount <= 0) return b;
      return service.recordPayment(b.id, {
        method: 'demo',
        provider: method === 'card' ? 'Demo card' : 'Demo mobile money',
        amount,
        status: 'succeeded',
        reference: `demo-${Date.now()}`,
      });
    }),

  auth: {
    current: currentUser,
    async signIn(email, password) {
      const all = await users();
      const u = all[email.trim().toLowerCase()];
      if (!u || u.passwordHash !== (await hashPassword(email.trim(), password))) {
        throw new AirlineError('auth', 'The email or password is not right.');
      }
      await AsyncStorage.setItem(SESSION_KEY, u.id);
      emit(publicUser(u));
      return publicUser(u);
    },
    async signUp(input: SignUpInput) {
      const email = input.email.trim().toLowerCase();
      if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) throw new AirlineError('auth', 'Enter a valid email address.');
      if (input.password.length < 8) throw new AirlineError('auth', 'Use at least 8 characters for the password.');
      const all = await users();
      if (all[email]) throw new AirlineError('auth', 'There is already an account with this email. Log in instead.');
      const u: StoredUser = {
        id: Crypto.randomUUID(),
        email,
        firstName: input.firstName.trim(),
        lastName: input.lastName.trim(),
        phone: input.phone.trim(),
        loyaltyNumber: `XC${String(Crypto.getRandomBytes(4).reduce((a, b) => a * 256 + b, 0)).slice(0, 8).padStart(8, '0')}`,
        passwordHash: await hashPassword(email, input.password),
      };
      all[email] = u;
      await AsyncStorage.setItem(USERS_KEY, JSON.stringify(all));
      await AsyncStorage.setItem(SESSION_KEY, u.id);
      emit(publicUser(u));
      return publicUser(u);
    },
    async signOut() {
      await AsyncStorage.removeItem(SESSION_KEY);
      emit(null);
    },
    async resetPassword() {
      // Demo accounts live on this device only, so there is no email to send.
    },
    async updateProfile(p) {
      const all = await users();
      const id = await uid();
      const entry = Object.entries(all).find(([, u]) => u.id === id);
      if (!entry) throw new AirlineError('auth', 'Log in first.');
      all[entry[0]] = { ...entry[1], ...p };
      await AsyncStorage.setItem(USERS_KEY, JSON.stringify(all));
      const u = publicUser(all[entry[0]]);
      emit(u);
      return u;
    },
    onChange(cb) {
      listeners.add(cb);
      return () => listeners.delete(cb);
    },
  },
};
