export const CONTAINER_BREAKPOINTS = {
  '@sm': 320,
  '@md': 480,
  '@lg': 640,
  '@xl': 800
} as const;

export type SlotSizeClass = 'full' | 'main' | 'aside' | 'tile' | 'strip';
