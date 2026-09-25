import type { AirlineStore } from './service.ts';
import type { Booking, Cabin, FlightOps } from './types.ts';

/** In-memory store with optional persistence hooks. Backs the demo app and tests. */
export class MemoryStore implements AirlineStore {
  private bookings = new Map<string, Booking>();
  ops: Record<string, Partial<FlightOps>> = {};

  private now: () => number;
  private persist: (all: Booking[]) => Promise<void>;

  constructor(now: () => number, persist: (all: Booking[]) => Promise<void> = async () => {}) {
    this.now = now;
    this.persist = persist;
  }

  load(all: Booking[]) {
    this.bookings = new Map(all.map((b) => [b.id, b]));
  }

  private clone(b: Booking): Booking {
    return JSON.parse(JSON.stringify(b));
  }

  private live(b: Booking): boolean {
    if (b.status === 'confirmed') return true;
    if (b.status === 'cancelled') return false;
    return !b.holdExpiresAt || Date.parse(b.holdExpiresAt) > this.now();
  }

  async getBookingByPnr(pnr: string) {
    for (const b of this.bookings.values()) if (b.pnr === pnr) return this.clone(b);
    return null;
  }

  async getBookingById(id: string) {
    const b = this.bookings.get(id);
    return b ? this.clone(b) : null;
  }

  async listBookingsForUser(userId: string) {
    return [...this.bookings.values()].filter((b) => b.userId === userId).map((b) => this.clone(b));
  }

  async insertBooking(b: Booking) {
    for (let i = 0; i < b.segments.length; i++) {
      const taken = await this.takenSeats(b.segments[i].flight.id);
      for (const p of b.passengers) {
        const s = p.seats[i];
        if (s && taken.has(s)) throw new Error(`Seat ${s} is taken`);
      }
    }
    this.bookings.set(b.id, this.clone(b));
    await this.persist([...this.bookings.values()]);
  }

  async updateBooking(b: Booking) {
    this.bookings.set(b.id, this.clone(b));
    await this.persist([...this.bookings.values()]);
  }

  async takenSeats(flightId: string) {
    const taken = new Set<string>();
    for (const b of this.bookings.values()) {
      if (!this.live(b)) continue;
      b.segments.forEach((s, i) => {
        if (s.flight.id !== flightId) return;
        b.passengers.forEach((p) => p.seats[i] && taken.add(p.seats[i]!));
      });
    }
    return taken;
  }

  async bookedCounts(flightIds: string[]) {
    const out: Record<string, Record<Cabin, number>> = {};
    for (const id of flightIds) out[id] = { economy: 0, business: 0 };
    for (const b of this.bookings.values()) {
      if (!this.live(b)) continue;
      for (const s of b.segments) {
        if (!out[s.flight.id]) continue;
        out[s.flight.id][s.cabin] += b.passengers.filter((p) => p.type !== 'infant').length;
      }
    }
    return out;
  }

  async flightOps(flightIds: string[]) {
    const out: Record<string, Partial<FlightOps>> = {};
    for (const id of flightIds) if (this.ops[id]) out[id] = this.ops[id];
    return out;
  }
}
