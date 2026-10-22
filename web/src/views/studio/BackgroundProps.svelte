<script lang="ts">
  import '../../styles/studio.css';
  import { library, studio, type Settings } from '../../stores';
  import { PRESETS, type Look } from '../../lib/look';
  import Icon from '../components/Icon.svelte';
  import Range from '../components/Range.svelte';
  import ColourPicker from '../components/ColourPicker.svelte';
  import PicturePick from './PicturePick.svelte';
  import { BACKGROUNDS, COLOUR_NAMES, FILTERS, WEATHER } from './options';

  const settings = $derived(studio.settings);
  const real = $derived(settings.place !== 'green');

  function css(look: Partial<Look>) {
    const first = look.bgColourA || '#f4f4f5';
    const second = look.bgColourB || '#a1a1aa';

    if (look.bg === 'solid') return first;
    if (look.bg === 'linear') return `linear-gradient(${look.bgAngle ?? 180}deg, ${first}, ${second})`;
    if (look.bg === 'radial') return `radial-gradient(circle at 50% 48%, ${first}, ${second} 75%)`;

    if (look.bg === 'studio') {
      const horizon = look.horizon ?? 66;
      return `linear-gradient(180deg, ${first} 0%, ${first} ${horizon - 6}%, ${second} ${horizon + 4}%, ${second} 100%)`;
    }

    return '';
  }

  const presetOn = (look: Partial<Look>) =>
    !real && Object.entries(look).every(([key, value]) => settings[key as keyof Settings] === value);
  const isOn = (place: string, id?: string) => settings.place === place && (id === undefined || settings.placeId === id);
  let placeName = $state('');
  let doomed = $state('');

  function usePreset(look: Partial<Look>) {
    if (real) library.pickPlace('green');
    studio.usePreset(look);
  }

  function deletePlace(id: string) {
    if (doomed !== id) {
      doomed = id;
      return;
    }

    library.removePlace(id);
    doomed = '';
  }

  function keepPlace() {
    library.savePlace(placeName);
    placeName = '';
  }
</script>

<span class="plab">Pick a background</span>
<div class="tiles">
  {#each PRESETS as [key, label, look] (key)}
    <button type="button" class="tile" class:on={presetOn(look)} onclick={() => usePreset(look)}>
      <span class="thumb" class:checker={look.bg === 'none'} style:background={css(look) || undefined}><Icon name="car" /></span>
      <span class="tname">{label}</span>
    </button>
  {/each}
  <button type="button" class="tile" class:on={real} onclick={() => !real && library.pickPlace('here')}>
    <span class="thumb place"><Icon name="pin" /></span>
    <span class="tname">Real place</span>
  </button>
</div>
{#if !real}
  <span class="plab">Make your own</span>
  <div class="seg wide">
    {#each BACKGROUNDS as kind (kind.value)}
      <button type="button" class:on={settings.bg === kind.value} onclick={() => studio.change({ bg: kind.value }, true)}>{kind.label}</button>
    {/each}
  </div>
  {#if settings.bg === 'image'}
    <PicturePick value={settings.bgImage} onpick={(bgImage) => studio.change({ bgImage }, true)} />
  {/if}
  {#if settings.bg !== 'none'}
    <ColourPicker label={COLOUR_NAMES[settings.bg][0]} value={settings.bgColourA} onchange={(bgColourA) => studio.change({ bgColourA }, true)} />
    {#if COLOUR_NAMES[settings.bg][1]}
      <ColourPicker label={COLOUR_NAMES[settings.bg][1] || ''} value={settings.bgColourB} onchange={(bgColourB) => studio.change({ bgColourB }, true)} />
    {/if}
    <div class="sliders">
      {#if settings.bg === 'linear'}
        <Range label="Direction" value={settings.bgAngle} min={0} max={360} text="{settings.bgAngle}°" onchange={(bgAngle) => studio.change({ bgAngle }, true)} />
      {/if}
      {#if settings.bg === 'studio'}
        <Range label="Where the floor starts" value={settings.horizon} min={30} max={90} text="{settings.horizon}%" onchange={(horizon) => studio.change({ horizon }, true)} />
      {/if}
      <Range label="Dark corners" value={settings.vignette} min={0} max={100} text="{settings.vignette}%" onchange={(vignette) => studio.change({ vignette }, true)} />
    </div>
  {/if}
{:else}
  <span class="plab">Where</span>
  <div class="opts two">
    <button type="button" class="opt" class:on={isOn('here')} onclick={() => library.pickPlace('here')}>Where you stood</button>
    {#each library.garages as garage (garage.id)}
      <button type="button" class="opt" class:on={isOn('garage', garage.id)} onclick={() => library.pickPlace('garage', garage.id)}>{garage.name}</button>
    {/each}
    {#each library.places as place (place.id)}
      <div class="placerow">
        <button type="button" class="opt" class:on={isOn('saved', place.id)} onclick={() => library.pickPlace('saved', place.id)}>{place.name}</button>
        <button type="button" class="sq stop" class:sure={doomed === place.id} aria-label="Delete place" title={doomed === place.id ? 'Click again to delete' : 'Delete'}
          onclick={() => deletePlace(place.id)}><Icon name="trash" /></button>
      </div>
    {/each}
  </div>
  <div class="saveplace">
    <input type="text" maxlength="32" placeholder="Keep this spot as..." bind:value={placeName} />
    <button type="button" class="second" disabled={!placeName.trim()} onclick={keepPlace}>Keep</button>
  </div>
  <div class="sliders">
    <Range label="Time of day" value={settings.hour} min={0} max={23} text="{String(settings.hour).padStart(2, '0')}:00" onchange={(hour) => studio.change({ hour }, true)} />
  </div>
  <span class="plab">Weather</span>
  <div class="opts three">
    {#each WEATHER as weather (weather.value)}
      <button type="button" class="opt" class:on={settings.weather === weather.value} onclick={() => studio.change({ weather: weather.value }, true)}>{weather.label}</button>
    {/each}
  </div>
  <div class="sliders">
    <Range label="Blur behind the car" value={settings.blur} min={0} max={100} text={settings.blur ? `${settings.blur}%` : 'Off'} onchange={(blur) => studio.change({ blur }, true)} />
  </div>
  <span class="plab">Colour filter</span>
  <div class="opts three">
    {#each FILTERS as filter (filter.value)}
      <button type="button" class="opt" class:on={settings.filter === filter.value} onclick={() => studio.change({ filter: filter.value }, true)}>{filter.label}</button>
    {/each}
  </div>
  {#if settings.filter !== 'none'}
    <div class="sliders">
      <Range label="Filter strength" value={settings.filterPower} min={0} max={100} text="{settings.filterPower}%" onchange={(filterPower) => studio.change({ filterPower }, true)} />
    </div>
  {/if}
{/if}
