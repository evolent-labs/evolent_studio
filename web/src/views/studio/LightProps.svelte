<script lang="ts">
  import '../../styles/studio.css';
  import { studio } from '../../stores';
  import Icon from '../components/Icon.svelte';
  import Range from '../components/Range.svelte';
  import ColourPicker from '../components/ColourPicker.svelte';
  import { GLOW_FROM, SKIES } from './options';

  const settings = $derived(studio.settings);
  const real = $derived(settings.place !== 'green');
</script>

{#if !real}
  <span class="plab lead">Daylight</span>
  <div class="opts three">
    {#each SKIES as sky (sky.value)}
      <button type="button" class="opt" class:on={settings.sky === sky.value} onclick={() => studio.change({ sky: sky.value }, true)}>{sky.label}</button>
    {/each}
  </div>
  <p class="quiet">Soft has no hard sun glints on the paint.</p>
  <div class="sliders">
    <Range label="Sun position" value={settings.sun} min={6} max={20} text={settings.sun < 10 ? 'Morning' : settings.sun > 16 ? 'Evening' : 'Midday'} onchange={(sun) => studio.change({ sun }, true)} />
  </div>
{/if}
<span class="plab" class:lead={real}>Shine on the car</span>
<div class="sliders">
  <Range label="Reflections" value={settings.shine} min={0} max={100} text={settings.shine === 100 ? 'As in the game' : settings.shine ? `${settings.shine}%` : 'None'} onchange={(shine) => studio.change({ shine }, true)} />
  {#if !real}
    <Range label="Sun" value={settings.sunPower} min={0} max={100} text={settings.sunPower === 100 ? 'Full' : settings.sunPower ? `${settings.sunPower}%` : 'No sun'} onchange={(sunPower) => studio.change({ sunPower }, true)} />
  {/if}
</div>
<p class="quiet">Reflections is the sky and the world mirrored in the paint and glass. {real ? '' : 'Less sun takes its bright glints away and lights the car evenly. '}Handy when the background is a picture the game's sky does not fit.</p>
{#if settings.shine < 100 || settings.sunPower < 100}
  <button type="button" class="ladd" onclick={() => studio.change({ shine: 100, sunPower: 100 }, true)}><Icon name="retake" />Shine back to normal</button>
{/if}
<span class="plab">Colour light</span>
<div class="sliders">
  <Range label="Strength" value={settings.glow} min={0} max={100} text={settings.glow ? `${settings.glow}%` : 'Off'} onchange={(glow) => studio.change({ glow }, true)} />
</div>
<ColourPicker label="Colour" value={settings.glowColour} onchange={(glowColour) => studio.change({ glowColour, glow: settings.glow || 60 }, true)} />
<span class="plab">Shines from</span>
<div class="seg wide">
  {#each GLOW_FROM as side (side.value)}
    <button type="button" class:on={settings.glowFrom === side.value} onclick={() => studio.change({ glowFrom: side.value, glow: settings.glow || 60 }, true)}>{side.label}</button>
  {/each}
</div>
<p class="quiet">{real ? 'Colours the car and the walls, floor and ceiling around it.' : 'Colours the car.'}</p>
