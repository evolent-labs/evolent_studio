<script lang="ts">
  import '../../styles/studio.css';
  import { studio } from '../../stores';
  import Range from '../components/Range.svelte';
  import { SHADOWS } from './options';

  const settings = $derived(studio.settings);
</script>

<span class="plab lead">Shadow</span>
<div class="opts three">
  {#each SHADOWS as shadow (shadow.value)}
    <button type="button" class="opt" class:on={settings.shadowStyle === shadow.value} onclick={() => studio.change({ shadowStyle: shadow.value, shadow: settings.shadow || 70 }, true)}>{shadow.label}</button>
  {/each}
</div>
<div class="sliders">
  <Range label="Shadow strength" value={settings.shadow} min={0} max={100} text={settings.shadow ? `${settings.shadow}%` : 'Off'} onchange={(shadow) => studio.change({ shadow }, true)} />
  {#if settings.shadow}
    <Range label="Shadow softness" value={settings.shadowSoft} min={0} max={100} text="{settings.shadowSoft}%" onchange={(shadowSoft) => studio.change({ shadowSoft }, true)} />
    <Range label="Shadow width" value={settings.shadowWide} min={50} max={150} text="{settings.shadowWide}%" onchange={(shadowWide) => studio.change({ shadowWide }, true)} />
  {/if}
  <Range label="Mirror floor" value={settings.reflect} min={0} max={100} text={settings.reflect ? `${settings.reflect}%` : 'Off'} onchange={(reflect) => studio.change({ reflect }, true)} />
  {#if settings.reflect}
    <Range label="Mirror reach" value={settings.reflectReach} min={10} max={100} text={settings.reflectReach < 35 ? 'Short' : settings.reflectReach > 70 ? 'Long' : 'Medium'} onchange={(reflectReach) => studio.change({ reflectReach }, true)} />
    <Range label="Mirror blur" value={settings.reflectBlur} min={0} max={100} text={settings.reflectBlur ? `${settings.reflectBlur}%` : 'Sharp'} onchange={(reflectBlur) => studio.change({ reflectBlur }, true)} />
  {/if}
</div>
