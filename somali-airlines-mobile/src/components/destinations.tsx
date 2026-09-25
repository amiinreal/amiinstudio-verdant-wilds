import Svg, { Circle, Ellipse, Path, Rect } from 'react-native-svg';

import { colors } from '@/lib/theme';

// Flat landscape illustrations from the design canvas's destination cards.
export function Scene({ code, width = 220, height = 140 }: { code: string; width?: number; height?: number }) {
  const v = ['HGA', 'GGR', 'BSA'].indexOf(code) >= 0 ? code : ['HGA', 'GGR', 'BSA'][code.charCodeAt(0) % 3];
  return (
    <Svg width={width} height={height} viewBox="0 0 320 200" preserveAspectRatio="none" style={{ borderRadius: 14 }}>
      {v === 'HGA' && (
        <>
          <Rect width={320} height={200} fill={colors.sky} />
          <Circle cx={236} cy={64} r={24} fill={colors.gold} />
          <Path d="M0 138 C60 92 110 104 160 124 C210 144 262 96 320 112 L320 200 L0 200Z" fill={colors.blue} />
          <Path d="M0 162 C80 140 150 172 230 156 C270 148 300 152 320 160 L320 200 L0 200Z" fill={colors.navy} />
        </>
      )}
      {v === 'GGR' && (
        <>
          <Rect width={320} height={200} fill={colors.gold} />
          <Circle cx={90} cy={70} r={30} fill={colors.sand} />
          <Path d="M0 150 L320 142 L320 200 L0 200Z" fill={colors.clay} />
          <Path d="M0 170 L320 166 L320 200 L0 200Z" fill={colors.navy} />
          <Path d="M222 150 L226 108" stroke={colors.navy} strokeWidth={4} />
          <Ellipse cx={226} cy={104} rx={46} ry={11} fill={colors.navy} />
        </>
      )}
      {v === 'BSA' && (
        <>
          <Rect width={320} height={200} fill={colors.skyLight} />
          <Path d="M0 110 L70 60 L120 96 L190 44 L260 100 L320 80 L320 130 L0 130Z" fill={colors.inkSoft} />
          <Rect y={126} width={320} height={74} fill={colors.blue} />
        </>
      )}
    </Svg>
  );
}
