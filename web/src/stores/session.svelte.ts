import type { OpenMessage } from './protocol';
import type { Block, Tab } from './types';

class Session {
  open = $state(false);
  block = $state<Block>(null);
  ace = $state('');
  accent = $state('#C3FF00');
  limitKb = $state(64);
  tab = $state<Tab>('vehicles');
  closed = $state(false);

  opened(message: OpenMessage) {
    this.open = true;
    this.block = message.block || null;
    this.ace = message.ace || '';
    this.accent = message.accent || '#C3FF00';
    this.limitKb = message.limitKb || 64;
    this.closed = false;
  }

  setClosed(closed: boolean) {
    this.closed = closed;
  }
}

export const session = new Session();
