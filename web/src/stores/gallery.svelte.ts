import { nui } from '../lib/nui';
import { SWATCHES } from './defaults';
import { session } from './session.svelte';

class Gallery {
  primary = $state(SWATCHES[0]);
  secondary = $state(SWATCHES[2]);
  search = $state('');
  detail = $state<string | null>(null);
  confirm = $state(false);

  sendColours() {
    nui('colours', { primary: this.primary, secondary: this.secondary });
  }

  setColour(which: 'primary' | 'secondary', hex: string) {
    this[which] = hex;
    this.sendColours();
  }

  retake(id: string) {
    if (session.block) return;
    nui('start', { models: [id] });
  }

  remove(id: string) {
    nui('delete', { model: id });
    this.confirm = false;
    this.detail = null;
  }
}

export const gallery = new Gallery();
