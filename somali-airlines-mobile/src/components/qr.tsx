import { create } from 'qrcode';
import { useMemo } from 'react';
import Svg, { Path, Rect } from 'react-native-svg';

import { colors } from '@/lib/theme';

/** A real, scannable QR code drawn as one SVG path. */
export function QRCode({ value, size = 200 }: { value: string; size?: number }) {
  const { d, n } = useMemo(() => {
    const qr = create(value, { errorCorrectionLevel: 'M' });
    const count = qr.modules.size;
    let path = '';
    for (let r = 0; r < count; r++) {
      for (let c = 0; c < count; c++) {
        if (qr.modules.get(r, c)) path += `M${c} ${r}h1v1h-1z`;
      }
    }
    return { d: path, n: count };
  }, [value]);

  const quiet = 2;
  return (
    <Svg width={size} height={size} viewBox={`${-quiet} ${-quiet} ${n + quiet * 2} ${n + quiet * 2}`} accessibilityLabel="Boarding pass code">
      <Rect x={-quiet} y={-quiet} width={n + quiet * 2} height={n + quiet * 2} fill={colors.white} />
      <Path d={d} fill={colors.navy} />
    </Svg>
  );
}
