// Brand tokens taken from the Somali Airlines design canvas.
export const colors = {
  navy: '#0E2A47',
  blue: '#1F5FAE',
  blueDark: '#164A8A',
  sky: '#4189DD',
  skyLight: '#8DB8EA',
  mist: '#EEF4FB',
  page: '#F7FAFD',
  white: '#FFFFFF',
  line: '#C9D6E5',
  lineSoft: '#E3EAF2',
  lineStrong: '#9AAEC4',
  cardLine: '#D5E1EE',
  ink: '#0E2A47',
  inkSoft: '#4A5B6E',
  inkFaint: '#A9BAD0',
  footerText: '#D6E0EC',
  gold: '#F2C46B',
  amber: '#E0A43A',
  sand: '#FFF6E3',
  sandLine: '#E9C77A',
  clay: '#B5523B',
  green: '#1E7A4F',
  greenSoft: '#DDF0E6',
  greenInk: '#14563A',
  red: '#B42318',
  redSoft: '#FDECEA',
} as const;

export const fonts = {
  display: 'BricolageGrotesque_700Bold',
  displayMedium: 'BricolageGrotesque_500Medium',
  body: 'IBMPlexSans_400Regular',
  bodyMedium: 'IBMPlexSans_500Medium',
  bodySemi: 'IBMPlexSans_600SemiBold',
} as const;

export const radius = { sm: 9, md: 12, lg: 14, xl: 16, xxl: 20, pill: 999 } as const;

export const space = { xs: 4, sm: 8, md: 12, lg: 16, xl: 20, xxl: 24, xxxl: 32 } as const;

/** The woven stripe band under headers: clay, amber, blue, white, navy. */
export const bandColors = [
  { color: colors.clay, w: 18 },
  { color: colors.amber, w: 6 },
  { color: colors.blue, w: 18 },
  { color: colors.white, w: 3 },
  { color: colors.navy, w: 11 },
];
