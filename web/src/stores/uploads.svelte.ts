import { nui } from '../lib/nui';
import { layersFor, paint } from '../lib/photos';
import { SWATCHES } from './defaults';
import { fleet } from './fleet.svelte';
import { session } from './session.svelte';
import type { Upload } from './types';

const STOPS = /key|webhook|Settings|busy|folder/i;

class Uploads {
  config = $state<Upload>({
    service: 'off',
    auto: false,
    format: 'webp',
    primary: SWATCHES[0],
    secondary: SWATCHES[2],
    hasToken: false,
  });
  progress = $state<{ done: number; total: number } | null>(null);
  error = $state('');

  get ready() {
    return this.config.service !== 'off' && this.config.hasToken;
  }

  use(config: unknown) {
    if (config && typeof config === 'object') this.config = config as Upload;
  }

  set(patch: Partial<Upload>) {
    this.config = { ...this.config, ...patch };
    this.error = '';
    nui('uploadSettings', patch);
  }

  async one(id: string) {
    const vehicle = fleet.byId.get(id);
    if (!vehicle || vehicle.status !== 'ready') return 'No photo';

    const layers = await layersFor(id, vehicle.updatedAt);
    if (!layers) return 'The photo could not be read';

    const { primary, secondary, format } = this.config;
    const painted = await paint(`${id}:${vehicle.updatedAt ?? 0}`, layers, primary, secondary, format);
    const reply = await nui<{ ok: boolean; url?: string; error?: string }>(
      'upload',
      { model: id, image: painted.image },
      70000,
    );

    if (reply?.ok && reply.url) {
      vehicle.url = reply.url;
      return '';
    }

    this.error = `${vehicle.name}: ${reply?.error || 'could not be uploaded'}`;
    return reply?.error || 'failed';
  }

  async all(again: boolean) {
    if (this.progress) return;

    const list = fleet.photos.filter((photo) => again || !photo.url);
    this.progress = { done: 0, total: list.length };
    this.error = '';

    try {
      for (const photo of list) {
        if (!session.open) break;

        const why = await this.one(photo.id);
        if (why && STOPS.test(why)) break;

        this.progress = { done: this.progress.done + 1, total: list.length };
        if (this.config.service === 'discord') await new Promise((done) => setTimeout(done, 1500));
      }
    } finally {
      this.progress = null;
    }
  }
}

export const uploads = new Uploads();
