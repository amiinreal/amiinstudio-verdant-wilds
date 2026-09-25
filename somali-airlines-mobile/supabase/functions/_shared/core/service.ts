import { airport, findAirport, isDomestic } from './airports.ts';
import { FARE_RULES, faresForCabin, priceTrip } from './pricing.ts';
import { flightById, flightsOn, CAPACITY } from './schedule.ts';
import { buildSeatMap, demoTakenSeats, EXIT_ROWS, parseSeat, pickFreeSeat, seatCabin } from './seats.ts';
import {
  BOARDING_BEFORE_MIN,
  GATE_CLOSES_BEFORE_MIN,
  arrivalInstant,
  checkinWindow,
  demoOps,
  departureInstant,
  withStatus,
} from './status.ts';
import { addDays, ageOn, isValidDate, minutesOf, timeOf, todayAt } from './time.ts';
import {
  AirlineError,
  type Booking,
  type BookingSegment,
  type Cabin,
  type CreateBookingInput,
  type Flight,
  type FlightOps,
  type FlightWithStatus,
  type Passenger,
  type PassengerInput,
  type PaymentRecord,
  type PriceBreakdown,
  type SearchQuery,
  type SeatMap,
} from './types.ts';

/** Where bookings live: AsyncStorage in the demo app, Postgres on the server. */
export interface AirlineStore {
  getBookingByPnr(pnr: string): Promise<Booking | null>;
  getBookingById(id: string): Promise<Booking | null>;
  listBookingsForUser(userId: string): Promise<Booking[]>;
  /** Must reject when a seat on the same flight is already held by a live booking. */
  insertBooking(b: Booking): Promise<void>;
  updateBooking(b: Booking): Promise<void>;
  /** Seats held by live bookings (confirmed, or held/pending and not yet expired). */
  takenSeats(flightId: string): Promise<Set<string>>;
  /** Seated passengers per cabin on live bookings, per flight. */
  bookedCounts(flightIds: string[]): Promise<Record<string, Record<Cabin, number>>>;
  flightOps(flightIds: string[]): Promise<Record<string, Partial<FlightOps>>>;
}

export type ServiceConfig = {
  /** Demo mode invents other passengers, delays and gates so the app feels alive. */
  demo: boolean;
  now: () => number;
  randomInt: (maxExclusive: number) => number;
  /** How long an unpaid booking keeps its seats while the customer pays. */
  paymentHoldMinutes: number;
  /** How long "hold and pay later" keeps the fare. */
  fareHoldHours: number;
};

export type FlightOption = Flight & { cheapest: number | null };

export type SearchResult = {
  outbound: FlightOption[];
  inbound: FlightOption[] | null;
};

export type DayPrice = { date: string; cheapest: number | null };

export type BoardingPass = {
  pnr: string;
  passengerName: string;
  passengerType: Passenger['type'];
  flight: FlightWithStatus;
  seat: string;
  cabin: Cabin;
  fareName: string;
  gate: string | null;
  boardingTime: string;
  gateClosesTime: string;
  zone: string;
  sequence: number;
  ticketNumber: string | null;
  barcode: string;
  hasInfant: boolean;
};

export type CheckInDocs = {
  passengerId: string;
  nationality: string;
  passportNumber: string;
  passportExpiry: string;
};

const PNR_ALPHABET = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

export function balanceDue(b: Booking): number {
  return Math.max(0, Math.round((b.price.total - b.paid) * 100) / 100);
}

export function seatedPassengers(b: Pick<Booking, 'passengers'> | { passengers: PassengerInput[] }): number {
  return b.passengers.filter((p) => p.type !== 'infant').length;
}

export function isInternational(b: Booking): boolean {
  return b.segments.some((s) => !isDomestic(s.flight.origin, s.flight.destination));
}

function normalizeName(s: string): string {
  return s
    .normalize('NFD')
    .replace(/[̀-ͯ]/g, '')
    .replace(/[^a-zA-Z]/g, '')
    .toUpperCase();
}

function err(code: string, message: string): never {
  throw new AirlineError(code, message);
}

export class AirlineService {
  private store: AirlineStore;
  private config: ServiceConfig;

  constructor(store: AirlineStore, config: ServiceConfig) {
    this.store = store;
    this.config = config;
  }

  // ---------- Flights ----------

  private async decorate(flights: Flight[]): Promise<Flight[]> {
    if (flights.length === 0) return flights;
    const counts = await this.store.bookedCounts(flights.map((f) => f.id));
    return flights.map((f) => {
      const booked = counts[f.id] ?? { economy: 0, business: 0 };
      let seatsLeft = {
        economy: CAPACITY.economy - booked.economy,
        business: CAPACITY.business - booked.business,
      };
      if (this.config.demo) {
        const demo = demoTakenSeats(f.id);
        let e = 0;
        let bz = 0;
        demo.forEach((s) => (seatCabin(s) === 'business' ? bz++ : e++));
        seatsLeft = { economy: Math.max(0, seatsLeft.economy - e), business: Math.max(0, seatsLeft.business - bz) };
      }
      return { ...f, seatsLeft };
    });
  }

