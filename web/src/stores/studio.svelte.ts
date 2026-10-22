import { nui } from '../lib/nui';
import type { Img, Look, Text } from '../lib/look';
import { angleOf, DEFAULTS, settingsOf } from './defaults';
import type { OpenMessage } from './protocol';
import { queue } from './queue.svelte';
import { shot } from './shot.svelte';
import type { Layer, Settings } from './types';

class Studio {
  settings = $state<Settings>({ ...DEFAULTS });
  defaults: Settings = { ...DEFAULTS };
  angle = $state<string | null>('front34');
  saved = $state(false);
  layer = $state<Layer>('bg');
  typing = $state(false);
  guideX = $state(false);
  guideY = $state(false);
  canUndo = $state(false);
  canRedo = $state(false);
  model = $state('');
  isAircraft = $state(false);
  face = $state(0);
  carError = $state('');
  #past: Settings[] = [];
  #future: Settings[] = [];
  #lastChange = 0;
  #was: Record<string, number> = {};

  opened(message: OpenMessage) {
    if (message.studio) this.settings = settingsOf(message.studio);
    if (message.defaults) this.defaults = settingsOf(message.defaults);

    this.angle = angleOf(this.settings);
    this.saved = false;
    this.typing = false;
    this.layer = 'photo';
    this.#past = [];
    this.#future = [];
    this.canUndo = this.canRedo = false;
  }

  exit() {
    const keep = this.#past.length > 0 && !this.saved;
    nui('close', keep ? { settings: $state.snapshot(this.settings) } : {});
  }

  get locked() {
    return shot.shooting !== null || queue.active?.status === 'running';
  }

  showCar(id: string) {
    this.carError = '';
    if (id && id !== this.model) nui('preview', { model: id });
  }

  replace(settings: Settings) {
    if (this.locked) return;

    this.remember();
    this.settings = settings;
    this.angle = angleOf(settings);
    this.saved = false;
    if (!this.exists(this.layer)) this.layer = 'bg';
    this.sendSettings();
  }

  reset() {
    shot.test = null;
    this.replace({ ...this.defaults });
  }

  save() {
    nui('save', { settings: $state.snapshot(this.settings) });
    this.saved = true;
  }

  #lastKey = '';

  remember(key = '') {
    const now = performance.now();

    if (now - this.#lastChange > 450 || !key || key !== this.#lastKey) {
      this.#past.push($state.snapshot(this.settings) as Settings);
      if (this.#past.length > 80) this.#past.shift();
      this.#future = [];
    }

    this.#lastChange = now;
    this.#lastKey = key;
    this.canUndo = this.#past.length > 0;
    this.canRedo = false;
  }

  #restore(from: Settings[], to: Settings[]) {
    if (this.locked) return;

    const settings = from.pop();
    if (!settings) return;

    to.push($state.snapshot(this.settings) as Settings);
    this.settings = settings;
    this.angle = angleOf(settings);
    this.#lastChange = 0;
    this.saved = false;
    this.canUndo = this.#past.length > 0;
    this.canRedo = this.#future.length > 0;
    if (!this.exists(this.layer)) this.layer = 'bg';
    this.sendSettings();
  }

  undo() {
    this.#restore(this.#past, this.#future);
  }

  redo() {
    this.#restore(this.#future, this.#past);
  }

  change(patch: Partial<Settings>, keepAngle = false) {
    if (this.locked) return;

    this.remember(Object.keys(patch).sort().join());
    this.settings = { ...this.settings, ...patch };

    const leavesBackdrop = patch.place && patch.place !== 'green';
    if (leavesBackdrop && (this.layer === 'floor' || this.layer.startsWith('text') || this.layer.startsWith('img'))) this.layer = 'bg';
    if (!keepAngle) this.angle = null;

    this.saved = false;
    this.sendSettings();
  }

  pickAngle(key: string, rot: number, height: number) {
    if (this.locked) return;

    this.remember();
    nui('camera:resetTurn');
    this.settings = { ...this.settings, rot, height };
    this.angle = key;
    this.saved = false;
    this.sendSettings();
  }

  #pending = false;

