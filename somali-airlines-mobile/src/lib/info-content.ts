import { AIRPORTS } from '@core/airports';
import { FARE_RULES } from '@core/pricing';
import { ROUTES } from '@core/schedule';
import { SEAT_PRICES } from '@core/seats';
import { CHECKIN_CLOSES_MIN, CHECKIN_OPENS_H, GATE_CLOSES_BEFORE_MIN } from '@core/status';

// Travel information pages. Figures that the booking engine enforces are read
// from the core so the text and the rules never disagree. Contact details in
// [BRACKETS] are placeholders to fill in before launch.

export type Block =
  | { kind: 'p'; text: string }
  | { kind: 'h'; text: string }
  | { kind: 'list'; items: string[] }
  | { kind: 'note'; text: string }
  | { kind: 'table'; rows: [string, string][] };

export type Article = {
  slug: string;
  title: string;
  summary: string;
  group: 'Before you fly' | 'At the airport' | 'About us' | 'Legal';
  blocks: Block[];
};

const days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const city = (c: string) => AIRPORTS.find((a) => a.code === c)?.city ?? c;

const routeRows: [string, string][] = ROUTES.filter((r) => r.number % 2 === 1).map((r) => [
  `${city(r.origin)} – ${city(r.destination)}`,
  r.days.length === 7 ? 'Daily' : r.days.map((d) => days[d]).join(', '),
]);

const fareRows = (['saver', 'classic', 'flex', 'business'] as const).map((f): [string, string] => {
  const r = FARE_RULES[f];
  return [r.name, `${r.cabinBag} cabin bag, ${r.checkedBags ? `${r.checkedBags} × ${r.checkedBagKg} kg checked` : 'no checked bag'}`];
});

