import { useLook } from '../lib/photos';
import { fleet } from './fleet.svelte';
import { studio } from './studio.svelte';
import type { Settings } from './types';

useLook((model) => ({ look: $state.snapshot(studio.settings) as Settings, name: fleet.nameOf(model) }));
