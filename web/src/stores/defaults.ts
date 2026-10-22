import type { Img, Text } from '../lib/look';
import type { Queue, Settings } from './types';

export const ANGLES = [
  ['front34', 'Front ¾', 35, 8],
  ['side', 'Side', 90, 2],
  ['rear34', 'Rear ¾', 145, 8],
  ['front', 'Front', 0, 4],
  ['rear', 'Rear', 180, 4],
  ['high', 'High', 35, 35],
] as const;
export const LAYERS = ['Black', 'White primary', 'White secondary'];
export const SWATCHES = ['#e11d2a', '#f4f4f5', '#16161a', '#1d4ed8', '#f59e0b', '#15803d', '#7c3aed', '#9ca3af'];

export const DEFAULTS: Settings = {
  rot: 35,
  height: 8,
  fov: 40,
  distance: 100,
  shiftX: 0,
  shiftY: 0,
  lights: 'off',
  roof: 'up',
  windows: 'up',
  cabin: 'off',
  steer: 0,
  pitch: 0,
  roll: 0,
  ride: 0,
  doors: [],
  plate: 'EVOLENT',
  width: 800,
  place: 'green',
  hour: 13,
  weather: 'sunny',
  glow: 0,
  glowColour: '#ff2d55',
  glowFrom: 'around',
  neon: 'off',
  neonColour: '#00bfff',
  tint: 'none',
  blur: 0,
  filter: 'none',
  filterPower: 70,
  bg: 'none',
  bgColourA: '#f4f4f5',
  bgColourB: '#a1a1aa',
  bgAngle: 180,
  horizon: 66,
  vignette: 0,
  frame: 'fit',
  frameW: 800,
  frameH: 450,
  carSize: 94,
  carY: 50,
  carDX: 0,
  carDY: 0,
  shadow: 0,
  shadowSoft: 50,
  shadowWide: 100,
  shadowStyle: 'contact',
  reflectBlur: 60,
  reflectReach: 45,
  reflect: 0,
  texts: [],
  images: [],
  bgImage: '',
  edge: 0,
  bright: 0,
  contrast: 0,
  saturation: 0,
  warm: 0,
  indicators: 'off',
  gear: 'down',
  ground: 'on',
  sky: 'sun',
  sun: 13,
  paint: 'gloss',
  shine: 100,
  sunPower: 100,
};

export const listOf = <T>(value: unknown): T[] => (Array.isArray(value) ? value : []);

export const queueOf = (raw: any): Queue | null =>
  raw && typeof raw === 'object' ? { ...raw, list: listOf<string>(raw.list), failed: listOf(raw.failed) } : null;

export const settingsOf = (raw: any): Settings => ({
  ...DEFAULTS,
  ...raw,
  doors: listOf<number>(raw?.doors),
  texts: listOf<Text>(raw?.texts),
  images: listOf<Img>(raw?.images),
});

export const angleOf = (settings: Settings) =>
  ANGLES.find(([, , rot, height]) => rot === settings.rot && height === settings.height)?.[0] ?? null;
