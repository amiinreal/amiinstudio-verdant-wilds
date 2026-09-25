import type { Airport } from './types.ts';

// City names use Somali spelling, as in the brand design.
export const AIRPORTS: Airport[] = [
  { code: 'MGQ', city: 'Muqdisho', name: 'Aden Adde International', country: 'Somalia', lat: 2.0144, lon: 45.3047, utcOffset: 3, domestic: true },
  { code: 'HGA', city: 'Hargeysa', name: 'Egal International', country: 'Somalia', lat: 9.518, lon: 44.0888, utcOffset: 3, domestic: true },
  { code: 'GGR', city: 'Garoowe', name: 'Garowe International', country: 'Somalia', lat: 8.457, lon: 48.567, utcOffset: 3, domestic: true },
  { code: 'BSA', city: 'Boosaaso', name: 'Bender Qassim International', country: 'Somalia', lat: 11.2753, lon: 49.1494, utcOffset: 3, domestic: true },
  { code: 'KMU', city: 'Kismaayo', name: 'Kismayo Airport', country: 'Somalia', lat: -0.3773, lon: 42.4592, utcOffset: 3, domestic: true },
  { code: 'GLK', city: 'Gaalkacyo', name: 'Abdullahi Yusuf International', country: 'Somalia', lat: 6.7808, lon: 47.4547, utcOffset: 3, domestic: true },
  { code: 'BBO', city: 'Berbera', name: 'Berbera Airport', country: 'Somalia', lat: 10.3892, lon: 44.9411, utcOffset: 3, domestic: true },
  { code: 'BIB', city: 'Baydhabo', name: 'Baidoa Airport', country: 'Somalia', lat: 3.1022, lon: 43.6286, utcOffset: 3, domestic: true },
  { code: 'NBO', city: 'Nairobi', name: 'Jomo Kenyatta International', country: 'Kenya', lat: -1.3192, lon: 36.9278, utcOffset: 3, domestic: false },
  { code: 'ADD', city: 'Addis Ababa', name: 'Bole International', country: 'Ethiopia', lat: 8.9779, lon: 38.7993, utcOffset: 3, domestic: false },
  { code: 'DJI', city: 'Djibouti', name: 'Djibouti–Ambouli International', country: 'Djibouti', lat: 11.5473, lon: 43.1595, utcOffset: 3, domestic: false },
  { code: 'EBB', city: 'Entebbe', name: 'Entebbe International', country: 'Uganda', lat: 0.0424, lon: 32.4435, utcOffset: 3, domestic: false },
  { code: 'JED', city: 'Jeddah', name: 'King Abdulaziz International', country: 'Saudi Arabia', lat: 21.6796, lon: 39.1565, utcOffset: 3, domestic: false },
  { code: 'DXB', city: 'Dubai', name: 'Dubai International', country: 'United Arab Emirates', lat: 25.2532, lon: 55.3657, utcOffset: 4, domestic: false },
  { code: 'IST', city: 'Istanbul', name: 'Istanbul Airport', country: 'Türkiye', lat: 41.2753, lon: 28.7519, utcOffset: 3, domestic: false },
];

const BY_CODE = new Map(AIRPORTS.map((a) => [a.code, a]));

export function airport(code: string): Airport {
  const a = BY_CODE.get(code);
  if (!a) throw new Error(`Unknown airport ${code}`);
  return a;
}

export function findAirport(code: string): Airport | undefined {
  return BY_CODE.get(code);
}

export function distanceKm(a: Airport, b: Airport): number {
  const rad = Math.PI / 180;
  const dLat = (b.lat - a.lat) * rad;
  const dLon = (b.lon - a.lon) * rad;
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(a.lat * rad) * Math.cos(b.lat * rad) * Math.sin(dLon / 2) ** 2;
  return 2 * 6371 * Math.asin(Math.sqrt(h));
}

export function isDomestic(origin: string, destination: string): boolean {
  return airport(origin).domestic && airport(destination).domestic;
}
