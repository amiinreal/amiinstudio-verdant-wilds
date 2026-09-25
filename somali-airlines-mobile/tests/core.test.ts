// Run with: npm test  (Node's built-in test runner with type stripping)
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { MemoryStore } from '../supabase/functions/_shared/core/memory-store.ts';
import { AirlineService, balanceDue } from '../supabase/functions/_shared/core/service.ts';
import { addDays } from '../supabase/functions/_shared/core/time.ts';
import type { PassengerInput } from '../supabase/functions/_shared/core/types.ts';

const NOW = Date.parse('2026-10-01T09:00:00Z');

function setup(now = NOW, demo = false) {
  let clock = now;
  let seed = 1;
  const store = new MemoryStore(() => clock);
  const service = new AirlineService(store, {
    demo,
    now: () => clock,
    randomInt: (n) => (seed = (seed * 16807) % 2147483647) % n,
    paymentHoldMinutes: 30,
    fareHoldHours: 48,
  });
  return { service, store, setNow: (t: number) => (clock = t) };
}

const adult = (first: string, last: string, extra: Partial<PassengerInput> = {}): PassengerInput => ({
  type: 'adult', title: 'Ms', firstName: first, lastName: last, dateOfBirth: '1990-04-02',
  nationality: 'Somali', passportNumber: '', passportExpiry: '', seats: [null], extraBags: 0, ...extra,
});

test('search finds the design sample flight with three fares', async () => {
  const { service } = setup();
  const r = await service.searchFlights({
    origin: 'MGQ', destination: 'HGA', date: '2026-10-15', returnDate: '2026-10-29', tripType: 'return',
    adults: 2, children: 1, infants: 0, cabin: 'economy',
  });
  assert.equal(r.outbound[0].flightNumber, 'HH 101');
  assert.equal(r.outbound[0].departTime, '07:40');
  assert.equal(r.inbound?.length, 3);
  const f = r.outbound[0].fares;
  assert.ok(f.saver! < f.classic! && f.classic! < f.flex!);
});

test('book, pay, change seats, check in and get a boarding pass', async () => {
  const { service, setNow } = setup();
  const q = await service.searchFlights({
    origin: 'MGQ', destination: 'HGA', date: '2026-10-15', tripType: 'oneway',
    adults: 1, children: 0, infants: 0, cabin: 'economy',
  });
  const b = await service.createBooking({
    segments: [{ flightId: q.outbound[0].id, fare: 'classic' }],
    passengers: [adult('Hodan', 'Warsame', { seats: ['14A'], extraBags: 1 })],
    contact: { email: 'hodan@example.com', phone: '+252 61 555 0142' },
    hold: false,
  }, null);
  assert.equal(b.status, 'pending_payment');
  assert.equal(b.price.seats, 10);
  assert.equal(b.price.bags, 35);

  await assert.rejects(service.getBooking(b.pnr, 'Nobody'));
  const paid = await service.recordPayment(b.id, { method: 'card', provider: 'stripe', amount: b.price.total, status: 'succeeded', reference: 'pi_1' });
  assert.equal(paid.status, 'confirmed');
  assert.ok(paid.passengers[0].ticketNumber);
  // Webhooks can arrive twice.
  const again = await service.recordPayment(b.id, { method: 'card', provider: 'stripe', amount: b.price.total, status: 'succeeded', reference: 'pi_1' });
  assert.equal(again.paid, b.price.total);

  const moved = await service.updateSeats(b.pnr, 'warsame', null, [{ passengerId: b.passengers[0].id, segmentIndex: 0, seat: '12C' }]);
  assert.equal(moved.passengers[0].seats[0], '12C');
  assert.equal(balanceDue(moved), 15);
  await service.recordPayment(b.id, { method: 'card', provider: 'stripe', amount: 15, status: 'succeeded', reference: 'pi_2' });

  await assert.rejects(service.checkIn(b.pnr, 'Warsame', null, 0, [b.passengers[0].id], []), /opens 24 hours/);
  setNow(Date.parse('2026-10-14T12:00:00Z'));
  const ci = await service.checkIn(b.pnr, 'Warsame', null, 0, [b.passengers[0].id], [
    { passengerId: b.passengers[0].id, nationality: 'Somali', passportNumber: 'P1234567', passportExpiry: '2030-01-01' },
  ]);
  assert.equal(ci.passengers[0].checkedIn[0], true);
  const passes = await service.boardingPasses(b.pnr, 'Warsame', null, 0);
  assert.equal(passes.length, 1);
  assert.equal(passes[0].seat, '12C');
  assert.equal(passes[0].boardingTime, '07:00');
  assert.match(passes[0].barcode, /^M1WARSAME\/HODAN/);
});

