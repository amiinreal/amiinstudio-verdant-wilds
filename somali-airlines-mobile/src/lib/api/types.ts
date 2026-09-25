import type {
  BoardingPass,
  CheckInDocs,
  DayPrice,
  SearchResult,
} from '@core/service';
import type {
  Booking,
  Cabin,
  CreateBookingInput,
  Flight,
  FlightWithStatus,
  PriceBreakdown,
  SearchQuery,
  SeatMap,
  User,
} from '@core/types';

/** How a customer proves a booking is theirs: reference plus a passenger's last name. */
export type BookingRef = { pnr: string; lastName: string };

export type SignUpInput = {
  email: string;
  password: string;
  firstName: string;
  lastName: string;
  phone: string;
};

export type MobileWallet = 'evc' | 'zaad' | 'sahal' | 'waafi';

export type CardPaymentStart =
  | { kind: 'payment_sheet'; clientSecret: string; amount: number }
  | { kind: 'checkout'; url: string; amount: number }
  | { kind: 'demo'; amount: number };

export interface AirlineApi {
  mode: 'demo' | 'live';

  searchFlights(q: SearchQuery): Promise<SearchResult>;
  datePrices(origin: string, destination: string, date: string, cabin: Cabin): Promise<DayPrice[]>;
  getFlight(id: string): Promise<Flight>;
  seatMap(flightId: string, pnr?: string): Promise<SeatMap>;
  flightStatus(q: { flightNumber?: string; origin?: string; destination?: string; date: string }): Promise<FlightWithStatus[]>;

  quote(input: CreateBookingInput): Promise<PriceBreakdown>;
  createBooking(input: CreateBookingInput): Promise<Booking>;
  getBooking(ref: BookingRef): Promise<Booking>;
  myBookings(): Promise<Booking[]>;
  claimBooking(ref: BookingRef): Promise<Booking>;
  updateSeats(ref: BookingRef, changes: { passengerId: string; segmentIndex: number; seat: string | null }[]): Promise<Booking>;
  updateBags(ref: BookingRef, bags: { passengerId: string; extraBags: number }[]): Promise<Booking>;
  updatePassengerDetails(
    ref: BookingRef,
    details: { passengerId: string; nationality?: string; passportNumber?: string; passportExpiry?: string; specialAssistance?: string | null }[],
  ): Promise<Booking>;
  changeOptions(ref: BookingRef, segmentIndex: number, date: string): Promise<{ flight: Flight; toPay: number }[]>;
  changeFlight(ref: BookingRef, segmentIndex: number, flightId: string): Promise<Booking>;
  refundQuote(ref: BookingRef): Promise<{ refund: number; explanation: string }>;
  cancelBooking(ref: BookingRef): Promise<{ booking: Booking; refund: number; manualRefund?: number }>;
  checkIn(ref: BookingRef, segmentIndex: number, passengerIds: string[], docs: CheckInDocs[]): Promise<Booking>;
  boardingPasses(ref: BookingRef, segmentIndex: number): Promise<BoardingPass[]>;

  holdFare(ref: BookingRef): Promise<Booking>;
  startCardPayment(ref: BookingRef): Promise<CardPaymentStart>;
  /** Sends a payment request to the phone; the booking confirms when the owner approves it. */
  startMobileMoney(ref: BookingRef, wallet: MobileWallet, msisdn: string): Promise<{ requestId: string }>;
  /** Demo only: completes a simulated payment. */
  completeDemoPayment(ref: BookingRef, method: 'card' | 'mobile_money'): Promise<Booking>;

  auth: {
    current(): Promise<User | null>;
    signIn(email: string, password: string): Promise<User>;
    signUp(input: SignUpInput): Promise<User>;
    signOut(): Promise<void>;
    resetPassword(email: string): Promise<void>;
    updateProfile(p: Partial<Pick<User, 'firstName' | 'lastName' | 'phone'>>): Promise<User>;
    onChange(cb: (u: User | null) => void): () => void;
  };
}
