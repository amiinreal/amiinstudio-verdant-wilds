import type { ReactElement } from 'react';

import type { CardPaymentStart } from './api';

// Stripe's React Native SDK has no web build, so the web app pays through
// Stripe Checkout and comes back to the booking page afterwards.

export type CardResult = 'paid' | 'canceled' | 'redirected';

export function PaymentsProvider({ children }: { children: ReactElement | ReactElement[] }) {
  return <>{children}</>;
}

export function useCardPayment() {
  return async (start: CardPaymentStart, _email: string): Promise<CardResult> => {
    if (start.kind === 'checkout') {
      window.location.assign(start.url);
      return 'redirected';
    }
    return 'paid';
  };
}
