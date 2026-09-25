// Confirms bookings when Stripe says the money arrived. Configure the
// endpoint in the Stripe dashboard for payment_intent.succeeded and
// payment_intent.payment_failed, and set STRIPE_WEBHOOK_SECRET.
import Stripe from 'npm:stripe@17';

import { service, stripe } from '../_shared/setup.ts';

const secret = Deno.env.get('STRIPE_WEBHOOK_SECRET') ?? '';
const crypto = Stripe.createSubtleCryptoProvider();

Deno.serve(async (req) => {
  if (!stripe || !secret) return new Response('Stripe is not configured', { status: 500 });
  const signature = req.headers.get('Stripe-Signature');
  if (!signature) return new Response('Missing signature', { status: 400 });

  let event: Stripe.Event;
  try {
    event = await stripe.webhooks.constructEventAsync(await req.text(), signature, secret, undefined, crypto);
  } catch (e) {
    return new Response(`Bad signature: ${(e as Error).message}`, { status: 400 });
  }

  if (event.type === 'payment_intent.succeeded' || event.type === 'payment_intent.payment_failed') {
    const pi = event.data.object as Stripe.PaymentIntent;
    const bookingId = pi.metadata?.booking_id;
    if (bookingId) {
      const succeeded = event.type === 'payment_intent.succeeded';
      await service.recordPayment(bookingId, {
        method: 'card',
        provider: 'stripe',
        amount: (succeeded ? pi.amount_received : pi.amount) / 100,
        status: succeeded ? 'succeeded' : 'failed',
        reference: pi.id,
      });
    }
  }

  return new Response(JSON.stringify({ received: true }), { headers: { 'Content-Type': 'application/json' } });
});