  private departed(f: Flight, minutesBefore = 0): boolean {
    return this.config.now() >= departureInstant(f) - minutesBefore * 60_000;
  }

  async getFlight(id: string): Promise<Flight> {
    const f = flightById(id);
    if (!f) err('flight_not_found', 'We could not find that flight.');
    const [d] = await this.decorate([f]);
    return d;
  }

  async searchFlights(q: SearchQuery): Promise<SearchResult> {
    this.validateSearch(q);
    const seated = q.adults + q.children;
    const options = async (o: string, d: string, date: string) => {
      const flights = await this.decorate(flightsOn(o, d, date));
      return flights
        // Stop selling 2 hours before departure.
        .filter((f) => !this.departed(f, 120))
        .map((f) => {
          const sellable = f.seatsLeft[q.cabin] >= seated;
          const prices = faresForCabin(q.cabin)
            .map((fam) => f.fares[fam])
            .filter((p): p is number => p != null);
          return { ...f, cheapest: sellable && prices.length ? Math.min(...prices) : null };
        });
    };
    const outbound = await options(q.origin, q.destination, q.date);
    const inbound =
      q.tripType === 'return' && q.returnDate
        ? await options(q.destination, q.origin, q.returnDate)
        : null;
    return { outbound, inbound };
  }

  /** Cheapest fare per day around a date, for the date strip above results. */
  async datePrices(origin: string, destination: string, center: string, cabin: Cabin, span = 3): Promise<DayPrice[]> {
    const out: DayPrice[] = [];
    const today = todayAt(airport(origin).utcOffset, this.config.now());
    for (let i = -span; i <= span; i++) {
      const date = addDays(center, i);
      if (date < today) {
        out.push({ date, cheapest: null });
        continue;
      }
      const flights = flightsOn(origin, destination, date).filter((f) => !this.departed(f, 120));
      const prices = flights.flatMap((f) =>
        faresForCabin(cabin).map((fam) => f.fares[fam]).filter((p): p is number => p != null),
      );
      out.push({ date, cheapest: prices.length ? Math.min(...prices) : null });
    }
    return out;
  }

  private validateSearch(q: SearchQuery) {
    if (!findAirport(q.origin) || !findAirport(q.destination)) err('bad_airport', 'Choose where you are flying from and to.');
    if (q.origin === q.destination) err('same_airport', 'Choose two different cities.');
    if (!isValidDate(q.date)) err('bad_date', 'Choose a departure date.');
    if (q.tripType === 'return') {
      if (!q.returnDate || !isValidDate(q.returnDate)) err('bad_date', 'Choose a return date.');
      if (q.returnDate < q.date) err('bad_date', 'The return date is before the departure date.');
    }
    if (q.adults < 1) err('pax', 'At least one adult must travel.');
    if (q.infants > q.adults) err('pax', 'Each infant needs an adult to sit with.');
    if (q.adults + q.children > 9) err('pax', 'You can book up to 9 seats at once.');
  }

  async flightStatus(opts: { flightNumber?: string; origin?: string; destination?: string; date: string }): Promise<FlightWithStatus[]> {
    let flights: Flight[] = [];
    if (opts.flightNumber) {
      const n = Number(opts.flightNumber.replace(/\D/g, ''));
      const f = flightById(`HH${n}-${opts.date}`);
      flights = f ? [f] : [];
    } else if (opts.origin && opts.destination) {
      flights = flightsOn(opts.origin, opts.destination, opts.date);
    }
    return this.withOps(flights);
  }

  private async withOps(flights: Flight[]): Promise<FlightWithStatus[]> {
    const ops = flights.length ? await this.store.flightOps(flights.map((f) => f.id)) : {};
    const now = this.config.now();
    return flights.map((f) => {
      const base = this.config.demo ? demoOps(f) : undefined;
      return withStatus(f, { ...base, ...ops[f.id] }, now);
    });
  }

  async seatMap(flightId: string, forPnr?: string): Promise<SeatMap> {
    const f = flightById(flightId);
    if (!f) err('flight_not_found', 'We could not find that flight.');
    const taken = await this.store.takenSeats(flightId);
    if (this.config.demo) demoTakenSeats(flightId).forEach((s) => taken.add(s));
    // A passenger's own seats show as free so they can keep or swap them.
    if (forPnr) {
      const b = await this.store.getBookingByPnr(forPnr);
      b?.segments.forEach((s, i) => {
        if (s.flight.id === flightId) b.passengers.forEach((p) => p.seats[i] && taken.delete(p.seats[i]!));
      });
    }
    return buildSeatMap(flightId, taken);
  }

