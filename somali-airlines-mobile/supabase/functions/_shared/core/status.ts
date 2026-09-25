import { airport } from './airports.ts';
import { addDays, hash, instant, minutesOf, timeOf } from './time.ts';
import type { Flight, FlightOps, FlightWithStatus } from './types.ts';

export const CHECKIN_OPENS_H = 24;
export const CHECKIN_CLOSES_MIN = 60;
export const BOARDING_BEFORE_MIN = 40;
export const GATE_CLOSES_BEFORE_MIN = 20;

export function departureInstant(f: Flight, delayMin = 0): number {
  return instant(f.date, f.departTime, airport(f.origin).utcOffset) + delayMin * 60_000;
}

export function arrivalInstant(f: Flight, delayMin = 0): number {
  return instant(addDays(f.date, f.arriveDayOffset), f.arriveTime, airport(f.destination).utcOffset) + delayMin * 60_000;
}

/** Operational data the demo invents when no operations team is feeding it. */
export function demoOps(f: Flight): FlightOps {
  const h = hash(`ops:${f.id}`);
  const delayed = h % 7 === 0;
  return {
    status: 'scheduled',
    delayMin: delayed ? 20 + (h % 5) * 10 : 0,
    gate: `${1 + (h % 8)}`,
    note: delayed ? 'Late arrival of the incoming aircraft' : null,
  };
}

export function withStatus(f: Flight, ops: Partial<FlightOps> | undefined, now: number): FlightWithStatus {
  const delayMin = ops?.delayMin ?? 0;
  const dep = departureInstant(f, delayMin);
  const arr = arrivalInstant(f, delayMin);
  let status = ops?.status ?? 'scheduled';
  if (status !== 'cancelled') {
    if (now >= arr) status = 'landed';
    else if (now >= dep) status = 'departed';
    else if (now >= dep - BOARDING_BEFORE_MIN * 60_000) status = 'boarding';
    else if (delayMin > 0) status = 'delayed';
    else if (now >= dep - 24 * 3600_000) status = 'on_time';
    else status = 'scheduled';
  }
  return {
    ...f,
    status,
    delayMin,
    gate: ops?.gate ?? null,
    note: ops?.note ?? null,
    estDepartTime: timeOf(minutesOf(f.departTime) + delayMin).time,
    estArriveTime: timeOf(minutesOf(f.arriveTime) + delayMin).time,
  };
}

export const STATUS_LABEL: Record<FlightWithStatus['status'], string> = {
  scheduled: 'Scheduled',
  on_time: 'On time',
  delayed: 'Delayed',
  boarding: 'Boarding',
  departed: 'Departed',
  landed: 'Landed',
  cancelled: 'Cancelled',
};

export type CheckinWindow =
  | { state: 'not_open'; opensAt: number }
  | { state: 'open'; closesAt: number }
  | { state: 'closed' };

export function checkinWindow(f: Flight, now: number, delayMin = 0): CheckinWindow {
  const dep = departureInstant(f, delayMin);
  const opens = dep - CHECKIN_OPENS_H * 3600_000;
  const closes = dep - CHECKIN_CLOSES_MIN * 60_000;
  if (now < opens) return { state: 'not_open', opensAt: opens };
  if (now < closes) return { state: 'open', closesAt: closes };
  return { state: 'closed' };
}
