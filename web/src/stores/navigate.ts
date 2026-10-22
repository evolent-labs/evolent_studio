import { gallery } from './gallery.svelte';
import { session } from './session.svelte';
import type { Tab } from './types';

export function go(tab: Tab) {
  const closed = session.tab === tab ? !session.closed : false;
  if (tab !== 'gallery') gallery.detail = null;
  session.tab = tab;
  session.setClosed(closed);
}
