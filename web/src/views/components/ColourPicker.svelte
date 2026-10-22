<script lang="ts" module>
  let openId = $state('');
  let next = 0;
</script>

<script lang="ts">
  import '../../styles/studio.css';
  import { untrack } from 'svelte';
  let { label, value, onchange }: { label: string; value: string; onchange: (hex: string) => void } = $props();
  const id = `c${next++}`;
  const QUICK = [
    '#ffffff',
    '#d4d4d8',
    '#71717a',
    '#16161a',
    '#e11d2a',
    '#f59e0b',
    '#22c55e',
    '#00bfff',
    '#1d4ed8',
    '#7c3aed',
  ];
  const open = $derived(openId === id);
  const custom = $derived(!QUICK.includes(value.toLowerCase()));

  function toHsv(hex: string) {
    const packed = parseInt(hex.replace('#', ''), 16) || 0;
    const r = ((packed >> 16) & 255) / 255;
    const g = ((packed >> 8) & 255) / 255;
    const b = (packed & 255) / 255;
    const max = Math.max(r, g, b);
    const range = max - Math.min(r, g, b);

    let sector = 0;
    if (range) sector = max === r ? ((g - b) / range) % 6 : max === g ? (b - r) / range + 2 : (r - g) / range + 4;

    return [((sector * 60) + 360) % 360, max ? range / max : 0, max];
  }

  function toHex(hue: number, sat: number, val: number) {
    const channel = (offset: number) => {
      const sector = (offset + hue / 60) % 6;
      return Math.round((val - val * sat * Math.max(0, Math.min(sector, 4 - sector, 1))) * 255);
    };

    return '#' + [channel(5), channel(3), channel(1)].map((level) => level.toString(16).padStart(2, '0')).join('');
  }

  let hue = $state(0);
  let sat = $state(0);
  let val = $state(0);
  let text = $state('');

  $effect(() => {
    const hex = value.toLowerCase();
    untrack(() => {
      if (hex !== toHex(hue, sat, val)) [hue, sat, val] = toHsv(hex);
    });
    text = value.toUpperCase();
  });

  function set(newHue: number, newSat: number, newVal: number) {
    hue = newHue;
    sat = newSat;
    val = newVal;
    onchange(toHex(newHue, newSat, newVal));
  }

  function track(event: PointerEvent, move: (x: number, y: number) => void) {
    const el = event.currentTarget as HTMLElement;
    el.setPointerCapture(event.pointerId);

    const at = (e: PointerEvent) => {
      const rect = el.getBoundingClientRect();
      const x = Math.max(0, Math.min(1, (e.clientX - rect.left) / rect.width));
      const y = Math.max(0, Math.min(1, (e.clientY - rect.top) / rect.height));
      move(x, y);
    };

    at(event);
    el.onpointermove = at;
    el.onpointerup = () => (el.onpointermove = el.onpointerup = null);
  }

  function typed(input: string) {
    text = input;

    const hex = input.trim().replace(/^#?/, '#');
    if (/^#[0-9a-f]{6}$/i.test(hex)) onchange(hex.toLowerCase());
  }
</script>

<div class="cp">
  {#if label}<span class="cplab">{label}</span>{/if}
  <div class="swrow">
    {#each QUICK as quick (quick)}
      <button type="button" aria-label={quick} style:background={quick} class:on={value.toLowerCase() === quick} onclick={() => onchange(quick)}></button>
    {/each}
    <button type="button" class="more" class:on={custom || open} aria-label="More colours" style:--pick={value}
      onclick={() => (openId = open ? '' : id)}></button>
  </div>
  {#if open}
    <div class="picker">
      <div class="sv" style:background-color={toHex(hue, 1, 1)} onpointerdown={(e) => track(e, (x, y) => set(hue, x, 1 - y))}>
        <i style:left="{sat * 100}%" style:top="{(1 - val) * 100}%"></i>
      </div>
      <div class="hue" onpointerdown={(e) => track(e, (x) => set(x * 359, sat, val))}>
        <i style:left="{(hue / 359) * 100}%"></i>
      </div>
      <div class="pickfoot">
        <span class="now" style:background={value}></span>
        <input type="text" maxlength="7" value={text} oninput={(e) => typed((e.currentTarget as HTMLInputElement).value)} />
        <button type="button" class="done" onclick={() => (openId = '')}>Done</button>
      </div>
    </div>
  {/if}
</div>
