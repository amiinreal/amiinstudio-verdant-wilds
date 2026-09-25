import { airport, distanceKm } from './airports.ts';
import { dayOfWeek, hash, minutesOf, timeOf } from './time.ts';
import type { Flight } from './types.ts';

// Sample network for the app. Days: 0 = Sunday ... 6 = Saturday.
// Replace with data from the reservation system when one is connected.
type RouteDef = {
  number: number;
  origin: string;
  destination: string;
  depart: string;
  days: number[];
};

const DAILY = [0, 1, 2, 3, 4, 5, 6];

const OUT_AND_BACK: [number, string, string, string, string, number[]][] = [
  // number, origin, destination, outbound departure, return departure, days
  [101, 'MGQ', 'HGA', '07:40', '10:20', DAILY],
  [103, 'MGQ', 'HGA', '13:10', '15:50', DAILY],
  [105, 'MGQ', 'HGA', '17:45', '20:25', DAILY],
  [111, 'MGQ', 'GGR', '08:30', '11:15', DAILY],
  [121, 'MGQ', 'BSA', '09:15', '12:40', DAILY],
  [131, 'MGQ', 'KMU', '07:00', '08:50', DAILY],
  [141, 'MGQ', 'GLK', '14:00', '16:30', [1, 2, 4, 5, 0]],
  [151, 'MGQ', 'BBO', '11:00', '14:00', [1, 3, 5]],
  [161, 'MGQ', 'BIB', '06:30', '08:00', [2, 4, 6]],
  [301, 'MGQ', 'NBO', '06:15', '11:00', DAILY],
  [311, 'MGQ', 'ADD', '10:00', '14:30', DAILY],
  [321, 'MGQ', 'DXB', '01:30', '08:30', DAILY],
  [331, 'MGQ', 'JED', '15:00', '20:45', [1, 4, 6]],
  [341, 'MGQ', 'IST', '02:00', '12:00', [2, 5, 0]],
  [351, 'MGQ', 'DJI', '12:15', '15:30', [1, 3, 5, 0]],
  [361, 'MGQ', 'EBB', '09:30', '14:15', [2, 4, 6]],
  [401, 'HGA', 'ADD', '08:00', '12:00', DAILY],
  [411, 'HGA', 'DXB', '03:00', '10:30', [3, 6]],
  [421, 'HGA', 'DJI', '13:00', '15:30', [2, 4]],
];

export const ROUTES: RouteDef[] = OUT_AND_BACK.flatMap(([n, o, d, out, back, days]) => [
  { number: n, origin: o, destination: d, depart: out, days },
  { number: n + 1, origin: d, destination: o, depart: back, days },
]);

export const AIRCRAFT = 'Airbus A320';
export const CAPACITY = { economy: 144, business: 12 };

export function blockMinutes(origin: string, destination: string): number {
  const km = distanceKm(airport(origin), airport(destination));
  return Math.round((km / 760) * 60 / 5) * 5 + 25;
}

/** Saver fare before date variation, in USD. Sample pricing for the demo. */
export function baseFare(origin: string, destination: string): number {
  const km = distanceKm(airport(origin), airport(destination));
  return Math.round((55 + km * 0.1) / 5) * 5;
}

export function flightNumber(n: number): string {
  return `HH ${n}`;
}

export function flightId(n: number, date: string): string {
  return `HH${n}-${date}`;
}

export function parseFlightId(id: string): { number: number; date: string } | null {
  const m = /^HH(\d{3})-(\d{4}-\d{2}-\d{2})$/.exec(id);
  return m ? { number: Number(m[1]), date: m[2] } : null;
}

export function routesServing(origin: string, destination: string): RouteDef[] {
  return ROUTES.filter((r) => r.origin === origin && r.destination === destination);
}

export function destinationsFrom(origin: string): string[] {
  return [...new Set(ROUTES.filter((r) => r.origin === origin).map((r) => r.destination))];
}

export function allOrigins(): string[] {
  return [...new Set(ROUTES.map((r) => r.origin))];
}

function buildFlight(route: RouteDef, date: string): Flight {
  const duration = blockMinutes(route.origin, route.destination);
  const tzShift = (airport(route.destination).utcOffset - airport(route.origin).utcOffset) * 60;
  const arrive = timeOf(minutesOf(route.depart) + duration + tzShift);
  const base = baseFare(route.origin, route.destination);
  // Fares move a little by date and by departure, like a simple revenue model.
  const wiggle = 0.9 + (hash(`${route.number}:${date}`) % 36) / 100;
  const weekend = [4, 5].includes(dayOfWeek(date)) ? 1.08 : 1;
  const saver = Math.round((base * wiggle * weekend) / 5) * 5 - 1;
  return {
    id: flightId(route.number, date),
    flightNumber: flightNumber(route.number),
    origin: route.origin,
    destination: route.destination,
    date,
    departTime: route.depart,
    arriveTime: arrive.time,
    arriveDayOffset: arrive.dayOffset,
    durationMin: duration,
    aircraft: AIRCRAFT,
    fares: {
      saver,
      classic: Math.round((saver * 1.3) / 5) * 5 - 1,
      flex: Math.round((saver * 1.75) / 5) * 5 - 1,
      business: Math.round((saver * 3.1) / 5) * 5 - 1,
    },
    seatsLeft: { ...CAPACITY },
  };
}

export function flightsOn(origin: string, destination: string, date: string): Flight[] {
  const dow = dayOfWeek(date);
  return routesServing(origin, destination)
    .filter((r) => r.days.includes(dow))
    .map((r) => buildFlight(r, date))
    .sort((a, b) => a.departTime.localeCompare(b.departTime));
}

export function flightById(id: string): Flight | null {
  const p = parseFlightId(id);
  if (!p) return null;
  const route = ROUTES.find((r) => r.number === p.number);
  if (!route || !route.days.includes(dayOfWeek(p.date))) return null;
  return buildFlight(route, p.date);
}

export function flightsByNumber(n: number, date: string): Flight | null {
  return flightById(flightId(n, date));
}

/** All flights departing any airport on a date, for the departures board. */
export function allFlightsOn(date: string): Flight[] {
  const dow = dayOfWeek(date);
  return ROUTES.filter((r) => r.days.includes(dow))
    .map((r) => buildFlight(r, date))
    .sort((a, b) => a.departTime.localeCompare(b.departTime));
}