  // ---------- Booking ----------

  private async resolveSegments(input: CreateBookingInput): Promise<BookingSegment[]> {
    if (input.segments.length < 1 || input.segments.length > 2) err('segments', 'Choose one or two flights.');
    const segments: BookingSegment[] = [];
    for (const sel of input.segments) {
      const flight = await this.getFlight(sel.flightId);
      if (this.departed(flight, 120)) err('too_late', `${flight.flightNumber} is no longer on sale.`);
      if (!(sel.fare in FARE_RULES) || flight.fares[sel.fare] == null) err('fare', 'That fare is not available.');
      segments.push({ flight, fare: sel.fare, cabin: FARE_RULES[sel.fare].cabin });
    }
    if (segments.length === 2) {
      const [a, b] = segments;
      if (a.flight.origin !== b.flight.destination || a.flight.destination !== b.flight.origin) {
        err('segments', 'The return flight must fly back on the same route.');
      }
      if (departureInstant(b.flight) < arrivalInstant(a.flight) + 60 * 60_000) {
        err('segments', 'The return flight leaves before the outbound one lands.');
      }
    }
    return segments;
  }

  private validatePassengers(passengers: PassengerInput[], segments: BookingSegment[], requireAll = true) {
    const adults = passengers.filter((p) => p.type === 'adult').length;
    const infants = passengers.filter((p) => p.type === 'infant').length;
    if (adults < 1) err('pax', 'At least one adult must travel.');
    if (infants > adults) err('pax', 'Each infant needs an adult to sit with.');
    if (passengers.length - infants > 9) err('pax', 'You can book up to 9 seats at once.');
    const firstDate = segments[0].flight.date;
    const lastDate = segments[segments.length - 1].flight.date;
    passengers.forEach((p, i) => {
      const who = `Passenger ${i + 1}`;
      if (!normalizeName(p.firstName) || !normalizeName(p.lastName)) err('pax_name', `${who}: enter the first and last name as in the passport.`);
      if (requireAll || p.dateOfBirth) {
        if (!isValidDate(p.dateOfBirth)) err('pax_dob', `${who}: enter a date of birth.`);
        const age = ageOn(p.dateOfBirth, firstDate);
        const ageEnd = ageOn(p.dateOfBirth, lastDate);
        if (age < 0) err('pax_dob', `${who}: check the date of birth.`);
        if (p.type === 'adult' && age < 12) err('pax_dob', `${who} is under 12 on the travel date, so books as a child.`);
        if (p.type === 'child' && (age < 2 || age >= 12)) err('pax_dob', `${who}: children are 2 to 11 years old on the travel date.`);
        if (p.type === 'infant' && ageEnd >= 2) err('pax_dob', `${who}: infants are under 2 for the whole trip. Book a child seat instead.`);
      }
      if (p.seats.length !== segments.length) p.seats = segments.map((_, si) => p.seats[si] ?? null);
      if (p.type === 'infant') p.seats = segments.map(() => null);
      if (!Number.isInteger(p.extraBags) || p.extraBags < 0 || p.extraBags > 3) err('bags', `${who}: up to 3 extra bags.`);
      if (p.type === 'infant') p.extraBags = 0;
    });
  }

  private async validateSeats(passengers: PassengerInput[], segments: BookingSegment[], ownPnr?: string) {
    for (let si = 0; si < segments.length; si++) {
      const seg = segments[si];
      const chosen = passengers.map((p) => p.seats[si]).filter((s): s is string => !!s);
      if (new Set(chosen).size !== chosen.length) err('seat', 'Two passengers picked the same seat.');
      for (const p of passengers) {
        const s = p.seats[si];
        if (s && p.type === 'child' && EXIT_ROWS.includes(parseSeat(s)?.row ?? 0)) {
          err('seat', `Children cannot sit in exit rows. Pick another seat than ${s}.`);
        }
      }
      if (chosen.length === 0) continue;
      const map = await this.seatMap(seg.flight.id, ownPnr);
      const free = new Set(map.rows.flatMap((r) => r.seats.filter((s) => s.state === 'free').map((s) => s.id)));
      for (const s of chosen) {
        if (seatCabin(s) !== seg.cabin) err('seat', `Seat ${s} is not in the ${seg.cabin} cabin.`);
        if (!free.has(s)) err('seat_taken', `Seat ${s} on ${seg.flight.flightNumber} was just taken. Pick another.`);
      }
    }
  }

  private async checkInventory(segments: BookingSegment[], seated: number) {
    for (const seg of segments) {
      const f = await this.getFlight(seg.flight.id);
      if (f.seatsLeft[seg.cabin] < seated) err('sold_out', `${f.flightNumber} has only ${f.seatsLeft[seg.cabin]} seats left in ${seg.cabin}.`);
    }
  }

