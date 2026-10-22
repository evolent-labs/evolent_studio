<script lang="ts">
  import '../../styles/studio.css';
  import { studio } from '../../stores';
  import PhotoProps from './PhotoProps.svelte';
  import CameraProps from './CameraProps.svelte';
  import LightProps from './LightProps.svelte';
  import CarProps from './CarProps.svelte';
  import FloorProps from './FloorProps.svelte';
  import BackgroundProps from './BackgroundProps.svelte';
  import TextProps from './TextProps.svelte';
  import ImageProps from './ImageProps.svelte';

  const settings = $derived(studio.settings);
  const real = $derived(settings.place !== 'green');
  const layer = $derived(
    (real && (studio.layer === 'floor' || studio.layer.startsWith('text') || studio.layer.startsWith('img'))) || !studio.exists(studio.layer)
      ? 'bg' : studio.layer,
  );
  const textIndex = $derived(layer.startsWith('text') ? +layer.slice(4) : -1);
  const imageIndex = $derived(layer.startsWith('img') ? +layer.slice(3) : -1);
</script>

{#if layer === 'photo'}
  <PhotoProps />
{:else if settings.images[imageIndex]}
  <ImageProps index={imageIndex} />
{:else if layer === 'bg'}
  <BackgroundProps />
{:else if layer === 'floor'}
  <FloorProps />
{:else if layer === 'light'}
  <LightProps />
{:else if layer === 'camera'}
  <CameraProps />
{:else if layer === 'car'}
  <CarProps />
{:else if settings.texts[textIndex]}
  <TextProps index={textIndex} />
{/if}
