<script lang="ts">
  import '../../styles/studio.css';
  import { shot, studio } from '../../stores';
  import Icon from '../components/Icon.svelte';
  import Range from '../components/Range.svelte';
  import { CAR_SPOTS, OWN_SIDES, SHAPES, SIZES, signed, type Side } from './options';

  const settings = $derived(studio.settings);
  const real = $derived(settings.place !== 'green');

  const pixels = (value: number) => Math.max(128, Math.min(2048, Math.round(value)));
  let chained = $state(false);

  function setOwn(side: Side, value: number, ratio = settings.frameW / settings.frameH) {
    let w = side === 'frameW' ? pixels(value) : settings.frameW;
    let h = side === 'frameH' ? pixels(value) : settings.frameH;

    if (chained) {
      if (side === 'frameW') {
        h = pixels(w / ratio);
        if (h !== Math.round(w / ratio)) w = pixels(h * ratio);
      } else {
        w = pixels(h * ratio);
        if (w !== Math.round(h * ratio)) h = pixels(w / ratio);
      }
    }

    if (w === settings.frameW && h === settings.frameH) return;

    studio.change({ frameW: w, frameH: h }, true);
    shot.test = null;
  }

  function typeOwn(side: Side, e: Event) {
    const input = e.currentTarget as HTMLInputElement;
    setOwn(side, +input.value || settings[side]);
    input.value = String(settings[side]);
  }

  function scrub(side: Side, e: PointerEvent) {
    e.preventDefault();

    const el = e.currentTarget as HTMLElement;
    el.setPointerCapture(e.pointerId);

    const from = settings[side];
    const x = e.clientX;
    const ratio = settings.frameW / settings.frameH;

    el.onpointermove = (moved) => setOwn(side, from + (moved.clientX - x) * (moved.shiftKey ? 10 : 2), ratio);
    el.onpointerup = el.onpointercancel = () => (el.onpointermove = el.onpointerup = el.onpointercancel = null);
  }

  function pickWidth(width: number) {
    studio.change({ width }, true);
    shot.test = null;
  }
</script>

