import { createClient } from 'npm:@supabase/supabase-js@2';
import Stripe from 'npm:stripe@17';

import { AirlineService } from './core/service.ts';
import { PgStore } from './pg-store.ts';

export const admin = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!, {
  auth: { persistSession: false },
});

export const service = new AirlineService(new PgStore(admin), {
  demo: false,
  now: Date.now,
  randomInt: (n) => {
    // Rejection sampling keeps PNRs and ticket numbers uniform.
    const limit = 256 - (256 % n);
    const buf = new Uint8Array(1);
    do crypto.getRandomValues(buf);
    while (buf[0] >= limit);
    return buf[0] % n;
  },
  paymentHoldMinutes: 30,
  fareHoldHours: Number(Deno.env.get('FARE_HOLD_HOURS') ?? 48),
});

const stripeKey = Deno.env.get('STRIPE_SECRET_KEY');
export const stripe = stripeKey
  ? new Stripe(stripeKey, { httpClient: Stripe.createFetchHttpClient() })
  : null;

export const cors = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

export function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...cors, 'Content-Type': 'application/json' },
  });
}
