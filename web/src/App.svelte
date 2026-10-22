<script lang="ts">
  import { session, queue, fleet, shot, studio, go, LAYERS, type Layer, type Tab } from './stores';
  import { nui } from './lib/nui';
  import Icon from './views/components/Icon.svelte';
  import QueueStrip from './views/components/QueueStrip.svelte';
  import Vehicles from './views/pages/Vehicles.svelte';
  import Settings from './views/pages/Settings.svelte';
  import Gallery from './views/pages/Gallery.svelte';
  import QueuePage from './views/pages/QueuePage.svelte';
  import Backdrop from './views/studio/Backdrop.svelte';
  import Inspector from './views/studio/Inspector.svelte';
  import Stage from './views/studio/Stage.svelte';
  import TestCard from './views/studio/TestCard.svelte';
  import { onScreen, preview } from './lib/look';

  const inGame = typeof GetParentResourceName === 'function';

  let height = $state(innerHeight);
  let width = $state(innerWidth);
  const zoom = $derived(Math.max(0.85, height / 1080));
  const menuWidth = $derived(width / zoom);
  const menuHeight = $derived(height / zoom);

  function hexRgb(hex: string) {
    let digits = (hex || '#C3FF00').replace('#', '');
    if (digits.length === 3) digits = digits.split('').map((digit) => digit + digit).join('');

    const packed = parseInt(digits, 16);
    return [(packed >> 16) & 255, (packed >> 8) & 255, packed & 255];
  }

  const accentVars = $derived.by(() => {
    const [r, g, b] = hexRgb(session.accent);
    const lum = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255;
    const fg = lum > 0.55 ? '#0a0a0f' : '#ffffff';
    return `--ac:${session.accent};--acfg:${fg};--acs:rgba(${r},${g},${b},.08);--acb:rgba(${r},${g},${b},.25);--acx:rgba(${r},${g},${b},.35)`;
  });

  const TABS: [Tab, string, string][] = [
    ['vehicles', 'Vehicles', 'car'],
    ['studio', 'Studio', 'camera'],
    ['gallery', 'Gallery', 'grid'],
    ['queue', 'Queue', 'list'],
    ['settings', 'Settings', 'gear'],
  ];
  const TITLES: Record<Tab, string> = {
    vehicles: 'Vehicles',
    studio: 'Studio',
    gallery: 'Gallery',
    queue: 'Queue',
    settings: 'Settings',
  };

  const inStudio = $derived(session.tab === 'studio');
  const free = $derived.by(() => {
    if (session.closed) return { left: 92, right: menuWidth };
    return inStudio ? { left: 92, right: menuWidth - 24 - 320 } : { left: 738, right: menuWidth };
  });
  const centre = $derived((free.left + free.right) / 2);
  const backdrop = $derived(inGame && inStudio && studio.settings.place === 'green');

  const MIN_VIEW_ZOOM = 0.5;
  const MAX_VIEW_ZOOM = 2.5;
  let viewZoom = $state(1);

  const area = $derived({
    x: (free.left + 16) * zoom,
    y: 56 * zoom,
    w: (free.right - free.left - 32) * zoom,
    h: height - (56 + 84) * zoom,
  });

  $effect(() => {
    if (!session.open) return;

    const x = session.closed || backdrop ? 0 : (centre - menuWidth / 2) / menuWidth;
    const fit = session.closed || backdrop ? 1 : Math.max(1, (0.72 * menuWidth) / (free.right - free.left));
    const scale = backdrop || inScene ? fit : fit * viewZoom;
    nui('panel', { x, y: 0, scale });
  });

  const inScene = $derived(studio.settings.place !== 'green');

  type Mode = 'wait' | 'orbit' | 'move' | 'spin' | 'text' | 'place' | 'none';
  type Drag = {
    x: number;
    y: number;
    startX: number;
    startY: number;
    rot: number;
    height: number;
    mode: Mode;
    car?: boolean;
    last?: PointerEvent;
    layer?: Layer;
    grabX?: number;
    grabY?: number;
    placeX?: number;
    placeY?: number;
  };

  let drag: Drag | null = null;
  let dragMode = $state<Mode | null>(null);

  $effect(() => {
    if (!session.open) {
      drag = null;
      dragMode = null;
      viewZoom = 1;
    }
  });

  let overCar = $state(false);
  let overText = $state(false);

  const textAt = (event: MouseEvent) => {
    const frame = preview.frame;
    if (!preview.on || !frame) return null;

    for (let n = preview.boxes.length - 1; n >= 0; n--) {
      const box = onScreen(preview.boxes[n], frame);
      const isOverX = event.clientX >= box.x - 6 && event.clientX <= box.x + box.w + 6;
      const isOverY = event.clientY >= box.y - 4 && event.clientY <= box.y + box.h + 4;
      if (!isOverX || !isOverY) continue;

      const { kind, i } = preview.boxes[n];
      return { layer: `${kind}${i}` as Layer, kind, ...box };
    }

    return null;
  };

  const at = (event: MouseEvent) => ({ x: event.clientX / innerWidth, y: event.clientY / innerHeight });

  let moveFrame = 0;

  function moveCar(event: PointerEvent) {
    const point = at(event);
    if (moveFrame) return;

    moveFrame = requestAnimationFrame(() => {
      moveFrame = 0;
      nui('drag', point);
    });
  }

  async function down(event: PointerEvent) {
    if (event.button !== 0 && event.button !== 2) return;
    if (studio.locked) return;

    studio.typing = false;

    const button = event.button;
    const current: Drag = {
      x: event.clientX,
      y: event.clientY,
      startX: event.clientX,
      startY: event.clientY,
      rot: studio.settings.rot,
      height: studio.settings.height,
      mode: 'wait',
    };
    drag = current;
    dragMode = 'wait';
    (event.currentTarget as HTMLElement).setPointerCapture(event.pointerId);

    const box = button === 0 && inStudio ? textAt(event) : null;

    if (box) {
      studio.layer = box.layer;
      current.mode = dragMode = 'text';
      current.layer = box.layer;
      current.grabX = event.clientX - (box.x + box.w / 2);
      current.grabY = event.clientY - (box.y + box.h / 2);
      return;
    }

    if (button === 2 && backdrop && studio.settings.frame !== 'fit') {
      current.mode = dragMode = 'place';
      current.placeX = studio.settings.carDX;
      current.placeY = studio.settings.carDY;
      return;
    }

    const car = inScene && (await nui<{ car: boolean }>('grab', { ...at(event), button }))?.car;

    if (drag !== current) {
      if (car) nui('release');
      return;
    }

    current.car = !!car;
    current.mode = dragMode = car ? (button === 0 ? 'move' : 'spin') : button === 0 ? 'orbit' : 'none';
    if (current.last) move(current.last);
  }

  let hoverAt = 0;

  async function hover(event: PointerEvent) {
    overText = inStudio && !!textAt(event);
    if (!inScene || performance.now() < hoverAt) return;

    hoverAt = performance.now() + 120;
    overCar = !!(await nui<{ car: boolean }>('hover', at(event)))?.car;
  }

  const snap = (percent: number) => (Math.abs(percent - 50) < 1.6 ? 50 : Math.round(Math.max(0, Math.min(100, percent)) * 10) / 10);

  function move(event: PointerEvent) {
    if (!drag) return hover(event);

    if (drag.mode === 'wait') {
      drag.last = event;
      return;
    }

    const dx = (event.clientX - drag.x) / zoom;
    const dy = (event.clientY - drag.y) / zoom;
    drag.x = event.clientX;
    drag.y = event.clientY;

    if (drag.mode === 'move') return moveCar(event);

    if (drag.mode === 'text') {
      const frame = preview.frame;
      if (!frame || !drag.layer) return;

      const x = snap(((event.clientX - (drag.grabX || 0) - frame.x) / frame.w) * 100);
      const y = snap(((event.clientY - (drag.grabY || 0) - frame.y) / frame.h) * 100);
      studio.guideX = x === 50;
      studio.guideY = y === 50;
      return studio.editItem(drag.layer, { x, y });
    }

    if (drag.mode === 'place') {
      const frame = preview.frame;
      if (!frame) return;

      drag.placeX = Math.max(-60, Math.min(60, (drag.placeX || 0) + (dx * zoom * 100) / frame.w));
      drag.placeY = Math.max(-60, Math.min(60, (drag.placeY || 0) + (dy * zoom * 100) / frame.h));

      const carDX = Math.abs(drag.placeX) < 1.5 ? 0 : Math.round(drag.placeX * 10) / 10;
      const carDY = Math.abs(drag.placeY) < 1.5 ? 0 : Math.round(drag.placeY * 10) / 10;
      studio.guideX = carDX === 0;
      studio.guideY = carDY === 0 && studio.settings.carY === 50;
      if (carDX !== studio.settings.carDX || carDY !== studio.settings.carDY) studio.change({ carDX, carDY }, true);
      return;
    }

    if (drag.mode === 'spin') return dx && nui('spin', { by: dx * 0.6 });
    if (drag.mode !== 'orbit') return;

    drag.rot += dx * 0.5;
    drag.height = Math.max(-10, Math.min(45, drag.height + dy * 0.3));
    if (drag.rot > 180) drag.rot -= 360;
    if (drag.rot < -180) drag.rot += 360;

    const rot = Math.round(drag.rot * 10) / 10;
    const height = Math.round(drag.height * 10) / 10;
    if (rot !== studio.settings.rot || height !== studio.settings.height) studio.change({ rot, height });
  }

  function up(event: PointerEvent) {
    const ended = drag;
    if (ended && (ended.mode === 'move' || ended.mode === 'spin')) nui('release');

    drag = null;
    dragMode = null;
    studio.guideX = studio.guideY = false;

    if (!ended || !inStudio || ended.mode === 'text') return;
    if (Math.hypot(event.clientX - ended.startX, event.clientY - ended.startY) > 4) return;

    if (ended.car || preview.carAt(event.clientX, event.clientY)) {
      studio.layer = 'car';
      return;
    }

    const frame = preview.frame;
    const isInFrameX = !!frame && event.clientX >= frame.x && event.clientX <= frame.x + frame.w;
    const isInFrameY = !!frame && event.clientY >= frame.y && event.clientY <= frame.y + frame.h;
    if (inScene || (isInFrameX && isInFrameY)) studio.layer = 'bg';
  }

  function double(event: MouseEvent) {
    if (studio.locked) return;

    if (inStudio && textAt(event)?.kind === 'text') studio.typing = true;
    else if (inScene) nui('car:moveTo', at(event));
  }

  function wheel(event: WheelEvent) {
    if (!event.deltaY || studio.locked) return;

    if (backdrop) {
      const most = studio.settings.frame === 'fit' ? 100 : 150;
      const carSize = Math.max(40, Math.min(most, studio.settings.carSize + (event.deltaY > 0 ? -2 : 2)));
      if (carSize !== studio.settings.carSize) studio.change({ carSize }, true);
      return;
    }

    if (!inScene) {
      viewZoom = Math.max(MIN_VIEW_ZOOM, Math.min(MAX_VIEW_ZOOM, viewZoom * (event.deltaY > 0 ? 1.1 : 1 / 1.1)));
      return;
    }

    const distance = Math.max(50, Math.min(250, studio.settings.distance + (event.deltaY > 0 ? 5 : -5)));
    if (distance !== studio.settings.distance) studio.change({ distance }, true);
  }

  function key(event: KeyboardEvent) {
    if (!session.open) return;

    const target = event.target;
    const field = (target instanceof HTMLInputElement && target.type !== 'range') || target instanceof HTMLTextAreaElement;
    const pressed = event.key.toLowerCase();

    if (event.ctrlKey && (pressed === 'z' || pressed === 'y') && !field) {
      event.preventDefault();
      if (pressed === 'y' || event.shiftKey) studio.redo();
      else studio.undo();
      return;
    }

    if (event.key === 'Escape') {
      if (studio.typing) studio.typing = false;
      else if (field) (target as HTMLElement).blur();
      else studio.exit();
      return;
    }

    const item = studio.item(studio.layer);
    if (field || !inStudio || !item || inScene || target instanceof HTMLButtonElement) return;

    if (event.key === 'Delete' || event.key === 'Backspace') studio.removeItem(studio.layer);
    else if (event.key === 'Enter' && studio.layer.startsWith('text')) studio.typing = true;
    else if (event.key.startsWith('Arrow')) {
      event.preventDefault();

      const step = event.shiftKey ? 2 : 0.5;
      const dx = event.key === 'ArrowLeft' ? -step : event.key === 'ArrowRight' ? step : 0;
      const dy = event.key === 'ArrowUp' ? -step : event.key === 'ArrowDown' ? step : 0;
      const x = Math.max(0, Math.min(100, item.x + dx));
      const y = Math.max(0, Math.min(100, item.y + dy));
      studio.editItem(studio.layer, { x, y });
    }
  }
