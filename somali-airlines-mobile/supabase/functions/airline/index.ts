// The airline API. Every price, seat and payment decision is made here, on
// the server, using the same core the app runs in demo mode.
import { balanceDue } from '../_shared/core/service.ts';
import { AirlineError, type Booking } from '../_shared/core/types.ts';
import { admin, cors, json, service, stripe } from '../_shared/setup.ts';

type Ref = { pnr: string; lastName: string };
// deno-lint-ignore no-explicit-any
type Args = Record<string, any>;

async function userIdFrom(req: Request): Promise<string | null> {
  const token = req.headers.get('Authorization')?.replace(/^Bearer\s+/i, '');
  if (!token) return null;
  const { data } = await admin.auth.getUser(token);
  return data.user?.id ?? null;
}

const refArgs = (ref: Ref, uid: string | null) => [String(ref?.pnr ?? ''), ref?.lastName ? String(ref.lastName) : null, uid] as const;

function requireStripe() {
  if (!stripe) throw new AirlineError('payments_off', 'Card payments are not set up yet. Choose another way to pay.');
  return stripe;
}

async function startCardPayment(ref: Ref, uid: string | null, platform: string, returnUrl: string) {
  const b = await service.getBooking(...refArgs(ref, uid));
  if (b.status === 'cancelled') throw new AirlineError('cancelled', 'This booking is cancelled.');
  const amount = balanceDue(b);
  if (amount <= 0) throw new AirlineError('nothing_due', 'There is nothing to pay on this booking.');
  const s = requireStripe();
  const metadata = { booking_id: b.id, pnr: b.pnr };
  const description = `Somali Airlines booking ${b.pnr}`;
  const cents = Math.round(amount * 100);

  if (platform === 'web') {
    const safeReturn = /^https:\/\//.test(returnUrl) || /^http:\/\/localhost(:\d+)?$/.test(returnUrl) ? returnUrl : null;
    if (!safeReturn) throw new AirlineError('return_url', 'Payments need a secure page to return to.');
    const session = await s.checkout.sessions.create({
      mode: 'payment',
      customer_email: b.contact.email,
      line_items: [{ quantity: 1, price_data: { currency: 'usd', unit_amount: cents, product_data: { name: description } } }],
      payment_intent_data: { metadata, description },
      metadata,
      success_url: `${safeReturn}/booking/${b.pnr}?paid=1`,
      cancel_url: `${safeReturn}/booking/${b.pnr}`,
    });
    return { kind: 'checkout', url: session.url, amount };
  }

  const intent = await s.paymentIntents.create(
    {
      amount: cents,
      currency: 'usd',
      automatic_payment_methods: { enabled: true },
      receipt_email: b.contact.email,
      description,
      metadata,
    },
    // Same booking + same amount within a few minutes reuses the intent.
    { idempotencyKey: `${b.id}:${cents}:${Math.floor(Date.now() / 600_000)}` },
  );
  return { kind: 'payment_sheet', clientSecret: intent.client_secret, amount };
}

async function cancel(ref: Ref, uid: string | null) {
  const { booking, refund } = await service.cancelBooking(...refArgs(ref, uid));
  let result: Booking = booking;
  if (refund > 0) {
    // Refund card payments newest first until the amount is covered.
    let left = Math.round(refund * 100);
    const cardPayments = booking.payments
      .filter((p) => p.provider === 'stripe' && p.status === 'succeeded' && p.reference)
      .reverse();
    for (const p of cardPayments) {
      if (left <= 0) break;
      const amount = Math.min(left, Math.round(p.amount * 100));
      const r = await requireStripe().refunds.create({ payment_intent: p.reference!, amount, metadata: { booking_id: booking.id } });
      result = await service.recordRefund(booking.id, amount / 100, r.id);
      left -= amount;
    }
    // Whatever is left was paid by mobile money or cash; the sales team pays it back by hand.
    return { booking: result, refund, manualRefund: Math.max(0, left) / 100 };
  }
  return { booking: result, refund, manualRefund: 0 };
}

async function handle(action: string, a: Args, uid: string | null) {
  switch (action) {
    case 'searchFlights': return service.searchFlights(a.q);
    case 'datePrices': return service.datePrices(a.origin, a.destination, a.date, a.cabin);
    case 'getFlight': return service.getFlight(a.id);
    case 'seatMap': return service.seatMap(a.flightId, a.pnr);
    case 'flightStatus': return service.flightStatus(a.q);
    case 'quote': return service.quote(a.input);
    case 'createBooking': return service.createBooking(a.input, uid);
    case 'getBooking': return service.getBooking(...refArgs(a.ref, uid));
    case 'myBookings':
      if (!uid) throw new AirlineError('auth', 'Log in to see your trips.');
      return service.myBookings(uid);
    case 'claimBooking':
      if (!uid) throw new AirlineError('auth', 'Log in to save bookings to your account.');
      return service.claimBooking(a.ref.pnr, a.ref.lastName, uid);
    case 'updateSeats': return service.updateSeats(...refArgs(a.ref, uid), a.changes);
    case 'updateBags': return service.updateBags(...refArgs(a.ref, uid), a.bags);
    case 'updatePassengerDetails': return service.updatePassengerDetails(...refArgs(a.ref, uid), a.details);
    case 'changeOptions': return service.changeOptions(...refArgs(a.ref, uid), a.segmentIndex, a.date);
    case 'changeFlight': return service.changeFlight(...refArgs(a.ref, uid), a.segmentIndex, a.flightId);
    case 'refundQuote': return service.refundQuote(await service.getBooking(...refArgs(a.ref, uid)));
    case 'cancelBooking': return cancel(a.ref, uid);
    case 'checkIn': return service.checkIn(...refArgs(a.ref, uid), a.segmentIndex, a.passengerIds, a.docs ?? []);
    case 'boardingPasses': return service.boardingPasses(...refArgs(a.ref, uid), a.segmentIndex);
    case 'holdFare': return service.holdFare(...refArgs(a.ref, uid));
    case 'startCardPayment': return startCardPayment(a.ref, uid, a.platform, a.returnUrl);
    case 'startMobileMoney':
      // EVC Plus, ZAAD, SAHAL and WAAFI need a merchant agreement with the
      // operator (for example through the WAAFI API). Plug it in here.
      throw new AirlineError('mobile_money_off', 'Mobile money is coming soon. Pay by card, or hold the fare and pay at a sales office.');
    default:
      throw new AirlineError('unknown_action', `Unknown action ${action}`);
  }
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: cors });
  if (req.method !== 'POST') return json({ error: { code: 'method', message: 'POST only' } }, 405);
  try {
    const { action, args } = await req.json();
    const uid = await userIdFrom(req);
    return json(await handle(String(action), args ?? {}, uid));
  } catch (e) {
    if (e instanceof AirlineError) return json({ error: { code: e.code, message: e.message } }, 400);
    console.error(e);
    return json({ error: { code: 'server', message: 'Something went wrong on our side. Try again.' } }, 500);
  }
});
