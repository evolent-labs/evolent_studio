<script lang="ts">
  import '../../styles/studio.css';
  import { studio, ANGLES } from '../../stores';
  import Range from '../components/Range.svelte';
  import { signed } from './options';

  const settings = $derived(studio.settings);
  const real = $derived(settings.place !== 'green');
  const minDistance = $derived(real ? 50 : 100);
  const distance = $derived(Math.max(minDistance, settings.distance));
</script>

<span class="plab lead">Angle</span>
<div class="opts three">
  {#each ANGLES as [key, label, rot, height] (key)}
    <button type="button" class="opt" class:on={studio.angle === key} onclick={() => studio.pickAngle(key, rot, height)}>{label}</button>
  {/each}
</div>
<div class="sliders">
  <Range label="Around the car" value={Math.round(settings.rot)} min={-180} max={180} text="{Math.round(settings.rot)}°" onchange={(rot) => studio.change({ rot })} />
  <Range label="Height" value={Math.round(settings.height)} min={-10} max={45} text="{Math.round(settings.height)}°" onchange={(height) => studio.change({ height })} />
  <Range label="Distance" value={distance} min={minDistance} max={250} text="{distance}%" onchange={(distance) => studio.change({ distance }, true)} />
  <Range label="Lens" value={settings.fov} min={20} max={80} text={settings.fov < 34 ? 'Long' : settings.fov > 55 ? 'Wide' : 'Normal'} onchange={(fov) => studio.change({ fov }, true)} />
  {#if real}
    <Range label="Move sideways" value={settings.shiftX} min={-50} max={50} text={signed(settings.shiftX, '%')} onchange={(shiftX) => studio.change({ shiftX }, true)} />
    <Range label="Move up or down" value={settings.shiftY} min={-50} max={50} text={signed(settings.shiftY, '%')} onchange={(shiftY) => studio.change({ shiftY }, true)} />
  {/if}
</div>