<span class="plab lead">Shape</span>
<div class="shapes">
  {#each SHAPES as shape (shape.value)}
    <button type="button" class="shape" class:on={settings.frame === shape.value} disabled={real} onclick={() => studio.setFrame(shape.value)}>
      <span class="sbox">
        {#if shape.w}<i style="width:{shape.w >= shape.h ? 30 : (30 * shape.w) / shape.h}px;height:{shape.w >= shape.h ? (30 * shape.h) / shape.w : 30}px"></i>{:else}<i class="fit"><Icon name="car" /></i>{/if}
      </span>
      <span class="tname">{shape.label}</span>
    </button>
  {/each}
  <button type="button" class="shape own" class:on={settings.frame === 'custom'} disabled={real} onclick={() => studio.setFrame('custom')}>
    <span class="sbox"><i class="dash" style="width:30px;height:{Math.max(8, Math.min(30, (30 * settings.frameH) / settings.frameW))}px"></i></span>
    <span class="tname">Your own size</span>
  </button>
</div>
{#if !real && settings.frame === 'custom'}
  <div class="sizerow">
    {#each OWN_SIDES as side, n (side.value)}
      {#if n}
        <button type="button" class="chain" class:on={chained} aria-label="Keep the shape" title={chained ? 'Width and height change together' : 'Change width and height together'}
          onclick={() => (chained = !chained)}><Icon name="link" /></button>
      {/if}
      <div class="sizebox">
        <span class="scrub" title="Drag left or right" onpointerdown={(e) => scrub(side.value, e)}>{side.label}</span>
        <input type="number" min="128" max="2048" step="1" aria-label={side.label} value={settings[side.value]} onchange={(e) => typeOwn(side.value, e)}
          onkeydown={(e) => { if (e.key === 'Enter') (e.currentTarget as HTMLInputElement).blur(); }} />
        <em>px</em>
      </div>
    {/each}
  </div>
  <p class="quiet">Type a size or drag the word Width or Height sideways, with Shift for bigger steps. From 128 to 2048 pixels each way. Much bigger than the car is on your screen and it gets soft.</p>
{/if}
{#if real}<p class="quiet">A photo in a real place is the whole screen, as you see it.</p>{/if}
{#if !real}
  <div class="sliders">
    <Range label="Car size" value={settings.carSize} min={40} max={settings.frame === 'fit' ? 100 : 150} text="{settings.carSize}%" onchange={(carSize) => studio.change({ carSize }, true)} />
  </div>
  {#if settings.frame !== 'fit'}
    <span class="plab">Car in the photo</span>
    <div class="opts three">
      {#each CAR_SPOTS as spot (spot.value)}
        <button type="button" class="opt" class:on={settings.carY === spot.value && !settings.carDY} onclick={() => studio.change({ carY: spot.value, carDY: 0 }, true)}>{spot.label}</button>
      {/each}
    </div>
    <div class="sliders">
      <Range label="Move sideways" value={settings.carDX} min={-60} max={60} text={settings.carDX ? signed(Math.round(settings.carDX), '%') : 'Centred'} onchange={(carDX) => studio.change({ carDX }, true)} />
      <Range label="Move up or down" value={settings.carDY} min={-60} max={60} text={settings.carDY ? signed(Math.round(settings.carDY), '%') : 'In place'} onchange={(carDY) => studio.change({ carDY }, true)} />
    </div>
    {#if settings.carDX || settings.carDY}
      <button type="button" class="ladd" onclick={() => studio.change({ carDX: 0, carDY: 0 }, true)}><Icon name="retake" />Car back to the centre</button>
    {/if}
    <p class="quiet">Or drag the car with the right mouse button. It can stick out of the photo, and it catches the centre line when it comes near.</p>
  {/if}
  <p class="quiet">Or scroll the mouse wheel on the photo. Every vehicle takes the same share of the photo, a boat or a bus no more than a car.</p>
{/if}
{#if real || settings.frame !== 'custom'}
  <span class="plab">Picture size</span>
  <div class="opts">
    {#each SIZES as size (size.value)}
      <button type="button" class="opt sized" class:on={settings.width === size.value} onclick={() => pickWidth(size.value)}><b>{size.label}</b><span>{size.value} px</span></button>
    {/each}
  </div>
{/if}
<span class="plab">Colour</span>
<div class="sliders lead">
  <Range label="Brightness" value={settings.bright} min={-50} max={50} text={signed(settings.bright, '')} onchange={(bright) => studio.change({ bright }, true)} />
  <Range label="Contrast" value={settings.contrast} min={-50} max={50} text={signed(settings.contrast, '')} onchange={(contrast) => studio.change({ contrast }, true)} />
  <Range label="Colour strength" value={settings.saturation} min={-50} max={50} text={signed(settings.saturation, '')} onchange={(saturation) => studio.change({ saturation }, true)} />
  <Range label="Warm or cold" value={settings.warm} min={-50} max={50} text={settings.warm > 0 ? `Warm ${settings.warm}` : settings.warm < 0 ? `Cold ${-settings.warm}` : '0'} onchange={(warm) => studio.change({ warm }, true)} />
</div>
{#if !real}
  <div class="sliders">
    <Range label="Clean the green edge" value={settings.edge} min={0} max={100} text={settings.edge ? `${settings.edge}%` : 'Off'} onchange={(edge) => studio.change({ edge }, true)} />
  </div>
{/if}
{#if settings.bright || settings.contrast || settings.saturation || settings.warm}
  <button type="button" class="ladd" onclick={() => studio.change({ bright: 0, contrast: 0, saturation: 0, warm: 0 }, true)}><Icon name="retake" />Colour back to normal</button>
{/if}
