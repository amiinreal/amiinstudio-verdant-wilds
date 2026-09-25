import type { ColorValue } from 'react-native';
import Svg, { Circle, Path, Polygon, Rect } from 'react-native-svg';

import { colors } from '@/lib/theme';

// Stroke icons drawn to match the design canvas (1.8–2 px strokes, round caps).
type P = { size?: number; color?: ColorValue; strokeWidth?: number };

function S({ size = 22, color = colors.blue, strokeWidth = 1.8, children }: P & { children: React.ReactNode }) {
  return (
    <Svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke={color} strokeWidth={strokeWidth} strokeLinecap="round" strokeLinejoin="round">
      {children}
    </Svg>
  );
}

export const Icon = {
  Plane: (p: P) => <S {...p}><Path d="M2 13l8-1 4-8h2l-1 8 5 1v2l-5 1 1 8h-2l-4-8-8-1z" /></S>,
  Booking: (p: P) => <S {...p}><Rect x={4} y={3} width={16} height={18} rx={2} /><Path d="M8 8h8M8 12h8M8 16h5" /></S>,
  Ticket: (p: P) => <S {...p}><Path d="M3 7h18v4a2 2 0 0 0 0 4v4H3v-4a2 2 0 0 0 0-4z" /></S>,
  Clock: (p: P) => <S {...p}><Circle cx={12} cy={12} r={9} /><Path d="M12 7v5l3 2" /></S>,
  Bag: (p: P) => <S {...p}><Rect x={5} y={7} width={14} height={13} rx={2} /><Path d="M9 7V4h6v3" /></S>,
  Info: (p: P) => <S {...p}><Circle cx={12} cy={12} r={9} /><Path d="M12 11v6M12 7.5v.5" /></S>,
  User: (p: P) => <S {...p}><Circle cx={12} cy={8} r={4} /><Path d="M4 21c1.5-4 4.5-6 8-6s6.5 2 8 6" /></S>,
  Search: (p: P) => <S {...p}><Circle cx={11} cy={11} r={7} /><Path d="M20 20l-4-4" /></S>,
  Swap: (p: P) => <S {...p}><Path d="M7 4v16l-3-3M17 20V4l3 3" /></S>,
  Back: (p: P) => <S {...p}><Path d="M15 5l-7 7 7 7" /></S>,
  Close: (p: P) => <S {...p}><Path d="M6 6l12 12M18 6L6 18" /></S>,
  Check: (p: P) => <S strokeWidth={2.4} {...p}><Path d="M5 12l5 5 9-10" /></S>,
  Cross: (p: P) => <S strokeWidth={2.4} {...p}><Path d="M6 6l12 12M18 6L6 18" /></S>,
  Chevron: (p: P) => <S {...p}><Path d="M9 5l7 7-7 7" /></S>,
  ChevronLeft: (p: P) => <S {...p}><Path d="M15 5l-7 7 7 7" /></S>,
  Calendar: (p: P) => <S {...p}><Rect x={3} y={5} width={18} height={16} rx={2} /><Path d="M3 10h18M8 3v4M16 3v4" /></S>,
  Seat: (p: P) => <S {...p}><Path d="M6 4v9a2 2 0 0 0 2 2h8M8 15l-1 5M16 15l1 5M18 11h-6" /></S>,
  Card: (p: P) => <S {...p}><Rect x={2} y={5} width={20} height={14} rx={2} /><Path d="M2 10h20M6 15h4" /></S>,
  Phone: (p: P) => <S {...p}><Rect x={7} y={2} width={10} height={20} rx={2} /><Path d="M11 18h2" /></S>,
  Hourglass: (p: P) => <S {...p}><Path d="M6 3h12M6 21h12M7 3c0 5 10 6 10 9s-10 4-10 9M17 3c0 5-10 6-10 9s10 4 10 9" /></S>,
  Doc: (p: P) => <S {...p}><Path d="M6 3h8l4 4v14H6z" /><Path d="M14 3v4h4M9 12h6M9 16h6" /></S>,
  Heart: (p: P) => <S {...p}><Path d="M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.5-7 10-7 10z" /></S>,
  Child: (p: P) => <S {...p}><Circle cx={12} cy={6} r={3} /><Path d="M8 21l1-7-3-2M16 21l-1-7 3-2M9 14h6" /></S>,
  Star: (p: P) => <S {...p}><Polygon points="12,3 14.6,9 21,9.3 16,13.3 17.7,20 12,16.3 6.3,20 8,13.3 3,9.3 9.4,9" /></S>,
  Chat: (p: P) => <S {...p}><Path d="M4 5h16v11H9l-5 4z" /></S>,
  Map: (p: P) => <S {...p}><Path d="M9 4L3 6v14l6-2 6 2 6-2V4l-6 2z" /><Path d="M9 4v14M15 6v14" /></S>,
  Shield: (p: P) => <S {...p}><Path d="M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z" /></S>,
  Logout: (p: P) => <S {...p}><Path d="M15 4h4v16h-4M10 8l-4 4 4 4M6 12h10" /></S>,
  Plus: (p: P) => <S {...p}><Path d="M12 5v14M5 12h14" /></S>,
  Minus: (p: P) => <S {...p}><Path d="M5 12h14" /></S>,
  Edit: (p: P) => <S {...p}><Path d="M4 20h4L19 9l-4-4L4 16z" /></S>,
  Wallet: (p: P) => <S {...p}><Rect x={3} y={6} width={18} height={14} rx={2} /><Path d="M16 13h2M3 10h18M6 6l9-3 2 3" /></S>,
  Copy: (p: P) => <S {...p}><Rect x={8} y={8} width={12} height={12} rx={2} /><Path d="M16 8V4H4v12h4" /></S>,
};

/** The White Star mark from the brand design. */
export function Logo({ size = 32 }: { size?: number }) {
  return (
    <Svg width={size} height={size} viewBox="0 0 40 40">
      <Circle cx={20} cy={20} r={20} fill={colors.sky} />
      <Polygon points="20,7 23.1,16.4 33,16.6 25,22.6 27.9,32.2 20,26.5 12.1,32.2 15,22.6 7,16.6 16.9,16.4" fill={colors.white} />
    </Svg>
  );
}

export function HeroStar({ size = 380 }: { size?: number }) {
  return (
    <Svg width={size} height={size} viewBox="0 0 100 100">
      <Polygon points="50,4 61.8,37.6 97.6,38.2 69,60 79.4,94.4 50,74 20.6,94.4 31,60 2.4,38.2 38.2,37.6" fill={colors.sky} />
    </Svg>
  );
}