  sendSettings() {
    if (this.#pending) return;

    this.#pending = true;
    requestAnimationFrame(() => {
      this.#pending = false;
      nui('settings', { settings: $state.snapshot(this.settings) });
    });
  }

  toggleDoor(door: number) {
    const doors = this.settings.doors;
    const next = doors.includes(door) ? doors.filter((open) => open !== door) : [...doors, door];
    this.change({ doors: next }, true);
  }

  usePreset(look: Partial<Look>) {
    this.change(look, true);
  }

  setFrame(frame: Look['frame']) {
    const size = this.settings.carSize;
    const carSize = frame === 'fit' ? Math.min(100, Math.max(size, 90)) : Math.min(size, 80);
    this.change({ frame, carSize }, true);
  }

  addText() {
    const texts = this.settings.texts;
    if (texts.length >= 3) return;

    const first = texts.length === 0;
    const light = /^#[c-f]/i.test(this.settings.bgColourA) && this.settings.bg !== 'none';
    const colour = light ? '#16161a' : '#ffffff';
    const text: Text = first
      ? {
          t: '{name}',
          x: 50,
          y: 11,
          size: 9,
          colour,
          weight: 800,
          caps: true,
          spacing: 6,
          alpha: 100,
          back: true,
          on: true,
        }
      : {
          t: 'Your text',
          x: 50,
          y: texts.length === 1 ? 92 : 22,
          size: 4,
          colour,
          weight: 600,
          caps: false,
          spacing: 2,
          alpha: 80,
          back: false,
          on: true,
        };

    this.change({ texts: [...texts, text] }, true);
    this.layer = `text${texts.length}`;
  }

  showing(layer: Layer) {
    const settings = this.settings;

    if (layer === 'light') return settings.glow > 0;
    if (layer === 'floor') return settings.shadow > 0 || settings.reflect > 0;
    if (layer.startsWith('text')) return settings.texts[+layer.slice(4)]?.on !== false;
    if (layer.startsWith('img')) return settings.images[+layer.slice(3)]?.on !== false;
    return true;
  }

  exists(layer: Layer) {
    if (layer.startsWith('text')) return !!this.settings.texts[+layer.slice(4)];
    if (layer.startsWith('img')) return !!this.settings.images[+layer.slice(3)];
    return true;
  }

  toggleLayer(layer: Layer) {
    const settings = this.settings;
    const on = this.showing(layer);

    if (layer === 'light') {
      if (on) this.#was.glow = settings.glow;
      this.change({ glow: on ? 0 : this.#was.glow || 60 }, true);
    } else if (layer === 'floor') {
      if (on) {
        this.#was.shadow = settings.shadow;
        this.#was.reflect = settings.reflect;
      }

      const floor = on ? { shadow: 0, reflect: 0 } : { shadow: this.#was.shadow ?? 70, reflect: this.#was.reflect ?? 0 };
      this.change(floor, true);
    } else if (layer.startsWith('text')) {
      this.editText(+layer.slice(4), { on: !on });
    } else if (layer.startsWith('img')) {
      this.editImage(+layer.slice(3), { on: !on });
    }
  }

  addImage(src: string) {
    const images = this.settings.images;
    if (images.length >= 3) return;

    const image: Img = { src: src.trim(), x: 88, y: 12, size: 16, alpha: 100, back: false, on: true };
    this.change({ images: [...images, image] }, true);
    this.layer = `img${images.length}`;
  }

  editImage(i: number, patch: Partial<Img>) {
    this.change({ images: this.settings.images.map((image, n) => (n === i ? { ...image, ...patch } : image)) }, true);
  }

  removeImage(i: number) {
    this.change({ images: this.settings.images.filter((_, n) => n !== i) }, true);
    this.layer = 'bg';
  }

  copyImage(i: number) {
    const image = this.settings.images[i];
    if (!image || this.settings.images.length >= 3) return;

    this.change({ images: [...this.settings.images, { ...image, x: Math.max(0, image.x - 10) }] }, true);
    this.layer = `img${this.settings.images.length - 1}`;
  }

  editItem(layer: Layer, patch: { x?: number; y?: number; size?: number }) {
    if (layer.startsWith('text')) this.editText(+layer.slice(4), patch);
    else if (layer.startsWith('img')) this.editImage(+layer.slice(3), patch);
  }

  removeItem(layer: Layer) {
    if (layer.startsWith('text')) this.removeText(+layer.slice(4));
    else if (layer.startsWith('img')) this.removeImage(+layer.slice(3));
  }

  item(layer: Layer) {
    if (layer.startsWith('text')) return this.settings.texts[+layer.slice(4)] || null;
    if (layer.startsWith('img')) return this.settings.images[+layer.slice(3)] || null;
    return null;
  }

  editText(i: number, patch: Partial<Text>) {
    this.change({ texts: this.settings.texts.map((text, n) => (n === i ? { ...text, ...patch } : text)) }, true);
  }

  removeText(i: number) {
    this.change({ texts: this.settings.texts.filter((_, n) => n !== i) }, true);
    this.layer = 'bg';
    this.typing = false;
  }

  copyText(i: number) {
    const text = this.settings.texts[i];
    if (!text || this.settings.texts.length >= 3) return;

    this.change({ texts: [...this.settings.texts, { ...text, y: Math.min(100, text.y + 8) }] }, true);
    this.layer = `text${this.settings.texts.length - 1}`;
  }
}

export const studio = new Studio();
