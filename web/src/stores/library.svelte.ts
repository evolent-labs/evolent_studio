import { nui } from '../lib/nui';
import { listOf, settingsOf } from './defaults';
import type { OpenMessage, PlacesMessage, StylesMessage } from './protocol';
import { studio } from './studio.svelte';
import type { Garage, Place, SavedPlace, Settings, Style } from './types';

class Library {
  pictures = $state<string[]>([]);
  styles = $state<Style[]>([]);
  style = $state('');
  garages = $state<Garage[]>([]);
  places = $state<SavedPlace[]>([]);

  opened(message: OpenMessage) {
    this.garages = listOf<Garage>(message.garages);
    this.pictures = listOf<string>(message.images);
    this.styles = listOf<Style>(message.styles);
    this.places = listOf<SavedPlace>(message.places);
    this.style = '';
  }

  saveStyle(name: string) {
    const settings = $state.snapshot(studio.settings) as Partial<Settings>;
    nui('style', { name: name.trim(), id: this.style || undefined, settings, fresh: !this.style });
  }

  saveNewStyle(name: string) {
    nui('style', { name: name.trim(), settings: $state.snapshot(studio.settings), fresh: true });
  }

  useStyle(style: Style) {
    studio.replace(settingsOf({ ...style.settings }));
    this.style = style.id;
  }

  removeStyle(id: string) {
    nui('styles:delete', { id });
    if (this.style === id) this.style = '';
  }

  gotStyles(message: StylesMessage) {
    this.styles = listOf<Style>(message.styles);
    if (message.added) this.style = message.added;
  }

  pickPlace(place: Place, id?: string) {
    const saved = place === 'saved' ? this.places.find((entry) => entry.id === id) : undefined;
    const time = saved
      ? { hour: saved.hour ?? studio.settings.hour, weather: saved.weather ?? studio.settings.weather }
      : {};

    studio.change({ place, placeId: id, ...time }, true);
  }

  savePlace(name: string) {
    nui('place', { name });
  }

  removePlace(id: string) {
    nui('places:delete', { id });
  }

  gotPlaces(message: PlacesMessage) {
    this.places = listOf<SavedPlace>(message.places);

    if (message.added) {
      studio.change({ place: 'saved', placeId: message.added }, true);
      return;
    }

    if (studio.settings.place !== 'saved') return;
    if (this.places.some((entry) => entry.id === studio.settings.placeId)) return;

    studio.change({ place: 'green', placeId: undefined }, true);
  }
}

export const library = new Library();
