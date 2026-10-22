<script lang="ts">
  import '../../styles/studio.css';
  import { studio } from '../../stores';
  import Icon from '../components/Icon.svelte';
  import Range from '../components/Range.svelte';
  import ColourPicker from '../components/ColourPicker.svelte';
  import { WEIGHTS } from './options';

  let { index }: { index: number } = $props();
  const text = $derived(studio.settings.texts[index]);
</script>

{#if text}
  <div class="tline lead">
    <input type="text" maxlength="40" value={text.t} placeholder="Type here" oninput={(e) => studio.editText(index, { t: (e.currentTarget as HTMLInputElement).value })} />
  </div>
  <div class="chiprow">
    <span>Add</span>
    <button type="button" class="chipbtn" onclick={() => studio.editText(index, { t: `${text.t}{name}` })}>Car name</button>
    <button type="button" class="chipbtn" onclick={() => studio.editText(index, { t: `${text.t}{model}` })}>Spawn code</button>
  </div>
  <div class="seg wide">
    {#each WEIGHTS as weight (weight.value)}
      <button type="button" class:on={text.weight === weight.value} onclick={() => studio.editText(index, { weight: weight.value })}>{weight.label}</button>
    {/each}
  </div>
  <ColourPicker label="Colour" value={text.colour} onchange={(colour) => studio.editText(index, { colour })} />
  <div class="sliders">
    <Range label="Size" value={text.size} min={2} max={30} step={0.5} text="{text.size}%" onchange={(size) => studio.editText(index, { size })} />
    <Range label="Letter spacing" value={text.spacing} min={0} max={40} onchange={(spacing) => studio.editText(index, { spacing })} />
    <Range label="Opacity" value={text.alpha} min={0} max={100} text="{text.alpha}%" onchange={(alpha) => studio.editText(index, { alpha })} />
  </div>
  <div class="prows">
    <div class="carrow">
      <span>Capitals</span>
      <div class="seg">
        <button type="button" class:on={!text.caps} onclick={() => studio.editText(index, { caps: false })}>Off</button>
        <button type="button" class:on={text.caps} onclick={() => studio.editText(index, { caps: true })}>On</button>
      </div>
    </div>
    <div class="carrow">
      <span>Place</span>
      <div class="seg">
        <button type="button" class:on={text.back} onclick={() => studio.editText(index, { back: true })}>Behind car</button>
        <button type="button" class:on={!text.back} onclick={() => studio.editText(index, { back: false })}>In front</button>
      </div>
    </div>
  </div>
  <div class="acts small">
    <button type="button" class="act" onclick={() => studio.editText(index, { x: 50 })}>Centre</button>
    <button type="button" class="act" disabled={studio.settings.texts.length >= 3} onclick={() => studio.copyText(index)}><Icon name="copy" />Copy</button>
    <button type="button" class="act del" onclick={() => studio.removeText(index)}><Icon name="trash" />Delete</button>
  </div>
{/if}