export const ARTICLES: Article[] = [
  {
    slug: 'baggage',
    title: 'Baggage',
    summary: 'Allowances for each fare, extra bags and what you cannot pack',
    group: 'Before you fly',
    blocks: [
      { kind: 'p', text: 'Your allowance depends on your fare. It is shown on your booking and on your ticket email.' },
      { kind: 'table', rows: fareRows },
      { kind: 'h', text: 'Extra bags' },
      { kind: 'p', text: 'Add extra 23 kg bags in My trips up to 1 hour before departure. It costs USD 35 per bag per flight within Somalia, and USD 60 per bag per flight abroad. It costs more at the airport.' },
      { kind: 'h', text: 'Cabin bag' },
      { kind: 'list', items: ['One bag up to 55 × 40 × 23 cm that fits in the overhead locker', 'One small personal item that fits under the seat in front', 'Medicine, documents and valuables always in your cabin bag'] },
      { kind: 'h', text: 'Not allowed in any bag' },
      { kind: 'list', items: ['Explosives, fireworks and flares', 'Flammable liquids and gas canisters', 'Toxic or corrosive substances', 'Weapons, unless declared and approved before travel'] },
      { kind: 'note', text: 'Power banks, spare lithium batteries and e-cigarettes are only allowed in the cabin, never in checked bags.' },
    ],
  },
  {
    slug: 'documents',
    title: 'Travel documents and eTAS',
    summary: 'Passports, the eTAS for Somalia, and visas for other countries',
    group: 'Before you fly',
    blocks: [
      { kind: 'p', text: 'Your passport must be valid for 6 months after you arrive. The name on your booking must match your passport.' },
      { kind: 'h', text: 'Flying to Somalia on a foreign passport' },
      { kind: 'p', text: 'You need an approved eTAS (electronic travel authorisation) before you board. This includes children and infants. Apply on the official government website and bring the approval with you.' },
      { kind: 'h', text: 'Flights within Somalia' },
      { kind: 'p', text: 'Bring a passport or a national ID card. Children travelling with a parent can use the parent’s documents if they are listed on them.' },
      { kind: 'h', text: 'Flying abroad' },
      { kind: 'p', text: 'Check the visa rules for Kenya, Ethiopia, Djibouti, Uganda, Saudi Arabia, the United Arab Emirates and Türkiye before you book. We cannot let you board without the right documents.' },
      { kind: 'note', text: 'Entry rules change. Always check with the embassy of the country you are flying to.' },
    ],
  },
  {
    slug: 'checkin',
    title: 'Check-in and boarding',
    summary: 'When check-in opens, gate times and boarding zones',
    group: 'At the airport',
    blocks: [
      { kind: 'table', rows: [
        ['Online check-in opens', `${CHECKIN_OPENS_H} hours before departure`],
        ['Online check-in closes', `${CHECKIN_CLOSES_MIN} minutes before departure`],
        ['Airport desk closes', '45 minutes before departure'],
        ['Gate closes', `${GATE_CLOSES_BEFORE_MIN} minutes before departure`],
      ] },
      { kind: 'p', text: 'After online check-in, show the boarding pass on your phone. It works without internet. Drop checked bags at the bag drop desk.' },
      { kind: 'h', text: 'Boarding zones' },
      { kind: 'list', items: ['Zone 1: Business, Flex fares and passengers needing assistance', 'Zone 2: rows 16 and back', 'Zone 3: all other rows'] },
    ],
  },
  {
    slug: 'seats',
    title: 'Seats',
    summary: 'Seat prices, exit rows and seats for families',
    group: 'Before you fly',
    blocks: [
      { kind: 'table', rows: [
        ['Standard seat', `USD ${SEAT_PRICES.standard}`],
        ['Front rows 4 to 7', `USD ${SEAT_PRICES.front}`],
        ['Exit rows 12 and 13, extra legroom', `USD ${SEAT_PRICES.exit}`],
        ['Flex and Business fares', 'Free'],
      ] },
      { kind: 'p', text: 'If you don’t choose, we give you a free seat at check-in.' },
      { kind: 'note', text: 'Exit row seats are for adults who can help in an emergency. Children cannot sit there.' },
    ],
  },
  {
    slug: 'children',
    title: 'Travelling with children',
    summary: 'Infants, children’s fares, pushchairs and flying alone',
    group: 'Before you fly',
    blocks: [
      { kind: 'list', items: [
        'Infants under 2 fly on an adult’s lap for 10% of the fare plus a small tax',
        'Children from 2 to 11 have their own seat and pay 75% of the fare',
        'Each adult can travel with one infant',
        'Pushchairs and car seats travel free and can be used up to the aircraft door',
      ] },
      { kind: 'h', text: 'Children flying alone' },
      { kind: 'p', text: 'Children under 12 cannot fly alone. Call us to arrange an escort for young people from 12 to 15.' },
    ],
  },
  {
    slug: 'assistance',
    title: 'Special assistance',
    summary: 'Wheelchairs, reduced mobility, medical needs and pregnancy',
    group: 'Before you fly',
    blocks: [
      { kind: 'p', text: 'Assistance is free. Add it to your booking in My trips under Passport and assistance, at least 48 hours before you fly.' },
      { kind: 'list', items: ['Wheelchair to the aircraft door or to your seat', 'Help for blind, low-vision, deaf and hard-of-hearing passengers', 'Travelling with medical equipment or oxygen', 'Priority boarding in zone 1'] },
      { kind: 'h', text: 'Pregnancy' },
      { kind: 'p', text: 'From week 28, bring a letter from your doctor or midwife. We cannot carry passengers after week 36, or week 32 with twins.' },
    ],
  },
  {
    slug: 'payments',
    title: 'Ways to pay',
    summary: 'Mobile money, cards, paying for family and holding a fare',
    group: 'Before you fly',
    blocks: [
      { kind: 'list', items: ['Mobile money: EVC Plus, ZAAD, SAHAL, WAAFI', 'Visa and Mastercard, with Apple Pay and Google Pay', 'Cash at a sales office'] },
      { kind: 'h', text: 'Let family pay' },
      { kind: 'p', text: 'Book from anywhere and enter a relative’s mobile number. They approve the payment with their PIN on their own phone. Your tickets arrive as soon as they do.' },
      { kind: 'h', text: 'Hold and pay later' },
      { kind: 'p', text: 'Keep a fare for up to 48 hours while you collect the money. The hold ends 24 hours before departure at the latest. If you don’t pay in time, the booking is released.' },
      { kind: 'note', text: 'All prices are in US dollars and include taxes and fees.' },
    ],
  },
  {
    slug: 'changes',
    title: 'Changes, cancellations and refunds',
    summary: 'What each fare lets you change, and what you get back',
    group: 'Before you fly',
    blocks: [
      { kind: 'table', rows: [
        ['Saver', 'Change for USD 50 per passenger, no refund (taxes are returned)'],
        ['Classic', 'Free date change, refund less USD 75 per passenger per flight'],
        ['Flex', 'Free changes, full refund'],
        ['Business', 'Free changes, full refund'],
      ] },
      { kind: 'p', text: 'If the new flight costs more, you pay the difference. If it costs less, the difference is not refunded. Changes close 2 hours before departure.' },
      { kind: 'p', text: 'Card refunds go back to the same card within 5 to 10 days. Mobile money and cash refunds are paid by our team within 7 days.' },
      { kind: 'note', text: 'If we cancel or badly delay your flight, you can choose a free change or a full refund on any fare.' },
    ],
  },
  {
    slug: 'destinations',
    title: 'Where we fly',
    summary: 'Our routes and the days they operate',
    group: 'About us',
    blocks: [
      { kind: 'p', text: 'All flights are direct, on an Airbus A320 with Business and Economy cabins.' },
      { kind: 'table', rows: routeRows },
    ],
  },
  {
    slug: 'story',
    title: 'Our story',
    summary: 'The White Star, since 1964',
    group: 'About us',
    blocks: [
      { kind: 'p', text: 'Somali Airlines first flew in July 1964. By the 1980s the White Star connected Muqdisho with Rome, Frankfurt, Cairo, Jeddah, Abu Dhabi and Nairobi.' },
      { kind: 'table', rows: [
        ['1964', 'First flights from Muqdisho, flown with DC-3s'],
        ['1970s', 'Boeing 720s and 707s carry the star to Europe'],
        ['1987', 'An Airbus A310 arrives, with White Star Service on board'],
        ['1991', 'Flights stop as the civil war begins'],
        ['2025', 'The government announces the airline’s return'],
      ] },
      { kind: 'p', text: 'Xiddigta Cad. The White Star is flying again.' },
    ],
  },
  {
    slug: 'contact',
    title: 'Contact us',
    summary: 'WhatsApp, phone and sales offices',
    group: 'About us',
    blocks: [
      { kind: 'p', text: 'Write to us in Somali, English or Arabic. A person answers.' },
      { kind: 'table', rows: [
        ['WhatsApp', '[WHATSAPP NUMBER]'],
        ['Phone', '[PHONE NUMBER]'],
        ['Email', '[SUPPORT EMAIL]'],
      ] },
      { kind: 'h', text: 'Sales offices' },
      { kind: 'p', text: 'Pay in cash or change a ticket in person at our offices in Muqdisho and Hargeysa. [OFFICE ADDRESSES AND HOURS]' },
      { kind: 'note', text: 'Have your 6-character booking reference ready.' },
    ],
  },
  {
    slug: 'conditions',
    title: 'Conditions of carriage',
    summary: 'The rules of your contract with us',
    group: 'Legal',
    blocks: [
      { kind: 'p', text: 'This is a summary. The full conditions of carriage apply to every ticket. [LINK TO FULL CONDITIONS]' },
      { kind: 'list', items: [
        'Tickets are personal and cannot be transferred to another person',
        'Flights must be used in order. If you miss the outbound flight, tell us before departure or the return may be cancelled',
        'Be at the gate before it closes. We may give your seat away if you are late',
        'We may refuse to carry passengers who are unfit to fly or who don’t have the right documents',
      ] },
    ],
  },
  {
    slug: 'privacy',
    title: 'Privacy',
    summary: 'What we collect and why',
    group: 'Legal',
    blocks: [
      { kind: 'p', text: 'We collect the details needed to fly you: names, dates of birth, passport details, contact details and payment records. Governments require some of this for border control.' },
      { kind: 'list', items: ['Card payments are handled by Stripe. We never see or store your full card number', 'We keep bookings for as long as the law requires, then delete them', 'You can ask for a copy of your data, or to correct it, at any time'] },
      { kind: 'note', text: '[DATA PROTECTION CONTACT]' },
    ],
  },
  {
    slug: 'accessibility',
    title: 'Accessibility',
    summary: 'How we make the app work for everyone',
    group: 'Legal',
    blocks: [
      { kind: 'p', text: 'The app supports screen readers, large text and has touch targets of at least 44 points. Tell us if something doesn’t work for you and we will fix it.' },
    ],
  },
];

export function article(slug: string) {
  return ARTICLES.find((a) => a.slug === slug);
}