</script>

<svelte:window bind:innerHeight={height} bind:innerWidth={width} onkeydown={key} />

{#if session.open}
  {#if backdrop}<Backdrop {area} />{/if}
  <div class="vp" style="zoom:{zoom};width:{menuWidth}px;height:{menuHeight}px;{accentVars}">
    {#if session.block === 'noaccess'}
      <div class="dim deep"></div>
      <div class="dialog glass">
        <span class="icon"><Icon name="lock" /></span>
        <h2>No access</h2>
        <p>Your account needs this ace permission to open the menu.</p>
        <div class="ace"><span>{session.ace}</span></div>
        <button type="button" onclick={() => studio.exit()}>Close</button>
      </div>
    {:else}
      <div class="drag" class:dragging={dragMode === 'orbit'} class:oncar={overCar || overText || dragMode === 'move' || dragMode === 'text'}
        ondblclick={double} onpointerdown={down} onpointermove={move} onpointerup={up} onpointercancel={up} onlostpointercapture={up} onwheel={wheel}
        oncontextmenu={(e) => e.preventDefault()}></div>
      {#if !session.closed && !inStudio}<div class="dim"></div>{/if}
      {#if inStudio}<Stage {zoom} left={free.left} right={free.right} />{/if}
      {#if shot.shooting}
        {@const taking = shot.shooting}
        <div class="shoot" style="left:{free.left}px;width:{free.right - free.left}px">
          {#key taking.layer}{#if taking.layer <= 3}<i class="flash"></i>{/if}{/key}
          <div class="shootcard glass">
            <span class="lens"><Icon name="camera" /></span>
            <span class="shoottxt">
              <b>{taking.layer > 3 ? 'Putting the photo together' : 'Taking the photo'}</b>
              <span>{fleet.nameOf(taking.model) || taking.model}</span>
            </span>
            <span class="steps">
              {#each [1, 2, 3] as n (n)}<i class:done={n < taking.layer} class:now={n === taking.layer}></i>{/each}
            </span>
            <span class="what">{taking.layer > 3 ? 'Almost done' : `${taking.layer} of 3, ${LAYERS[taking.layer - 1]}`}</span>
          </div>
        </div>
      {/if}
      <div class="hints" class:left={inStudio && !session.closed}>
        <span class="mouse chipglass"><Icon name="mouse" /></span>
        {#if studio.locked}
          <span class="hint chipglass">Photos are being taken, the studio stays as it is. Pause the queue to change it.</span>
        {:else if inScene}
          <span class="hint chipglass">Drag the car to move it</span>
          <span class="hint chipglass">Right drag to turn it</span>
        {:else}
          <span class="hint chipglass">Drag to turn</span>
          <span class="hint chipglass">{backdrop ? 'Scroll to size the car' : 'Scroll to zoom'}</span>
          {#if backdrop && studio.settings.frame !== 'fit'}<span class="hint chipglass">Right drag to move the car</span>{/if}
        {/if}
        {#if inStudio && !studio.locked}<span class="hint chipglass">Click a part to change it</span>{/if}
      </div>
      {#if inStudio && shot.test}
        <div class="testfloat glass" style="left:{(free.left + free.right) / 2 - 240}px"><TestCard /></div>
      {/if}

      {#if !session.closed}
        {#if inStudio}
          <Inspector />
        {:else}
          <main class="panel glass">
            <header class="head">
              <div>
                <p class="eyebrow">Evolent Studio</p>
                <h1>{TITLES[session.tab]}</h1>
              </div>
              <button type="button" class="x" aria-label="Close" onclick={() => session.setClosed(true)}><Icon name="close" /></button>
            </header>
            {#if session.block === 'noresource'}
              <div class="banner">
                <Icon name="warn" />
                <div>
                  <b>Screenshot resource not running</b>
                  <span>Start screencapture or screenshot-basic on the server, then open /evstudio again.</span>
                </div>
              </div>
            {/if}
            {#if queue.state && session.tab !== 'queue'}<QueueStrip />{/if}
            {#if session.tab === 'vehicles'}<Vehicles />
            {:else if session.tab === 'gallery'}<Gallery />
            {:else if session.tab === 'settings'}<Settings />
            {:else}<QueuePage />{/if}
          </main>
        {/if}
      {/if}

      <nav class="nav glass">
        {#each TABS as [tab, label, icon] (tab)}
          <button type="button" class="tab" class:on={session.tab === tab && !session.closed} onclick={() => go(tab)}>
            <span class="ic">
              <Icon name={icon} />
              {#if tab === 'queue' && queue.state?.status === 'running'}<span class="pulse"></span>{/if}
            </span>
            <span class="lbl"><span>{label}</span></span>
          </button>
        {/each}
        <button type="button" class="tab exit" title="Close the menu (Esc)" onclick={() => studio.exit()}>
          <span class="ic"><Icon name="close" /></span>
          <span class="lbl"><span>Exit</span></span>
        </button>
      </nav>
    {/if}
  </div>
{/if}
