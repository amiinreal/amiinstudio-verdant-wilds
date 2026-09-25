import { findAirport } from '@core/airports';
import { parseDate } from '@core/time';

export { formatUsd } from '@core/pricing';

const DAYS = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const MONTHS_LONG = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

export function dayName(date: string): string {
  const { y, m, d } = parseDate(date);
  return DAYS[new Date(Date.UTC(y, m - 1, d)).getUTCDay()];
}

/** "Thu 15 Oct" as in the design */
export function shortDate(date: string): string {
  const { m, d } = parseDate(date);
  return `${dayName(date)} ${d} ${MONTHS[m - 1]}`;
}

export function dayMonth(date: string): string {
  const { m, d } = parseDate(date);
  return `${d} ${MONTHS[m - 1]}`;
}

export function longDate(date: string): string {
  const { y, m, d } = parseDate(date);
  return `${dayName(date)} ${d} ${MONTHS_LONG[m - 1]} ${y}`;
}

export function monthName(m: number): string {
  return MONTHS_LONG[m - 1];
}

export function duration(min: number): string {
  const h = Math.floor(min / 60);
  const m = min % 60;
  return h ? `${h} h ${m} min` : `${m} min`;
}

export function cityName(code: string): string {
  return findAirport(code)?.city ?? code;
}

export function cityCode(code: string): string {
  const a = findAirport(code);
  return a ? `${a.city} (${a.code})` : code;
}

export function countdown(ms: number): string {
  if (ms <= 0) return '0:00';
  const total = Math.floor(ms / 1000);
  const h = Math.floor(total / 3600);
  const m = Math.floor((total % 3600) / 60);
  const s = total % 60;
  if (h > 0) return `${h} h ${m} min`;
  return `${m}:${s < 10 ? '0' : ''}${s}`;
}

export function dateTime(iso: string): string {
  const t = new Date(iso);
  const pad = (n: number) => (n < 10 ? `0${n}` : String(n));
  return `${t.getDate()} ${MONTHS[t.getMonth()]} ${t.getFullYear()}, ${pad(t.getHours())}:${pad(t.getMinutes())}`;
}
