import { StripeProvider, useStripe } from '@stripe/stripe-react-native';
import * as WebBrowser from 'expo-web-browser';
import type { ReactElement } from 'react';

import { AirlineError } from '@core/types';

import type { CardPaymentStart } from './api';
import { config } from './config';

export type CardResult = 'paid' | 'canceled' | 'redirected';

export function PaymentsProvider({ children }: { children: ReactElement | ReactElement[] }) {
  return (
    <StripeProvider publishableKey={config.stripePublishableKey} merchantIdentifier={config.merchantIdentifier} urlScheme={config.urlScheme}>
      {children}
    </StripeProvider>
  );
}

/** Opens Stripe's PaymentSheet (cards, Apple Pay, Google Pay) for a booking. */
export function useCardPayment() {
  const { initPaymentSheet, presentPaymentSheet } = useStripe();

  return async (start: CardPaymentStart, email: string): Promise<CardResult> => {
    if (start.kind === 'checkout') {
      await WebBrowser.openBrowserAsync(start.url);
      return 'redirected';
    }
    if (start.kind !== 'payment_sheet') return 'paid';
    if (!config.stripePublishableKey) throw new AirlineError('stripe', 'Card payments are not set up in this build.');

    const wallets = process.env.EXPO_PUBLIC_STRIPE_WALLETS === '1';
    const country = process.env.EXPO_PUBLIC_STRIPE_MERCHANT_COUNTRY ?? 'US';
    const init = await initPaymentSheet({
      merchantDisplayName: 'Somali Airlines',
      paymentIntentClientSecret: start.clientSecret,
      returnURL: `${config.urlScheme}://stripe-redirect`,
      defaultBillingDetails: { email },
      ...(wallets
        ? {
            applePay: { merchantCountryCode: country },
            googlePay: { merchantCountryCode: country, currencyCode: 'USD', testEnv: __DEV__ },
          }
        : {}),
    });
    if (init.error) throw new AirlineError('stripe', init.error.message);

    const res = await presentPaymentSheet();
    if (res.error) {
      if (res.error.code === 'Canceled') return 'canceled';
      throw new AirlineError('stripe', res.error.message);
    }
    return 'paid';
  };
}
