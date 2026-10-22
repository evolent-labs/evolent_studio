<script lang="ts">
  import '../../styles/studio.css';
  import { studio } from '../../stores';
  import Icon from '../components/Icon.svelte';
  import Range from '../components/Range.svelte';
  import PicturePick from './PicturePick.svelte';

  let { index }: { index: number } = $props();
  const image = $derived(studio.settings.images[index]);
</script>

{#if image}
  <PicturePick value={image.src} onpick={(src) => studio.editImage(index, { src })} />
  <div class="sliders">
    <Range label="Size" value={image.size} min={2} max={100} text="{image.size}%" onchange={(size) => studio.editImage(index, { size })} />
    <Range label="Opacity" value={image.alpha} min={0} max={100} text="{image.alpha}%" onchange={(alpha) => studio.editImage(index, { alpha })} />
  </div>
  <div class="prows">
    <div class="carrow">
      <span>Place</span>
      <div class="seg">
        <button type="button" class:on={image.back} onclick={() => studio.editImage(index, { back: true })}>Behind car</button>
        <button type="button" class:on={!image.back} onclick={() => studio.editImage(index, { back: false })}>In front</button>
      </div>
    </div>
  </div>
  <div class="acts small">
    <button type="button" class="act" onclick={() => studio.editImage(index, { x: 50 })}>Centre</button>
    <button type="button" class="act" disabled={studio.settings.images.length >= 3} onclick={() => studio.copyImage(index)}><Icon name="copy" />Copy</button>
    <button type="button" class="act del" onclick={() => studio.removeImage(index)}><Icon name="trash" />Delete</button>
  </div>
{/if}
