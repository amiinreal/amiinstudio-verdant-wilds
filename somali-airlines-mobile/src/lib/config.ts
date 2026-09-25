// Live mode needs a Supabase project (see README). Without one the app runs
// the same airline logic on the device, with simulated payments.
export const config = {
  supabaseUrl: process.env.EXPO_PUBLIC_SUPABASE_URL ?? '',
  supabaseAnonKey: process.env.EXPO_PUBLIC_SUPABASE_ANON_KEY ?? '',
  stripePublishableKey: process.env.EXPO_PUBLIC_STRIPE_PUBLISHABLE_KEY ?? '',
  merchantIdentifier: 'merchant.com.amiinstudio.somaliairlines',
  urlScheme: 'somaliairlines',
};

export const isLive = Boolean(config.supabaseUrl && config.supabaseAnonKey);
