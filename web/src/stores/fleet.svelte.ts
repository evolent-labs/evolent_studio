import { nui } from '../lib/nui';
import { queue } from './queue.svelte';
import { session } from './session.svelte';
import type { Filter, Status, Vehicle } from './types';

class Fleet {
  list = $state<Vehicle[]>([]);
  loading = $state(true);
  filter = $state<Filter>('all');
  search = $state('');
  sel = $state<Record<string, boolean>>({});
  addonOpen = $state(false);
  addonCode = $state('');
  addonErr = $state('');

  byId = $derived(new Map(this.list.map((vehicle) => [vehicle.id, vehicle])));
  counts = $derived.by(() => {
    const tally = { all: this.list.length, owned: 0, missing: 0, ready: 0, failed: 0 };

    for (const vehicle of this.list) {
      if (vehicle.owned > 0) tally.owned++;
      tally[vehicle.status]++;
    }

    return tally;
  });
  firstRun = $derived(!this.loading && this.list.length > 0 && this.counts.ready === 0);
  selected = $derived(Object.keys(this.sel).filter((id) => this.sel[id]));
  photos = $derived(
    this.list
      .filter((vehicle) => vehicle.status === 'ready')
      .sort((a, b) => (b.updatedAt || 0) - (a.updatedAt || 0)),
  );
  rows = $derived.by(() => {
    const term = this.search.trim().toLowerCase();

    return this.list.filter((vehicle) => {
      if (term && vehicle.name.toLowerCase().indexOf(term) < 0 && vehicle.id.indexOf(term) < 0) return false;

      const status = this.statusOf(vehicle);
      if (this.filter === 'owned') return vehicle.owned > 0;
      if (this.filter === 'missing') return status === 'missing' || status === 'queued' || status === 'shooting';
      if (this.filter === 'ready') return status === 'ready';
      if (this.filter === 'failed') return status === 'failed';
      return true;
    });
  });

  nameOf(id: string | undefined) {
    return (id && this.byId.get(id)?.name) || id || '';
  }

  statusOf(vehicle: Vehicle): Status {
    if (queue.active?.current === vehicle.id) return 'shooting';
    if (queue.queued.has(vehicle.id)) return 'queued';
    return vehicle.status;
  }

  toggle(id: string) {
    this.sel[id] = !this.sel[id];
    nui('preview', { model: id });
  }

  selectVisible(on: boolean) {
    for (const row of this.rows) this.sel[row.id] = on;
  }

  selectWhere(test: (vehicle: Vehicle) => boolean) {
    const sel: Record<string, boolean> = {};
    for (const vehicle of this.list) if (test(vehicle)) sel[vehicle.id] = true;
    this.sel = sel;
  }

  clearSel() {
    this.sel = {};
  }

  start() {
    const models = this.selected;
    if (!models.length || session.block) return;

    this.sel = {};
    nui('start', { models });
  }

  async addAddon() {
    const code = this.addonCode.trim().toLowerCase();
    const reply = await nui<{ ok: boolean; error?: string; id?: string; name?: string }>('addon', { model: code });
    if (!reply) return;

    if (!reply.ok || !reply.id) {
      this.addonErr = reply.error || `${code} is not a vehicle model on this server.`;
      return;
    }

    if (!this.byId.has(reply.id)) {
      this.list.push({ id: reply.id, name: reply.name || reply.id, owned: 0, status: 'missing' });
      this.list.sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
    }

    this.sel[reply.id] = true;
    this.search = reply.id;
    this.addonOpen = false;
    this.addonCode = '';
    nui('preview', { model: reply.id });
  }
}

export const fleet = new Fleet();
