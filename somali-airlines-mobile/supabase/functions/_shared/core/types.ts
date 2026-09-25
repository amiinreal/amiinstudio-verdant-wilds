// Shared domain types. This folder has no dependencies so it runs unchanged in
// the Expo app (demo mode) and in the Supabase Edge Function (Deno).

export type Cabin = 'economy' | 'business';
export type FareFamily = 'saver' | 'classic' | 'flex' | 'business';
export type PassengerType = 'adult' | 'child' | 'infant';
export type TripType = 'oneway' | 'return';

export type Airport = {
  code: string;
  city: string;
  name: string;
  country: string;
  lat: number;
  lon: number;
  /** UTC offset in hours. None of the airports we fly to observe DST. */
  utcOffset: number;
  domestic: boolean;
};

export type FlightStatus =
  | 'scheduled'
  | 'on_time'
  | 'delayed'
  | 'boarding'
  | 'departed'
  | 'landed'
  | 'cancelled';

export type Flight = {
  /** e.g. HH101-2026-10-15 */
  id: string;
  flightNumber: string;
  origin: string;
  destination: string;
  /** Local departure date at the origin, YYYY-MM-DD */
  date: string;
  /** Local times, HH:MM */
  departTime: string;
  arriveTime: string;
  /** 1 when the flight lands the next local day */
  arriveDayOffset: number;
  durationMin: number;
  aircraft: string;
  /** Base adult fare per family in USD; null when the family is not sold */
  fares: Record<FareFamily, number | null>;
  seatsLeft: Record<Cabin, number>;
};

export type FlightOps = {
  status: FlightStatus;
  delayMin: number;
  gate: string | null;
  note: string | null;
};

export type FlightWithStatus = Flight & FlightOps & {
  /** Estimated local departure/arrival after any delay */
  estDepartTime: string;
  estArriveTime: string;
};

export type SearchQuery = {
  origin: string;
  destination: string;
  date: string;
  returnDate?: string | null;
  tripType: TripType;
  adults: number;
  children: number;
  infants: number;
  cabin: Cabin;
};

export type SegmentSelection = {
  flightId: string;
  fare: FareFamily;
};

export type PassengerInput = {
  type: PassengerType;
  title: 'Mr' | 'Ms' | 'Mrs' | 'Miss' | 'Mstr' | '';
  firstName: string;
  lastName: string;
  dateOfBirth: string;
  nationality: string;
  passportNumber: string;
  passportExpiry: string;
  /** Seat per segment, same order as the booking's segments */
  seats: (string | null)[];
  /** Extra 23 kg bags bought on top of the fare allowance, applies to every segment */
  extraBags: number;
  /** Index of the adult this infant travels on the lap of */
  infantOnAdult?: number | null;
};

export type Passenger = PassengerInput & {
  id: string;
  ticketNumber: string | null;
  checkedIn: boolean[];
  specialAssistance: string | null;
};

export type BookingSegment = {
  flight: Flight;
  fare: FareFamily;
  cabin: Cabin;
};

export type PriceLine = { label: string; amount: number };

export type PriceBreakdown = {
  currency: 'USD';
  fare: number;
  taxes: number;
  seats: number;
  bags: number;
  fees: number;
  total: number;
  lines: PriceLine[];
};

export type BookingStatus = 'held' | 'pending_payment' | 'confirmed' | 'cancelled';

export type PaymentMethod = 'card' | 'mobile_money' | 'cash_office' | 'demo';

export type PaymentRecord = {
  id: string;
  method: PaymentMethod;
  provider: string;
  amount: number;
  status: 'pending' | 'succeeded' | 'failed' | 'refunded';
  reference: string | null;
  createdAt: string;
};

export type BookingEvent = {
  at: string;
  text: string;
};

export type Booking = {
  id: string;
  pnr: string;
  status: BookingStatus;
  userId: string | null;
  createdAt: string;
  holdExpiresAt: string | null;
  contact: { email: string; phone: string };
  segments: BookingSegment[];
  passengers: Passenger[];
  price: PriceBreakdown;
  paid: number;
  refunded: number;
  payments: PaymentRecord[];
  history: BookingEvent[];
};

export type CreateBookingInput = {
  segments: SegmentSelection[];
  passengers: PassengerInput[];
  contact: { email: string; phone: string };
  /** true = keep the fare for a while and pay later */
  hold: boolean;
};

export type SeatState = 'free' | 'taken' | 'blocked';

export type Seat = {
  id: string;
  row: number;
  letter: string;
  cabin: Cabin;
  kind: 'standard' | 'front' | 'exit' | 'business';
  state: SeatState;
  price: number;
};

export type SeatMap = {
  flightId: string;
  aircraft: string;
  letters: string[][];
  rows: { row: number; cabin: Cabin; exit: boolean; seats: Seat[] }[];
};

export type User = {
  id: string;
  email: string;
  firstName: string;
  lastName: string;
  phone: string;
  loyaltyNumber: string;
};

export class AirlineError extends Error {
  code: string;
  constructor(code: string, message: string) {
    super(message);
    this.code = code;
  }
}