test('seats cannot be double booked', async () => {
  const { service } = setup();
  const flightId = `HH101-2026-10-15`;
  const mk = () => service.createBooking({
    segments: [{ flightId, fare: 'saver' }],
    passengers: [adult('A', 'B', { seats: ['20A'] })],
    contact: { email: 'a@b.co', phone: '0612345678' }, hold: false,
  }, null);
  await mk();
  await assert.rejects(mk(), /taken/);
});

test('unpaid bookings release seats after the payment window', async () => {
  const { service, setNow } = setup();
  const b = await service.createBooking({
    segments: [{ flightId: 'HH101-2026-10-15', fare: 'saver' }],
    passengers: [adult('A', 'B', { seats: ['20A'] })],
    contact: { email: 'a@b.co', phone: '0612345678' }, hold: false,
  }, null);
  setNow(NOW + 31 * 60_000);
  const map = await service.seatMap('HH101-2026-10-15');
  assert.equal(map.rows.find((r) => r.row === 20)!.seats[0].state, 'free');
  const again = await service.getBooking(b.pnr, 'B');
  assert.equal(again.status, 'cancelled');
});

test('date change on Saver charges the fee, cancellation refunds taxes only', async () => {
  const { service } = setup();
  const b = await service.createBooking({
    segments: [{ flightId: 'HH101-2026-10-15', fare: 'saver' }],
    passengers: [adult('A', 'B')],
    contact: { email: 'a@b.co', phone: '0612345678' }, hold: false,
  }, 'user-1');
  await service.recordPayment(b.id, { method: 'card', provider: 'stripe', amount: b.price.total, status: 'succeeded', reference: 'x' });
  const opts = await service.changeOptions(b.pnr, null, 'user-1', 0, '2026-10-16');
  assert.equal(opts.length, 3);
  const changed = await service.changeFlight(b.pnr, null, 'user-1', 0, opts[1].flight.id);
  assert.equal(changed.segments[0].flight.flightNumber, 'HH 103');
  assert.ok(balanceDue(changed) >= 50);
  const { refund } = await service.cancelBooking(b.pnr, null, 'user-1');
  assert.equal(refund, changed.price.taxes);
});

test('return must be after outbound; infants need adults', async () => {
  const { service } = setup();
  await assert.rejects(service.createBooking({
    segments: [{ flightId: 'HH101-2026-10-15', fare: 'saver' }, { flightId: 'HH102-2026-10-14', fare: 'saver' }],
    passengers: [adult('A', 'B', { seats: [null, null] })],
    contact: { email: 'a@b.co', phone: '0612345678' }, hold: false,
  }, null), /return flight/);
  await assert.rejects(service.createBooking({
    segments: [{ flightId: 'HH101-2026-10-15', fare: 'saver' }],
    passengers: [{ ...adult('Baby', 'B'), type: 'infant', dateOfBirth: addDays('2026-10-15', -200) }],
    contact: { email: 'a@b.co', phone: '0612345678' }, hold: false,
  }, null), /adult/);
});

test('demo mode shows other passengers and flight status', async () => {
  const { service } = setup(NOW, true);
  const map = await service.seatMap('HH101-2026-10-15');
  assert.ok(map.rows.some((r) => r.seats.some((s) => s.state === 'taken')));
  const st = await service.flightStatus({ flightNumber: 'HH101', date: '2026-10-01' });
  assert.equal(st.length, 1);
  assert.ok(st[0].gate);
});