  async quote(input: CreateBookingInput): Promise<PriceBreakdown> {
    const segments = await this.resolveSegments(input);
    const passengers = input.passengers.map((p) => ({ ...p, seats: [...p.seats] }));
    this.validatePassengers(passengers, segments, false);
    return priceTrip(segments, passengers);
  }

  private newPnr(): string {
    let s = '';
    for (let i = 0; i < 6; i++) s += PNR_ALPHABET[this.config.randomInt(PNR_ALPHABET.length)];
    return s;
  }

  private newId(): string {
    const hex = '0123456789abcdef';
    let s = '';
    for (let i = 0; i < 32; i++) s += hex[this.config.randomInt(16)];
    return `${s.slice(0, 8)}-${s.slice(8, 12)}-4${s.slice(13, 16)}-a${s.slice(17, 20)}-${s.slice(20)}`;
  }

  private ticketNumber(): string {
    let s = '999';
    for (let i = 0; i < 10; i++) s += this.config.randomInt(10);
    return s;
  }

  private nowIso(): string {
    return new Date(this.config.now()).toISOString();
  }

  async createBooking(input: CreateBookingInput, userId: string | null): Promise<Booking> {
    const segments = await this.resolveSegments(input);
    const passengers = input.passengers.map((p) => ({
      ...p,
      firstName: p.firstName.trim(),
      lastName: p.lastName.trim(),
      seats: [...p.seats],
    }));
    this.validatePassengers(passengers, segments);
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(input.contact.email.trim())) err('contact', 'Enter an email address for your tickets.');
    if (input.contact.phone.replace(/\D/g, '').length < 7) err('contact', 'Enter a phone number we can reach you on.');
    await this.checkInventory(segments, seatedPassengers({ passengers }));
    await this.validateSeats(passengers, segments);

    const now = this.config.now();
    const firstDep = departureInstant(segments[0].flight);
    const holdMs = input.hold
      ? Math.min(this.config.fareHoldHours * 3600_000, firstDep - 24 * 3600_000 - now)
      : this.config.paymentHoldMinutes * 60_000;
    if (input.hold && holdMs < 3600_000) err('hold', 'Holding a fare is only possible more than 25 hours before departure.');

    let pnr = this.newPnr();
    for (let i = 0; i < 5 && (await this.store.getBookingByPnr(pnr)); i++) pnr = this.newPnr();

