import type { SupabaseClient } from 'npm:@supabase/supabase-js@2';

import type { AirlineStore } from './core/service.ts';
import { AirlineError, type Booking, type Cabin, type FlightOps } from './core/types.ts';

/** Bookings in Postgres. Uses the service role; see migrations for the schema. */
export class PgStore implements AirlineStore {
  private db: SupabaseClient;

  constructor(db: SupabaseClient) {
    this.db = db;
  }

  private async one(column: 'pnr' | 'id', value: string): Promise<Booking | null> {
    const { data, error } = await this.db.from('bookings').select('data').eq(column, value).maybeSingle();
    if (error) throw error;
    return (data?.data as Booking) ?? null;
  }

  getBookingByPnr(pnr: string) {
    return this.one('pnr', pnr);
  }

  getBookingById(id: string) {
    return this.one('id', id);
  }

  async listBookingsForUser(userId: string) {
    const { data, error } = await this.db
      .from('bookings')
      .select('data')
      .eq('user_id', userId)
      .order('first_departure', { ascending: true })
      .limit(100);
    if (error) throw error;
    return (data ?? []).map((r) => r.data as Booking);
  }

  private async save(b: Booking) {
    const { error } = await this.db.rpc('airline_save_booking', { p: b });
    if (error) {
      if (error.code === '23505') throw new AirlineError('seat_taken', 'A seat you picked was just taken. Pick another.');
      throw error;
    }
  }

  insertBooking(b: Booking) {
    return this.save(b);
  }

  updateBooking(b: Booking) {
    return this.save(b);
  }

  async takenSeats(flightId: string) {
    const { data, error } = await this.db.rpc('airline_taken_seats', { p_flight_id: flightId });
    if (error) throw error;
    return new Set<string>((data ?? []) as string[]);
  }

  async bookedCounts(flightIds: string[]) {
    const out: Record<string, Record<Cabin, number>> = {};
    for (const id of flightIds) out[id] = { economy: 0, business: 0 };
    const { data, error } = await this.db.rpc('airline_booked_counts', { p_flight_ids: flightIds });
    if (error) throw error;
    for (const r of (data ?? []) as { flight_id: string; cabin: Cabin; pax: number }[]) {
      out[r.flight_id][r.cabin] = Number(r.pax);
    }
    return out;
  }

  async flightOps(flightIds: string[]) {
    const { data, error } = await this.db
      .from('flight_ops')
      .select('flight_id,status,delay_min,gate,note')
      .in('flight_id', flightIds);
    if (error) throw error;
    const out: Record<string, Partial<FlightOps>> = {};
    for (const r of data ?? []) {
      out[r.flight_id] = {
        ...(r.status ? { status: r.status } : {}),
        delayMin: r.delay_min,
        gate: r.gate,
        note: r.note,
      };
    }
    return out;
  }
}
