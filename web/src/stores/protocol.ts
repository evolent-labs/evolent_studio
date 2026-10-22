import type { Block, Garage, Queue, SavedPlace, Settings, Style, Upload, Vehicle } from './types';

export type OpenMessage = {
  type: 'open';
  block?: Block;
  ace?: string;
  accent?: string;
  limitKb?: number;
  studio?: Partial<Settings>;
  defaults?: Partial<Settings>;
  garages?: Garage[];
  images?: string[];
  styles?: Style[];
  places?: SavedPlace[];
  upload?: Upload;
  queue?: Queue | null;
};
export type RowMessage = {
  type: 'row';
  id: string;
  status: Vehicle['status'];
  error?: string;
  updatedAt?: number;
  sizeKb?: number;
};
export type StylesMessage = { type: 'styles'; styles?: Style[]; added?: string };
export type PlacesMessage = { type: 'places'; places?: SavedPlace[]; added?: string };

export type NuiMessage =
  | OpenMessage
  | { type: 'close' }
  | { type: 'shooting'; on?: boolean; layer?: number; model?: string }
  | { type: 'vehicles'; list?: Vehicle[] }
  | RowMessage
  | { type: 'upload'; upload?: Upload }
  | { type: 'queue'; queue?: Queue | null }
  | { type: 'spot'; h?: number }
  | StylesMessage
  | { type: 'model'; model?: string; isAircraft?: boolean }
  | { type: 'nocar'; model?: string; error?: string }
  | PlacesMessage;

export type MessageOf<Type extends NuiMessage['type']> = Extract<NuiMessage, { type: Type }>;
