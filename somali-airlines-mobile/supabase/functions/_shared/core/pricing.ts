import { isDomestic } from './airports.ts';
import { seatPrice } from './seats.ts';
import type {
  BookingSegment,
  Cabin,
  FareFamily,
  PassengerInput,
  PassengerType,
  PriceBreakdown,
  PriceLine,
} from './types.ts';

export type FareRules = {
  family: FareFamily;
  name: string;
  cabin: Cabin;
  cabinBag: string;
  checkedBags: number;
  checkedBagKg: number;
  /** Fee to change dates, before any fare difference. null = changes not allowed */
  changeFee: number | null;
  /** Fee kept on cancellation. null = not refundable (taxes are still returned) */
  cancelFee: number | null;
  freeSeat: boolean;
  priorityBoarding: boolean;
  lounge: boolean;
};

// Sample fare rules matching the design's Saver / Classic / Flex cards.
export const FARE_RULES: Record<FareFamily, FareRules> = {
  saver: {
    family: 'saver', name: 'Saver', cabin: 'economy', cabinBag: '7 kg',
    checkedBags: 0, checkedBagKg: 23, changeFee: 50, cancelFee: null,
    freeSeat: false, priorityBoarding: false, lounge: false,
  },
  classic: {
    family: 'classic', name: 'Classic', cabin: 'economy', cabinBag: '7 kg',
    checkedBags: 1, checkedBagKg: 23, changeFee: 0, cancelFee: 75,
    freeSeat: false, priorityBoarding: false, lounge: false,
  },
  flex: {
    family: 'flex', name: 'Flex', cabin: 'economy', cabinBag: '7 kg',
    checkedBags: 2, checkedBagKg: 23, changeFee: 0, cancelFee: 0,
    freeSeat: true, priorityBoarding: true, lounge: false,
  },
  business: {
    family: 'business', name: 'Business', cabin: 'business', cabinBag: '2 × 7 kg',
    checkedBags: 2, checkedBagKg: 32, changeFee: 0, cancelFee: 0,
    freeSeat: true, priorityBoarding: true, lounge: true,
  },
};

export const ECONOMY_FARES: FareFamily[] = ['saver', 'classic', 'flex'];
export const BUSINESS_FARES: FareFamily[] = ['business'];

export function faresForCabin(cabin: Cabin): FareFamily[] {
  return cabin === 'business' ? BUSINESS_FARES : ECONOMY_FARES;
}

export function fareFeatures(family: FareFamily): { ok: boolean; text: string }[] {
  const r = FARE_RULES[family];
  return [
    { ok: true, text: `Cabin bag, ${r.cabinBag}` },
    r.checkedBags > 0
      ? { ok: true, text: `${r.checkedBags} checked bag${r.checkedBags > 1 ? 's' : ''}, ${r.checkedBagKg} kg${r.checkedBags > 1 ? ' each' : ''}` }
      : { ok: false, text: 'No checked bag' },
    r.changeFee === 0
      ? { ok: true, text: 'Change date for free' }
      : { ok: false, text: `Changes for a USD ${r.changeFee} fee` },
    r.cancelFee === 0
      ? { ok: true, text: 'Full refund' }
      : r.cancelFee === null
        ? { ok: false, text: 'Not refundable' }
        : { ok: false, text: `Refund, less USD ${r.cancelFee}` },
    ...(r.freeSeat ? [{ ok: true, text: 'Free seat choice' }] : []),
    ...(r.lounge ? [{ ok: true, text: 'Lounge and priority boarding' }] : []),
  ];
}

export const PAX_FARE_SHARE: Record<PassengerType, number> = { adult: 1, child: 0.75, infant: 0.1 };

export function taxPerPassenger(origin: string, destination: string, type: PassengerType): number {
  if (type === 'infant') return 5;
  return isDomestic(origin, destination) ? 18 : 45;
}

export function extraBagPrice(origin: string, destination: string): number {
  return isDomestic(origin, destination) ? 35 : 60;
}

export const PAX_LABEL: Record<PassengerType, [string, string]> = {
  adult: ['adult', 'adults'],
  child: ['child', 'children'],
  infant: ['infant', 'infants'],
};

export function paxLabel(type: PassengerType, n: number): string {
  return `${n} ${PAX_LABEL[type][n === 1 ? 0 : 1]}`;
}

function round2(n: number): number {
  return Math.round(n * 100) / 100;
}

export function segmentFare(seg: BookingSegment): number {
  const f = seg.flight.fares[seg.fare];
  if (f == null) throw new Error(`Fare ${seg.fare} not sold on ${seg.flight.id}`);
  return f;
}

/** The full price of a trip. Runs on the server for real bookings. */
export function priceTrip(
  segments: BookingSegment[],
  passengers: Pick<PassengerInput, 'type' | 'seats' | 'extraBags'>[],
): PriceBreakdown {
  let fare = 0;
  let taxes = 0;
  let seats = 0;
  let bags = 0;
  segments.forEach((seg, si) => {
    const base = segmentFare(seg);
    const rules = FARE_RULES[seg.fare];
    for (const p of passengers) {
      fare += base * PAX_FARE_SHARE[p.type];
      taxes += taxPerPassenger(seg.flight.origin, seg.flight.destination, p.type);
      const seat = p.seats[si];
      if (seat && p.type !== 'infant' && !rules.freeSeat) seats += seatPrice(seat);
      if (p.type !== 'infant') bags += p.extraBags * extraBagPrice(seg.flight.origin, seg.flight.destination);
    }
  });
  fare = round2(fare);
  const counts = { adult: 0, child: 0, infant: 0 };
  passengers.forEach((p) => counts[p.type]++);
  const who = (['adult', 'child', 'infant'] as PassengerType[])
    .filter((t) => counts[t] > 0)
    .map((t) => paxLabel(t, counts[t]))
    .join(', ');
  const lines: PriceLine[] = [{ label: `Flights, ${who}`, amount: fare }];
  if (seats) lines.push({ label: 'Seat selection', amount: seats });
  if (bags) lines.push({ label: 'Extra bags', amount: bags });
  lines.push({ label: 'Taxes and fees', amount: taxes });
  return {
    currency: 'USD',
    fare,
    taxes,
    seats,
    bags,
    fees: 0,
    total: round2(fare + taxes + seats + bags),
    lines,
  };
}

export function formatUsd(amount: number): string {
  const whole = Number.isInteger(amount);
  return `USD ${amount.toLocaleString('en-US', {
    minimumFractionDigits: whole ? 0 : 2,
    maximumFractionDigits: 2,
  })}`;
}
