# Somali Airlines mobile app

An Expo (SDK 57) app for Somali Airlines, built on the brand design canvas
(blue `#1F5FAE`, navy `#0E2A47`, Bricolage Grotesque + IBM Plex Sans, the woven
stripe band and the White Star mark). It runs on iOS, Android and the web.

> Concept app. Not an official Somali Airlines service. Routes, schedules,
> fares and policies are sample data to replace with the airline's own.

## What it does

| Area | Screens |
| --- | --- |
| **Search** | Return / one way, city picker limited to real routes, calendar, travellers (adults, children, infants) and cabin |
| **Book** | 5 steps like the design: flights with a 7-day price strip and Saver / Classic / Flex / Business fares → passengers → seat map → bags → payment |
| **Pay** | Stripe PaymentSheet (cards, Apple Pay, Google Pay) on phones, Stripe Checkout on the web, mobile money (EVC Plus, ZAAD, SAHAL, WAAFI) flow, and *hold and pay later* |
| **Manage booking** | Find by reference + last name, change seats, add bags, change flight (fare rules, change fees, fare difference), passport details and special assistance, cancel with a refund quote, booking history |
| **Check-in** | Opens 24 h before departure, passport checks for international flights (6-month validity), automatic seats, safety declaration |
| **Boarding pass** | Design-matched pass with a real, scannable IATA BCBP QR code, one per passenger, saved for offline use |
| **Flight status** | By route or flight number, yesterday / today / tomorrow, delays and gates |
| **Account** | Sign up, log in, reset password, profile, White Star member number, trips across devices |
| **Travel info** | Baggage, documents and eTAS, check-in times, seats, children, assistance, payments, changes and refunds, route map, our story, contact, legal |

## Run it

```bash
npm install
npm start          # then press i / a / w, or scan the QR code with Expo Go
```

With no `.env`, the app runs in **demo mode**: the same airline engine runs on
the phone, bookings and accounts live in AsyncStorage, other passengers,
delays and gates are simulated, and payments complete instantly. A green
"Demo" badge shows on the home screen.

```bash
npm test           # booking engine tests (search, pricing, seats, holds, changes, refunds, check-in)
npm run typecheck
npm run lint
```

## Go live: Supabase + Stripe

Everything that decides money or seats runs on the server, in the Supabase
Edge Function `airline`, using the **same code** the demo runs
(`supabase/functions/_shared/core`). The app only sends requests.

1. **Create a Supabase project** and link it:
   ```bash
   npx supabase login
   npx supabase link --project-ref <your-ref>
   npx supabase db push                     # creates tables, RLS and functions
   ```
2. **Set the function secrets** (Stripe Dashboard → Developers → API keys):
   ```bash
   npx supabase secrets set STRIPE_SECRET_KEY=sk_test_... STRIPE_WEBHOOK_SECRET=whsec_...
   npx supabase functions deploy airline
   npx supabase functions deploy stripe-webhook
   ```
3. **Add the Stripe webhook**: endpoint
   `https://<your-ref>.supabase.co/functions/v1/stripe-webhook`, events
   `payment_intent.succeeded` and `payment_intent.payment_failed`. Copy its
   signing secret into `STRIPE_WEBHOOK_SECRET`.
4. **Configure the app**: copy `.env.example` to `.env` and fill in the
   Supabase URL, anon key and Stripe publishable key.
5. **Build**: Stripe's SDK is native, so use a development build rather than
   Expo Go for card payments:
   ```bash
   npx eas-cli@latest build --profile development --platform android
   ```

### How payment works

1. The app creates the booking. The server prices it and holds the seats for 30 minutes.
2. The app asks for a payment. The server creates a Stripe PaymentIntent for the balance due (or a Checkout Session on the web).
3. The customer pays in Stripe's sheet.
4. Stripe calls `stripe-webhook`, which records the payment, confirms the booking and issues ticket numbers. Repeated webhooks are ignored.
5. Cancelling a refundable booking refunds the card through Stripe automatically.

### Staff

Set `profiles.role` to `agent` or `admin` in the database for staff. Staff can
read all bookings and update `flight_ops` (status, delay, gate, note), which
the app shows on flight status and boarding passes.

## Project layout

```
src/app/                    Expo Router screens
  (tabs)/                   Book, Trips, Status, Info, Account
  book/                     flights → passengers → seats → extras
  pay/[pnr].tsx             payment
  booking/[pnr]/            manage, seats, bags, change, details, check-in, boarding pass
  auth/                     log in, sign up, reset password
  info/[slug].tsx           travel information pages
src/components/             brand UI, seat map, calendar, QR code
src/lib/api/                demo (on-device) and live (Supabase) clients, same interface
supabase/functions/_shared/core/   the airline engine: schedule, pricing, seats, status, bookings
supabase/functions/airline/        the API Edge Function
supabase/functions/stripe-webhook/ payment confirmation
supabase/migrations/               schema, row-level security, seat locking
tests/                             engine tests (Node's test runner)
```

## Before launch

- Replace the sample network in `core/schedule.ts` and fares in `core/pricing.ts` with the reservation system's data.
- Fill the `[PLACEHOLDERS]` in `src/lib/info-content.ts` (phone, WhatsApp, offices).
- Mobile money needs a merchant agreement with the operators (for example through the WAAFI API). The screen and flow are ready; plug the provider into `startMobileMoney` in `supabase/functions/airline/index.ts`. Until then live mode tells customers it is coming soon.
- Add rate limiting on booking lookups (reference + last name) before going public.
- Somali and Arabic translations: the design offers Soomaali / English / العربية.
