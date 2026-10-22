import type { Look } from '../../lib/look';
import type { Settings } from '../../stores/types';

export type Option<Value = string> = { value: Value; label: string };
export type Side = 'frameW' | 'frameH';
export type Switch = 'lights' | 'roof' | 'windows' | 'cabin';

export const signed = (value: number, unit: string) => `${value > 0 ? '+' : ''}${value}${unit}`;

export const SHAPES: (Option<Look['frame']> & { w: number; h: number })[] = [
  { value: 'fit', label: 'Fits the car', w: 0, h: 0 },
  { value: '16:9', label: 'Wide', w: 16, h: 9 },
  { value: '3:2', label: 'Photo', w: 3, h: 2 },
  { value: '4:3', label: 'Classic', w: 4, h: 3 },
  { value: '1:1', label: 'Square', w: 1, h: 1 },
  { value: '4:5', label: 'Tall', w: 4, h: 5 },
];
export const OWN_SIDES: Option<Side>[] = [
  { value: 'frameW', label: 'Width' },
  { value: 'frameH', label: 'Height' },
];
export const CAR_SPOTS: Option<number>[] = [
  { value: 0, label: 'Top' },
  { value: 50, label: 'Middle' },
  { value: 100, label: 'Bottom' },
];
export const SIZES: Option<number>[] = [
  { value: 512, label: 'Small' },
  { value: 640, label: 'Medium' },
  { value: 800, label: 'Large' },
  { value: 1024, label: 'Biggest' },
];

export const ON_OFF: Option<'off' | 'on'>[] = [
  { value: 'off', label: 'Off' },
  { value: 'on', label: 'On' },
];
export const UP_DOWN: Option<'up' | 'down'>[] = [
  { value: 'up', label: 'Up' },
  { value: 'down', label: 'Down' },
];
export const SWITCHES: { key: Switch; label: string; options: Option<Settings[Switch]>[] }[] = [
  { key: 'lights', label: 'Lights', options: ON_OFF },
  { key: 'roof', label: 'Roof', options: UP_DOWN },
  { key: 'windows', label: 'Windows', options: UP_DOWN },
  { key: 'cabin', label: 'Inside light', options: ON_OFF },
];
export const TINTS: Option<Settings['tint']>[] = [
  { value: 'none', label: 'None' },
  { value: 'light', label: 'Light' },
  { value: 'dark', label: 'Dark' },
  { value: 'limo', label: 'Limo' },
];
export const INDICATORS: Option<Settings['indicators']>[] = [
  { value: 'off', label: 'Off' },
  { value: 'left', label: 'Left' },
  { value: 'right', label: 'Right' },
  { value: 'both', label: 'Both' },
];
export const DOORS: Option<number>[] = [
  { value: 0, label: 'Driver' },
  { value: 1, label: 'Passenger' },
  { value: 2, label: 'Rear left' },
  { value: 3, label: 'Rear right' },
  { value: 4, label: 'Hood' },
  { value: 5, label: 'Trunk' },
];

export const BACKGROUNDS: Option<Look['bg']>[] = [
  { value: 'solid', label: 'Colour' },
  { value: 'linear', label: 'Gradient' },
  { value: 'radial', label: 'Spotlight' },
  { value: 'studio', label: 'Studio' },
  { value: 'image', label: 'Picture' },
];
export const COLOUR_NAMES: Record<string, [string, string?]> = {
  solid: ['Colour'],
  linear: ['From', 'To'],
  radial: ['Middle', 'Edges'],
  studio: ['Wall', 'Floor'],
  image: ['Colour where the picture is see-through'],
};
export const WEATHER: Option[] = [
  { value: 'sunny', label: 'Sunny' },
  { value: 'clear', label: 'Clear' },
  { value: 'clouds', label: 'Cloudy' },
  { value: 'overcast', label: 'Overcast' },
  { value: 'foggy', label: 'Foggy' },
  { value: 'rain', label: 'Rain' },
];
export const FILTERS: Option[] = [
  { value: 'none', label: 'None' },
  { value: 'vivid', label: 'Vivid' },
  { value: 'faded', label: 'Faded' },
  { value: 'contrast', label: 'Contrast' },
  { value: 'dark', label: 'Dark' },
  { value: 'bw', label: 'Black and white' },
  { value: 'vignette', label: 'Dark corners' },
];

export const SHADOWS: Option<Look['shadowStyle']>[] = [
  { value: 'soft', label: 'Soft' },
  { value: 'contact', label: 'Grounded' },
  { value: 'cast', label: 'Cast' },
];

export const SKIES: Option<Settings['sky']>[] = [
  { value: 'sun', label: 'Sunny' },
  { value: 'soft', label: 'Soft' },
  { value: 'cloudy', label: 'Cloudy' },
];
export const GLOW_FROM: Option<Settings['glowFrom']>[] = [
  { value: 'around', label: 'Around' },
  { value: 'left', label: 'Left' },
  { value: 'right', label: 'Right' },
  { value: 'behind', label: 'Behind' },
  { value: 'above', label: 'Above' },
];

export const WEIGHTS: Option<number>[] = [
  { value: 400, label: 'Regular' },
  { value: 600, label: 'Bold' },
  { value: 800, label: 'Heavy' },
];
