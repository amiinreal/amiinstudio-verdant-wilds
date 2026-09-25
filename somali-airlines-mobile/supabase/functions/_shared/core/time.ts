// Date helpers that work on plain YYYY-MM-DD / HH:MM strings plus a UTC
// offset, so results never depend on the device's time zone.

export function pad(n: number): string {
  return n < 10 ? `0${n}` : String(n);
}

export function parseDate(date: string): { y: number; m: number; d: number } {
  const [y, m, d] = date.split('-').map(Number);
  return { y, m, d };
}

export function addDays(date: string, days: number): string {
  const { y, m, d } = parseDate(date);
  const t = new Date(Date.UTC(y, m - 1, d + days));
  return `${t.getUTCFullYear()}-${pad(t.getUTCMonth() + 1)}-${pad(t.getUTCDate())}`;
}

export function dayOfWeek(date: string): number {
  const { y, m, d } = parseDate(date);
  return new Date(Date.UTC(y, m - 1, d)).getUTCDay();
}

export function minutesOf(time: string): number {
  const [h, m] = time.split(':').map(Number);
  return h * 60 + m;
}

export function timeOf(minutes: number): { time: string; dayOffset: number } {
  const dayOffset = Math.floor(minutes / 1440);
  const rest = ((minutes % 1440) + 1440) % 1440;
  return { time: `${pad(Math.floor(rest / 60))}:${pad(rest % 60)}`, dayOffset };
}

/** Absolute instant (ms since epoch) of a local date + time at a UTC offset. */
export function instant(date: string, time: string, utcOffset: number): number {
  const { y, m, d } = parseDate(date);
  const mins = minutesOf(time);
  return Date.UTC(y, m - 1, d, 0, mins) - utcOffset * 3600_000;
}

/** Local YYYY-MM-DD at a UTC offset for an absolute instant. */
export function localDate(ms: number, utcOffset: number): string {
  const t = new Date(ms + utcOffset * 3600_000);
  return `${t.getUTCFullYear()}-${pad(t.getUTCMonth() + 1)}-${pad(t.getUTCDate())}`;
}

export function todayAt(utcOffset: number, now = Date.now()): string {
  return localDate(now, utcOffset);
}

export function diffDays(a: string, b: string): number {
  const pa = parseDate(a);
  const pb = parseDate(b);
  return Math.round((Date.UTC(pb.y, pb.m - 1, pb.d) - Date.UTC(pa.y, pa.m - 1, pa.d)) / 86400_000);
}

export function ageOn(dateOfBirth: string, onDate: string): number {
  const b = parseDate(dateOfBirth);
  const o = parseDate(onDate);
  let age = o.y - b.y;
  if (o.m < b.m || (o.m === b.m && o.d < b.d)) age--;
  return age;
}

export function isValidDate(date: string): boolean {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date)) return false;
  const { y, m, d } = parseDate(date);
  const t = new Date(Date.UTC(y, m - 1, d));
  return t.getUTCFullYear() === y && t.getUTCMonth() === m - 1 && t.getUTCDate() === d;
}

/** Small deterministic hash, used to vary fares and demo load per flight. */
export function hash(text: string): number {
  let h = 0x811c9dc5;
  for (let i = 0; i < text.length; i++) {
    h ^= text.charCodeAt(i);
    h = Math.imul(h, 0x01000193);
  }
  return h >>> 0;
}

export function seeded(seed: number): () => number {
  let a = seed;
  return () => {
    a = (a + 0x6d2b79f5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}
