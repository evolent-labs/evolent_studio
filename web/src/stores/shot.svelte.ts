import { nui } from '../lib/nui';
import { layerKb, paint, type Layers } from '../lib/photos';
import { gallery } from './gallery.svelte';
import { session } from './session.svelte';
import type { Test } from './types';

class Shot {
  test = $state<Test | null>(null);
  testing = $state(false);
  testError = $state('');
  shooting = $state<{ layer: number; model: string } | null>(null);

  clear() {
    this.test = null;
    this.shooting = null;
    this.testing = false;
    this.testError = '';
  }

  async take() {
    if (session.block || this.testing) return;

    this.testing = true;

    try {
      this.testError = '';

      const reply = await nui<{ ok: boolean; layers?: Layers; error?: string }>('test', {}, 60000);
      if (!reply?.ok || !reply.layers) {
        this.testError = reply?.error || 'The test shot did not work, try again.';
        return;
      }

      const kb = layerKb(reply.layers);
      const painted = await paint(`test:${Date.now()}`, reply.layers, gallery.primary, gallery.secondary);

      this.test = { image: painted.image, w: painted.width, h: painted.height, kb, big: kb > session.limitKb };
    } finally {
      this.testing = false;
    }
  }
}

export const shot = new Shot();