    const booking: Booking = {
      id: this.newId(),
      pnr,
      status: input.hold ? 'held' : 'pending_payment',
      userId,
      createdAt: this.nowIso(),
      holdExpiresAt: new Date(now + holdMs).toISOString(),
      contact: { email: input.contact.email.trim(), phone: input.contact.phone.trim() },
      segments,
      passengers: passengers.map((p) => ({
        ...p,
        id: this.newId(),
        ticketNumber: null,
        checkedIn: segments.map(() => false),
        specialAssistance: null,
      })),
      price: priceTrip(segments, passengers),
      paid: 0,
      refunded: 0,
      payments: [],
      history: [{ at: this.nowIso(), text: input.hold ? 'Fare held' : 'Booking created' }],
    };
    await this.store.insertBooking(booking);
    return booking;
  }

  /** Bookings whose payment window passed release their seats. */
  private async expireIfNeeded(b: Booking): Promise<Booking> {
    if ((b.status === 'held' || b.status === 'pending_payment') && b.holdExpiresAt && Date.parse(b.holdExpiresAt) < this.config.now()) {
      b.status = 'cancelled';
      b.history.push({ at: this.nowIso(), text: 'Released because it was not paid in time' });
      await this.store.updateBooking(b);
    }
    return b;
  }

  /** Find a booking the way airlines do: reference plus a passenger's last name, or the owner's account. */
  async getBooking(pnr: string, lastName: string | null, userId: string | null = null): Promise<Booking> {
    const b = await this.store.getBookingByPnr(pnr.trim().toUpperCase());
    const ok =
      b &&
      ((userId && b.userId === userId) ||
        (lastName && b.passengers.some((p) => normalizeName(p.lastName) === normalizeName(lastName))));
    if (!b || !ok) err('booking_not_found', 'We could not find a booking with that reference and last name.');
    return this.expireIfNeeded(b);
  }

  async myBookings(userId: string): Promise<Booking[]> {
    const list = await this.store.listBookingsForUser(userId);
    const out: Booking[] = [];
    for (const b of list) out.push(await this.expireIfNeeded(b));
    return out.sort((a, b) => a.segments[0].flight.date.localeCompare(b.segments[0].flight.date));
  }

  async claimBooking(pnr: string, lastName: string, userId: string): Promise<Booking> {
    const b = await this.getBooking(pnr, lastName);
    if (b.userId && b.userId !== userId) err('claimed', 'This booking is already saved to another account.');
    b.userId = userId;
    b.history.push({ at: this.nowIso(), text: 'Added to account' });
    await this.store.updateBooking(b);
    return b;
  }

  private assertEditable(b: Booking) {
    if (b.status === 'cancelled') err('cancelled', 'This booking is cancelled.');
    if (b.segments.every((s) => this.departed(s.flight))) err('flown', 'This trip has already flown.');
  }

  private reprice(b: Booking) {
    const fresh = priceTrip(b.segments, b.passengers);
    const fees = b.price.fees;
    const lines = [
      ...fresh.lines,
      ...b.price.lines.filter((l) => l.label.startsWith('Change fee') || l.label.startsWith('Fare difference')),
    ];
    // Once money is paid, a cheaper new price never lowers the total.
    const before = b.price.total - fees;
    const keep = b.paid > 0 ? Math.max(0, Math.round((before - fresh.total) * 100) / 100) : 0;
    if (keep > 0) lines.push({ label: 'Fare difference, not refunded', amount: keep });
    b.price = { ...fresh, fees: fees + keep, total: Math.round((fresh.total + fees + keep) * 100) / 100, lines };
  }

  private settle(b: Booking) {
    if (b.status === 'confirmed' && balanceDue(b) > 0) {
      b.history.push({ at: this.nowIso(), text: `Balance to pay: USD ${balanceDue(b)}` });
    }
  }

  async updateSeats(
    pnr: string, lastName: string | null, userId: string | null,
    changes: { passengerId: string; segmentIndex: number; seat: string | null }[],
  ): Promise<Booking> {
    const b = await this.getBooking(pnr, lastName, userId);
    this.assertEditable(b);
    for (const c of changes) {
      const p = b.passengers.find((x) => x.id === c.passengerId);
      if (!p || p.type === 'infant') err('pax', 'Seats are for passengers with their own seat.');
      const seg = b.segments[c.segmentIndex];
      if (!seg) err('segment', 'Unknown flight.');
      if (p.checkedIn[c.segmentIndex]) err('checked_in', 'Seats cannot change after check-in. Ask at the gate.');
      if (this.departed(seg.flight, 60)) err('too_late', 'Seat changes close an hour before departure.');
      p.seats[c.segmentIndex] = c.seat;
    }
    await this.validateSeats(b.passengers, b.segments, b.pnr);
    this.reprice(b);
    b.history.push({ at: this.nowIso(), text: 'Seats updated' });
    this.settle(b);
    await this.store.updateBooking(b);
    return b;
  }

  async updateBags(pnr: string, lastName: string | null, userId: string | null, bags: { passengerId: string; extraBags: number }[]): Promise<Booking> {
    const b = await this.getBooking(pnr, lastName, userId);
    this.assertEditable(b);
    for (const x of bags) {
      const p = b.passengers.find((q) => q.id === x.passengerId);
      if (!p || p.type === 'infant') err('pax', 'Infants travel with the adult’s allowance.');
      if (!Number.isInteger(x.extraBags) || x.extraBags < 0 || x.extraBags > 3) err('bags', 'Up to 3 extra bags per passenger.');
      if (x.extraBags < p.extraBags && b.paid > 0) err('bags', 'Bags you paid for cannot be removed online.');
      p.extraBags = x.extraBags;
    }
    this.reprice(b);
    b.history.push({ at: this.nowIso(), text: 'Bags updated' });
    this.settle(b);
    await this.store.updateBooking(b);
    return b;
  }

  async updatePassengerDetails(
    pnr: string, lastName: string | null, userId: string | null,
    details: { passengerId: string; nationality?: string; passportNumber?: string; passportExpiry?: string; specialAssistance?: string | null }[],
  ): Promise<Booking> {
    const b = await this.getBooking(pnr, lastName, userId);
    this.assertEditable(b);
    for (const d of details) {
      const p = b.passengers.find((q) => q.id === d.passengerId);
      if (!p) err('pax', 'Unknown passenger.');
      if (d.nationality !== undefined) p.nationality = d.nationality.trim();
      if (d.passportNumber !== undefined) p.passportNumber = d.passportNumber.trim().toUpperCase();
      if (d.passportExpiry !== undefined) {
        if (d.passportExpiry && !isValidDate(d.passportExpiry)) err('passport', 'Enter the passport expiry date.');
        p.passportExpiry = d.passportExpiry;
      }
      if (d.specialAssistance !== undefined) p.specialAssistance = d.specialAssistance;
    }
    b.history.push({ at: this.nowIso(), text: 'Passenger details updated' });
    await this.store.updateBooking(b);
    return b;
  }

  /** Other flights the customer can move a segment to, with the price to pay. */
  async changeOptions(pnr: string, lastName: string | null, userId: string | null, segmentIndex: number, date: string) {
    const b = await this.getBooking(pnr, lastName, userId);
    this.assertEditable(b);
    const seg = b.segments[segmentIndex];
    if (!seg) err('segment', 'Unknown flight.');
    const rules = FARE_RULES[seg.fare];
    if (rules.changeFee === null) err('no_change', 'This fare cannot be changed.');
    const flights = await this.decorate(flightsOn(seg.flight.origin, seg.flight.destination, date));
    const seated = seatedPassengers(b);
    const out = [];
    for (const f of flights) {
      if (f.id === seg.flight.id || this.departed(f, 120)) continue;
      if (f.seatsLeft[seg.cabin] < seated || f.fares[seg.fare] == null) continue;
      const trial: Booking = JSON.parse(JSON.stringify(b));
      trial.segments[segmentIndex] = { ...seg, flight: f };
      trial.passengers.forEach((p) => (p.seats[segmentIndex] = null));
      if (!this.segmentOrderOk(trial.segments)) continue;
      this.applyChangeFee(trial, rules.changeFee);
      this.reprice(trial);
      out.push({ flight: f, toPay: Math.max(0, Math.round((trial.price.total - b.price.total) * 100) / 100) });
    }
    return out;
  }

  private segmentOrderOk(segments: BookingSegment[]): boolean {
    if (segments.length < 2) return true;
    return departureInstant(segments[1].flight) >= arrivalInstant(segments[0].flight) + 60 * 60_000;
  }

  private applyChangeFee(b: Booking, fee: number) {
    if (fee <= 0) return;
    const amount = fee * seatedPassengers(b);
    b.price.fees += amount;
    b.price.total += amount;
    b.price.lines.push({ label: `Change fee, ${seatedPassengers(b)} × USD ${fee}`, amount });
  }

  async changeFlight(pnr: string, lastName: string | null, userId: string | null, segmentIndex: number, newFlightId: string): Promise<Booking> {
    const b = await this.getBooking(pnr, lastName, userId);
    this.assertEditable(b);
    const seg = b.segments[segmentIndex];
    if (!seg) err('segment', 'Unknown flight.');
    if (this.departed(seg.flight, 120)) err('too_late', 'Changes close 2 hours before departure.');
    if (b.passengers.some((p) => p.checkedIn[segmentIndex])) err('checked_in', 'This flight is checked in. Call us to change it.');
    const rules = FARE_RULES[seg.fare];
    if (rules.changeFee === null) err('no_change', 'This fare cannot be changed.');
    const f = await this.getFlight(newFlightId);
    if (f.origin !== seg.flight.origin || f.destination !== seg.flight.destination) err('route', 'You can change the date or time, not the route.');
    if (this.departed(f, 120)) err('too_late', 'That flight is no longer on sale.');
    if (f.fares[seg.fare] == null) err('fare', 'Your fare is not sold on that flight.');
    if (f.seatsLeft[seg.cabin] < seatedPassengers(b)) err('sold_out', 'Not enough seats on that flight.');
    const old = seg.flight.flightNumber + ' ' + seg.flight.date;
    b.segments[segmentIndex] = { ...seg, flight: f };
    if (!this.segmentOrderOk(b.segments)) err('segments', 'The return flight would leave before the outbound one lands.');
    b.passengers.forEach((p) => (p.seats[segmentIndex] = null));
    this.applyChangeFee(b, rules.changeFee);
    this.reprice(b);
    b.history.push({ at: this.nowIso(), text: `Changed ${old} to ${f.flightNumber} ${f.date}` });
    this.settle(b);
    await this.store.updateBooking(b);
    return b;
  }

  /** What the customer gets back if they cancel now. */
  refundQuote(b: Booking): { refund: number; explanation: string } {
    if (b.status !== 'confirmed' || b.paid <= 0) return { refund: 0, explanation: 'Nothing has been paid on this booking.' };
    const unflown = b.segments.filter((s) => !this.departed(s.flight));
    if (unflown.length < b.segments.length) return { refund: 0, explanation: 'Part of this trip has flown. Call us to cancel the rest.' };
    const paid = b.paid - b.refunded;
    if (b.segments.every((s) => FARE_RULES[s.fare].cancelFee === 0)) return { refund: paid, explanation: 'Your fare is fully refundable.' };
    if (b.segments.some((s) => FARE_RULES[s.fare].cancelFee === null)) {
      return { refund: Math.min(paid, b.price.taxes), explanation: 'Saver fares are not refundable. You get the taxes back.' };
    }
    const fee = b.segments.reduce((sum, s) => sum + (FARE_RULES[s.fare].cancelFee ?? 0), 0) * seatedPassengers(b);
    return {
      refund: Math.max(Math.min(paid, b.price.taxes), Math.round((paid - fee) * 100) / 100),
      explanation: `A cancellation fee of USD ${fee} applies.`,
    };
  }

  async cancelBooking(pnr: string, lastName: string | null, userId: string | null): Promise<{ booking: Booking; refund: number }> {
    const b = await this.getBooking(pnr, lastName, userId);
    if (b.status === 'cancelled') err('cancelled', 'This booking is already cancelled.');
    if (b.passengers.some((p) => p.checkedIn.some(Boolean))) err('checked_in', 'Checked-in bookings can only be cancelled by phone.');
    const { refund } = this.refundQuote(b);
    b.status = 'cancelled';
    b.history.push({ at: this.nowIso(), text: refund > 0 ? `Cancelled. USD ${refund} to be refunded` : 'Cancelled' });
    await this.store.updateBooking(b);
    return { booking: b, refund };
  }

  /** Turns a booking waiting for payment into a longer fare hold ("hold and pay later"). */
  async holdFare(pnr: string, lastName: string | null, userId: string | null): Promise<Booking> {
    const b = await this.getBooking(pnr, lastName, userId);
    if (b.status === 'held') return b;
    if (b.status !== 'pending_payment') err('hold', 'Only unpaid bookings can be held.');
    const now = this.config.now();
    const ms = Math.min(this.config.fareHoldHours * 3600_000, departureInstant(b.segments[0].flight) - 24 * 3600_000 - now);
    if (ms < 3600_000) err('hold', 'Holding a fare is only possible more than 25 hours before departure.');
    b.status = 'held';
    b.holdExpiresAt = new Date(now + ms).toISOString();
    b.history.push({ at: this.nowIso(), text: 'Fare held, pay later' });
    await this.store.updateBooking(b);
    return b;
  }

  /** Called when money arrives (Stripe webhook, mobile money callback, sales office, demo). */
  async recordPayment(bookingId: string, payment: Omit<PaymentRecord, 'id' | 'createdAt'>): Promise<Booking> {
    const b = await this.store.getBookingById(bookingId);
    if (!b) err('booking_not_found', 'Unknown booking.');
    if (payment.reference && b.payments.some((p) => p.reference === payment.reference && p.status === 'succeeded')) return b;
    b.payments.push({ ...payment, id: this.newId(), createdAt: this.nowIso() });
    if (payment.status !== 'succeeded') {
      await this.store.updateBooking(b);
      return b;
    }
    b.paid = Math.round((b.paid + payment.amount) * 100) / 100;
    if (b.status === 'cancelled') {
      // Money arrived after the hold ran out: keep it on record so staff can refund or rebook.
      b.history.push({ at: this.nowIso(), text: `Payment of USD ${payment.amount} received after the booking was released` });
    } else if (balanceDue(b) === 0) {
      if (b.status !== 'confirmed') b.history.push({ at: this.nowIso(), text: 'Paid and ticketed' });
      else b.history.push({ at: this.nowIso(), text: `Paid USD ${payment.amount}` });
      b.status = 'confirmed';
      b.holdExpiresAt = null;
      b.passengers.forEach((p) => (p.ticketNumber ??= this.ticketNumber()));
    } else {
      b.history.push({ at: this.nowIso(), text: `Part payment of USD ${payment.amount}` });
    }
    await this.store.updateBooking(b);
    return b;
  }

  async recordRefund(bookingId: string, amount: number, reference: string | null): Promise<Booking> {
    const b = await this.store.getBookingById(bookingId);
    if (!b) err('booking_not_found', 'Unknown booking.');
    b.refunded = Math.round((b.refunded + amount) * 100) / 100;
    b.payments.push({ id: this.newId(), method: 'card', provider: 'refund', amount: -amount, status: 'refunded', reference, createdAt: this.nowIso() });
    b.history.push({ at: this.nowIso(), text: `Refunded USD ${amount}` });
    await this.store.updateBooking(b);
    return b;
  }

  // ---------- Check-in ----------

  async checkIn(
    pnr: string, lastName: string | null, userId: string | null,
    segmentIndex: number, passengerIds: string[], docs: CheckInDocs[],
  ): Promise<Booking> {
    const b = await this.getBooking(pnr, lastName, userId);
    if (b.status !== 'confirmed') err('not_paid', 'Pay for the booking before you check in.');
    if (balanceDue(b) > 0) err('not_paid', `Pay the balance of USD ${balanceDue(b)} before you check in.`);
    const seg = b.segments[segmentIndex];
    if (!seg) err('segment', 'Unknown flight.');
    const [status] = await this.withOps([seg.flight]);
    if (status.status === 'cancelled') err('cancelled', 'This flight is cancelled. We will contact you.');
    const win = checkinWindow(seg.flight, this.config.now(), status.delayMin);
    if (win.state === 'not_open') err('not_open', 'Online check-in opens 24 hours before departure.');
    if (win.state === 'closed') err('closed', 'Online check-in has closed. Go to the airport desk.');
    if (passengerIds.length === 0) err('pax', 'Choose who is checking in.');

    const international = !isDomestic(seg.flight.origin, seg.flight.destination);
    const arrival = arrivalInstant(seg.flight);
    for (const d of docs) {
      const p = b.passengers.find((x) => x.id === d.passengerId);
      if (!p) continue;
      p.nationality = d.nationality.trim() || p.nationality;
      p.passportNumber = d.passportNumber.trim().toUpperCase() || p.passportNumber;
      p.passportExpiry = d.passportExpiry || p.passportExpiry;
    }
    const taken = await this.store.takenSeats(seg.flight.id);
    if (this.config.demo) demoTakenSeats(seg.flight.id).forEach((s) => taken.add(s));
    b.passengers.forEach((p) => {
      const s = p.seats[segmentIndex];
      if (s) taken.add(s);
    });

    for (const id of passengerIds) {
      const p = b.passengers.find((x) => x.id === id);
      if (!p) err('pax', 'Unknown passenger.');
      const name = `${p.firstName} ${p.lastName}`;
      if (international) {
        if (!p.passportNumber || !p.passportExpiry) err('passport', `${name}: add passport details to check in for an international flight.`);
        const sixMonths = arrival + 182 * 86400_000;
        if (Date.parse(`${p.passportExpiry}T00:00:00Z`) < sixMonths) err('passport', `${name}: the passport must be valid for 6 months after you arrive.`);
      } else if (!p.passportNumber && !p.nationality) {
        err('passport', `${name}: add a passport or national ID number.`);
      }
      if (p.type === 'infant') {
        const carrier = b.passengers.find((x) => x.type === 'adult' && passengerIds.includes(x.id));
        if (!carrier) err('infant', 'Infants check in with the adult they travel with.');
      } else if (!p.seats[segmentIndex]) {
        const seat = pickFreeSeat(seg.cabin, taken);
        if (!seat) err('full', 'There is no free seat left. Go to the airport desk.');
        p.seats[segmentIndex] = seat;
        taken.add(seat);
      }
      p.checkedIn[segmentIndex] = true;
    }
    b.history.push({ at: this.nowIso(), text: `Checked in for ${seg.flight.flightNumber}` });
    await this.store.updateBooking(b);
    return b;
  }

  async boardingPasses(pnr: string, lastName: string | null, userId: string | null, segmentIndex: number): Promise<BoardingPass[]> {
    const b = await this.getBooking(pnr, lastName, userId);
    const seg = b.segments[segmentIndex];
    if (!seg) err('segment', 'Unknown flight.');
    const [flight] = await this.withOps([seg.flight]);
    const depMin = minutesOf(flight.departTime) + flight.delayMin;
    const rules = FARE_RULES[seg.fare];
    const infants = b.passengers.filter((p) => p.type === 'infant' && p.checkedIn[segmentIndex]);
    let infantIndex = 0;
    return b.passengers
      .filter((p) => p.type !== 'infant' && p.checkedIn[segmentIndex] && p.seats[segmentIndex])
      .map((p, i) => {
        const hasInfant = p.type === 'adult' && infantIndex < infants.length ? (infantIndex++, true) : false;
        const seat = p.seats[segmentIndex]!;
        const seq = (Number(seat.replace(/\D/g, '')) * 7 + i * 3) % 180 + 1;
        const zone = rules.priorityBoarding ? '1' : Number(seat.replace(/\D/g, '')) >= 16 ? '2' : '3';
        const julian = Math.floor((Date.UTC(+flight.date.slice(0, 4), +flight.date.slice(5, 7) - 1, +flight.date.slice(8, 10)) - Date.UTC(+flight.date.slice(0, 4), 0, 0)) / 86400_000);
        const name = `${normalizeName(p.lastName)}/${normalizeName(p.firstName)}`.slice(0, 20).padEnd(20, ' ');
        const fn = flight.flightNumber.replace(/\D/g, '').padStart(4, '0');
        // IATA BCBP-style string (Resolution 792 mandatory fields).
        const barcode = `M1${name}E${b.pnr.padEnd(7, ' ')}${flight.origin}${flight.destination}HH ${fn} ${String(julian).padStart(3, '0')}${seg.cabin === 'business' ? 'J' : 'Y'}${seat.padStart(4, '0')}${String(seq).padStart(4, '0')} 100`;
        return {
          pnr: b.pnr,
          passengerName: `${p.title ? p.title + ' ' : ''}${p.firstName} ${p.lastName}`,
          passengerType: p.type,
          flight,
          seat,
          cabin: seg.cabin,
          fareName: rules.name,
          gate: flight.gate,
          boardingTime: timeOf(depMin - BOARDING_BEFORE_MIN).time,
          gateClosesTime: timeOf(depMin - GATE_CLOSES_BEFORE_MIN).time,
          zone,
          sequence: seq,
          ticketNumber: p.ticketNumber,
          barcode,
          hasInfant,
        };
      });
  }
}
