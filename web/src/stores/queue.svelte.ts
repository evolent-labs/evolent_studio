import { nui } from '../lib/nui';
import type { Queue } from './types';

class QueueStore {
  state = $state<Queue | null>(null);
  active = $derived(this.state && this.state.status !== 'done' ? this.state : null);
  queued = $derived(new Set(this.active ? this.active.list : []));

  act(action: 'pause' | 'resume' | 'stop' | 'retry' | 'dismiss') {
    nui('queue', { action });
  }
}

export const queue = new QueueStore();
