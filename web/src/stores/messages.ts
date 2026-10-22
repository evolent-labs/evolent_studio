import { queueOf } from './defaults';
import { fleet } from './fleet.svelte';
import { gallery } from './gallery.svelte';
import { library } from './library.svelte';
import type { MessageOf, NuiMessage, RowMessage } from './protocol';
import { queue } from './queue.svelte';
import { session } from './session.svelte';
import { shot } from './shot.svelte';
import { studio } from './studio.svelte';
import { uploads } from './uploads.svelte';

function row(message: RowMessage) {
  const vehicle = fleet.byId.get(message.id);
  if (vehicle && message.status === 'failed' && vehicle.status === 'ready' && vehicle.updatedAt) {
    vehicle.error = message.error || undefined;
  } else if (vehicle) {
    vehicle.status = message.status;
    vehicle.error = message.error || undefined;
    vehicle.url = undefined;
    if (message.status === 'ready') {
      vehicle.updatedAt = message.updatedAt;
      vehicle.sizeKb = message.sizeKb;
      if (uploads.config.auto && uploads.ready) uploads.one(message.id);
    } else {
      vehicle.updatedAt = vehicle.sizeKb = undefined;
    }
  }
  if (message.status === 'missing' && gallery.detail === message.id) gallery.detail = null;
}

const HANDLERS: { [Type in NuiMessage['type']]: (message: MessageOf<Type>) => void } = {
  open(message) {
    session.opened(message);
    fleet.loading = true;
    studio.opened(message);
    library.opened(message);
    uploads.use(message.upload);
    uploads.error = '';
    queue.state = queueOf(message.queue);
    shot.clear();
    gallery.sendColours();
  },
  close() {
    shot.shooting = null;
    session.open = false;
  },
  shooting(message) {
    shot.shooting = message.on ? { layer: message.layer || 1, model: message.model || '' } : null;
  },
  vehicles(message) {
    fleet.list = message.list || [];
    fleet.loading = false;
  },
  row,
  upload(message) {
    uploads.use(message.upload);
  },
  queue(message) {
    queue.state = queueOf(message.queue);
  },
  spot(message) {
    studio.face = Math.round(message.h || 0);
  },
  styles(message) {
    library.gotStyles(message);
  },
  model(message) {
    studio.isAircraft = !!message.isAircraft;
    studio.model = message.model || '';
    studio.carError = '';
  },
  nocar(message) {
    studio.carError = `${message.model}: ${message.error || 'could not be shown'}`;
  },
  places(message) {
    library.gotPlaces(message);
  },
};

const KNOWN = new Set(Object.keys(HANDLERS));

export function isNuiMessage(data: unknown): data is NuiMessage {
  if (!data || typeof data !== 'object') return false;
  const type = (data as { type?: unknown }).type;
  return typeof type === 'string' && KNOWN.has(type);
}

export function receive(message: NuiMessage) {
  const handle = HANDLERS[message.type] as (message: NuiMessage) => void;
  handle(message);
}
