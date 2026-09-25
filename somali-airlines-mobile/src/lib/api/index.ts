import { isLive } from '../config';
import { demoApi } from './demo';
import { liveApi } from './live';
import type { AirlineApi } from './types';

export const api: AirlineApi = isLive ? liveApi : demoApi;

export type * from './types';

export function errorMessage(e: unknown): string {
  if (e && typeof e === 'object' && 'message' in e && typeof e.message === 'string') return e.message;
  return 'Something went wrong. Try again.';
}
