<script lang="ts">
  import '../../styles/studio.css';
  import { studio, ANGLES } from '../../stores';
  import { onScreen, preview, type Rect, SHAPE_NAMES, sizeText } from '../../lib/look';

  let { zoom, left, right }: { zoom: number; left: number; right: number } = $props();
  const settings = $derived(studio.settings);
  const kind = $derived(studio.layer.startsWith('text') ? 'text' : studio.layer.startsWith('img') ? 'img' : '');
  const index = $derived(kind ? +studio.layer.slice(kind === 'text' ? 4 : 3) : -1);
  const item = $derived(studio.item(studio.layer));

  let box = $state<Rect | null>(null);
  let frame = $state<Rect | null>(null);

  const same = (a: Rect | null, b: Rect | null) => {
    if (a === b) return true;
    if (!a || !b) return false;
    return Math.abs(a.x - b.x) < 0.5 && Math.abs(a.y - b.y) < 0.5 && Math.abs(a.w - b.w) < 0.5 && Math.abs(a.h - b.h) < 0.5;
  };
  const toMenu = (rect: Rect) => ({ x: rect.x / zoom, y: rect.y / zoom, w: rect.w / zoom, h: rect.h / zoom });

  $effect(() => {
    let raf = 0;

    const loop = () => {
      const shown = preview.frame;
      const found = shown && kind ? preview.boxes.find((candidate) => candidate.kind === kind && candidate.i === index) : null;
      const nextBox = found && shown ? toMenu(onScreen(found, shown)) : null;
      const nextFrame = shown ? toMenu(shown) : null;

      if (!same(box, nextBox)) box = nextBox;
      if (!same(frame, nextFrame)) frame = nextFrame;

      raf = requestAnimationFrame(loop);
    };

    loop();

    return () => cancelAnimationFrame(raf);
  });

  function pull(event: PointerEvent, around: Rect, apply: (scale: number) => void) {
    event.stopPropagation();

    const el = event.currentTarget as HTMLElement;
    el.setPointerCapture(event.pointerId);

    const cx = (around.x + around.w / 2) * zoom;
    const cy = (around.y + around.h / 2) * zoom;
    const start = Math.hypot(event.clientX - cx, event.clientY - cy) || 1;

    el.onpointermove = (e) => apply(Math.hypot(e.clientX - cx, e.clientY - cy) / start);
    el.onpointerup = () => (el.onpointermove = el.onpointerup = null);
  }

  function sizeItem(event: PointerEvent) {
    if (!box || !item) return;

    const size = item.size;
    const layer = studio.layer;
    const most = kind === 'img' ? 100 : 30;

    pull(event, box, (scale) => {
      const next = Math.round(Math.max(2, Math.min(most, size * scale)) * 2) / 2;
      studio.editItem(layer, { size: next });
    });
  }

  function typed(el: HTMLInputElement) {
    el.focus();
    el.setSelectionRange(el.value.length, el.value.length);
  }

  function stopTyping(event: KeyboardEvent) {
    if (event.key !== 'Enter' && event.key !== 'Escape') return;

    event.stopPropagation();
    studio.typing = false;
  }

  const CORNERS = ['nw', 'ne', 'sw', 'se'];
</script>

{#if frame && studio.guideX}
  <i class="guide v" style="left:{frame.x + frame.w / 2}px;top:{frame.y}px;height:{frame.h}px"></i>
{/if}
{#if frame && studio.guideY}
  <i class="guide h" style="top:{frame.y + frame.h / 2}px;left:{frame.x}px;width:{frame.w}px"></i>
{/if}
{#if frame}
  <div class="photoedge" class:sel={studio.layer === 'photo'} style="left:{frame.x}px;top:{frame.y}px;width:{frame.w}px;height:{frame.h}px">
    <button type="button" class="photolabel" onclick={() => (studio.layer = 'photo')}>
      <span>{SHAPE_NAMES[settings.frame] || settings.frame}</span><span>{sizeText(settings, settings.width)}</span>
    </button>
  </div>
{/if}
{#if box && item}
  <div class="selbox" style="left:{box.x - 6}px;top:{box.y - 4}px;width:{box.w + 12}px;height:{box.h + 8}px">
    {#each CORNERS as corner (corner)}
      <span class="handle {corner}" onpointerdown={sizeItem}></span>
    {/each}
  </div>
  {#if studio.typing && kind === 'text'}
    <input class="typing" use:typed style="left:{box.x + box.w / 2}px;top:{box.y + box.h + 10}px" maxlength="40" value={settings.texts[index].t}
      oninput={(e) => studio.editText(index, { t: (e.currentTarget as HTMLInputElement).value })}
      onkeydown={stopTyping}
      onblur={() => (studio.typing = false)} />
  {/if}
{/if}

<div class="stagerow bottom" style="left:{left}px;width:{right - left}px">
  <div class="stagebar glass">
    {#each ANGLES as [key, label, rot, height] (key)}
      <button type="button" class="angle" class:on={studio.angle === key} onclick={() => studio.pickAngle(key, rot, height)}>{label}</button>
    {/each}
  </div>
</div>
