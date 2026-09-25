import { AIRCRAFT } from './schedule.ts';
import { hash, seeded } from './time.ts';
import type { Cabin, Seat, SeatMap } from './types.ts';

// Airbus A320 layout: business rows 1-3 (2-2), economy rows 4-27 (3-3).
export const BUSINESS_ROWS = [1, 2, 3];
export const ECONOMY_ROWS = Array.from({ length: 24 }, (_, i) => i + 4);
export const EXIT_ROWS = [12, 13];
export const FRONT_ROWS = [4, 5, 6, 7];
const BUSINESS_LETTERS = [['A', 'C'], ['D', 'F']];
const ECONOMY_LETTERS = [['A', 'B', 'C'], ['D', 'E', 'F']];

export function parseSeat(seat: string): { row: number; letter: string } | null {
  const m = /^(\d{1,2})([A-F])$/.exec(seat);
  return m ? { row: Number(m[1]), letter: m[2] } : null;
}

export function seatCabin(seat: string): Cabin | null {
  const p = parseSeat(seat);
  if (!p) return null;
  if (BUSINESS_ROWS.includes(p.row)) return BUSINESS_LETTERS.flat().includes(p.letter) ? 'business' : null;
  if (ECONOMY_ROWS.includes(p.row)) return 'economy';
  return null;
}

export function seatKind(row: number): Seat['kind'] {
  if (BUSINESS_ROWS.includes(row)) return 'business';
  if (EXIT_ROWS.includes(row)) return 'exit';
  if (FRONT_ROWS.includes(row)) return 'front';
  return 'standard';
}

export const SEAT_PRICES: Record<Seat['kind'], number> = {
  business: 0,
  exit: 25,
  front: 15,
  standard: 10,
};

export function seatPrice(seat: string): number {
  const p = parseSeat(seat);
  return p ? SEAT_PRICES[seatKind(p.row)] : 0;
}

export function allSeats(cabin: Cabin): string[] {
  if (cabin === 'business') return BUSINESS_ROWS.flatMap((r) => BUSINESS_LETTERS.flat().map((l) => `${r}${l}`));
  return ECONOMY_ROWS.flatMap((r) => ECONOMY_LETTERS.flat().map((l) => `${r}${l}`));
}

/** Seats other passengers hold in the demo, so the map doesn't look empty. */
export function demoTakenSeats(flightId: string): Set<string> {
  const rnd = seeded(hash(flightId));
  const load = 0.35 + rnd() * 0.4;
  const taken = new Set<string>();
  for (const cabin of ['business', 'economy'] as Cabin[]) {
    for (const s of allSeats(cabin)) if (rnd() < load) taken.add(s);
  }
  return taken;
}

export function buildSeatMap(flightId: string, taken: Set<string>): SeatMap {
  const rows: SeatMap['rows'] = [];
  for (const row of [...BUSINESS_ROWS, ...ECONOMY_ROWS]) {
    const cabin: Cabin = BUSINESS_ROWS.includes(row) ? 'business' : 'economy';
    const letters = (cabin === 'business' ? BUSINESS_LETTERS : ECONOMY_LETTERS).flat();
    rows.push({
      row,
      cabin,
      exit: EXIT_ROWS.includes(row),
      seats: letters.map((letter) => {
        const id = `${row}${letter}`;
        const kind = seatKind(row);
        return {
          id,
          row,
          letter,
          cabin,
          kind,
          state: taken.has(id) ? 'taken' : 'free',
          price: SEAT_PRICES[kind],
        };
      }),
    });
  }
  return { flightId, aircraft: AIRCRAFT, letters: ECONOMY_LETTERS, rows };
}

/** Next free seat for automatic assignment at check-in, window seats first. */
export function pickFreeSeat(cabin: Cabin, taken: Set<string>, avoidRows: number[] = EXIT_ROWS): string | null {
  const order = cabin === 'business' ? ['A', 'F', 'C', 'D'] : ['A', 'F', 'C', 'D', 'B', 'E'];
  const rows = cabin === 'business' ? BUSINESS_ROWS : [...ECONOMY_ROWS].reverse();
  for (const letter of order) {
    for (const row of rows) {
      if (avoidRows.includes(row)) continue;
      const id = `${row}${letter}`;
      if (!taken.has(id)) return id;
    }
  }
  return null;
}
