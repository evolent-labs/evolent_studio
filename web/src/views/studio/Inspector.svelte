<script lang="ts">
  import '../../styles/studio.css';
  import { session, fleet, shot, studio, library, type Layer } from '../../stores';
  import { PRESETS, SHAPE_NAMES, sizeText, type Look } from '../../lib/look';
  import Icon from '../components/Icon.svelte';
  import LayerProps from './LayerProps.svelte';

  const settings = $derived(studio.settings);
  let props: HTMLDivElement;

  $effect(() => {
    studio.layer;
    if (props) props.scrollTop = 0;
  });

  const real = $derived(settings.place !== 'green');
  const presetOf = (look: Look) =>
    PRESETS.find(([, , preset]) => Object.entries(preset).every(([key, value]) => look[key as keyof Look] === value))?.[1];
  const KINDS = {
    none: 'See-through',
    solid: 'Colour',
    linear: 'Gradient',
    radial: 'Spotlight',
    studio: 'Studio',
    image: 'Picture',
  } as const;
  const SKIES = { sun: 'Sunny', soft: 'Soft', cloudy: 'Cloudy' } as const;
  const angleLabel = (angle: string) =>
    angle.replace('front34', 'Front ¾').replace('rear34', 'Rear ¾').replace(/^./, (first) => first.toUpperCase());
  const bgName = $derived(real ? 'Real place' : presetOf(settings) || KINDS[settings.bg]);
  const angleName = $derived(studio.angle ? angleLabel(studio.angle) : `${Math.round(settings.rot)}° around`);
  const shapeName = $derived(SHAPE_NAMES[settings.frame] || settings.frame);
  const fileName = (src: string) =>
    src
      .replace(/^https?:\/\/[^/]+\//i, '')
      .split(/[/?#]/)
      .filter(Boolean)
      .pop() || 'Picture';

  type Row = { id: Layer; icon: string; name: string; sub: string; eye?: boolean };

  const items = (back: boolean) => {
    const list: Row[] = [];

    settings.texts.forEach((text, i) => {
      if (text.back !== back) return;
      list.push({ id: `text${i}`, icon: 'text', name: text.t.trim() || 'Empty text', sub: 'Text', eye: true });
    });

    settings.images.forEach((image, i) => {
      if (image.back !== back) return;
      list.push({ id: `img${i}`, icon: 'picture', name: fileName(image.src), sub: 'Picture', eye: true });
    });

    return list;
  };

  const rows = $derived.by(() => {
    const photoSub = real ? `${settings.width} px` : `${shapeName}, ${sizeText(settings, settings.width)}`;
    const lightParts = [real ? '' : SKIES[settings.sky], settings.glow ? 'colour light' : ''];
    const list: Row[] = [
      { id: 'photo', icon: 'frame', name: 'Photo', sub: photoSub },
      { id: 'camera', icon: 'camera', name: 'Camera', sub: angleName },
      { id: 'light', icon: 'bulb', name: 'Light', sub: lightParts.filter(Boolean).join(', ') || 'Colour light off' },
    ];

    if (!real) list.push(...items(false));
    list.push({ id: 'car', icon: 'car', name: 'Car', sub: fleet.nameOf(studio.model) || 'Vehicle' });

    if (!real) {
      const floorParts = [settings.shadow && 'Shadow', settings.reflect && 'Mirror'].filter(Boolean);
      const floorSub = floorParts.length ? floorParts.join(' and ') : 'Off';
      list.push(...items(true));
      list.push({ id: 'floor', icon: 'floor', name: 'Floor', sub: floorSub, eye: true });
    }

    list.push({ id: 'bg', icon: 'image', name: 'Background', sub: bgName });

    return list;
  });

  let styling = $state(false);
  let styleName = $state('');
  let doomed = $state('');
  const current = $derived(library.styles.find((style) => style.id === library.style));

  function deleteStyle(id: string) {
    if (doomed !== id) {
      doomed = id;
      return;
    }

    library.removeStyle(id);
    doomed = '';
  }

  function keepStyle() {
    library.saveNewStyle(styleName);
    styleName = '';
  }
</script>

<aside class="inspector glass">
  <header class="head">
    <div>
      <p class="eyebrow">Evolent Studio</p>
      <h1>Studio</h1>
    </div>
    <div class="tools">
      <button type="button" class="x" aria-label="Undo" title="Undo (Ctrl+Z)" disabled={!studio.canUndo} onclick={() => studio.undo()}><Icon name="undo" /></button>
      <button type="button" class="x" aria-label="Redo" title="Redo (Ctrl+Y)" disabled={!studio.canRedo} onclick={() => studio.redo()}><Icon name="redo" /></button>
      <button type="button" class="x" aria-label="Close" title="Close the menu (Esc)" onclick={() => studio.exit()}><Icon name="close" /></button>
    </div>
  </header>
  <div class="stylebar">
    <button type="button" class="stylepick" class:open={styling} onclick={() => (styling = !styling)}>
      <span class="lic"><Icon name="layers" /></span>
      <span class="ltxt"><b>{current?.name || 'Styles'}</b><span>{current ? 'Saved style' : library.styles.length ? `${library.styles.length} saved, pick one` : 'Keep this look under a name'}</span></span>
      <span class="chev"><Icon name="back" /></span>
    </button>
    {#if styling}
      <div class="styles fadein">
        {#each library.styles as style (style.id)}
          <div class="lrow" class:sel={library.style === style.id}>
            <button type="button" class="lpick" onclick={() => library.useStyle(style)}>
              <span class="ltxt"><b>{style.name}</b></span>
            </button>
            <button type="button" class="leye" class:sure={doomed === style.id} aria-label="Delete style" title={doomed === style.id ? 'Click again to delete' : 'Delete'}
              onclick={() => deleteStyle(style.id)}><Icon name="trash" /></button>
          </div>
        {/each}
        <div class="saveplace">
          <input type="text" maxlength="32" placeholder="Name, e.g. Dealership" bind:value={styleName} />
          <button type="button" class="second" disabled={!styleName.trim()} onclick={keepStyle}>Keep</button>
        </div>
        {#if current}
          <button type="button" class="ladd" onclick={() => library.saveStyle(current.name)}><Icon name="check" />Update {current.name}</button>
        {/if}
      </div>
    {/if}
  </div>
  <div class="layers" class:locked={studio.locked}>
    {#each rows as row (row.id)}
      {@const on = studio.showing(row.id)}
      <div class="lrow" class:sel={studio.layer === row.id} class:off={row.eye && !on} class:car={row.id === 'car'}>
        <button type="button" class="lpick" onclick={() => (studio.layer = row.id)}>
          <span class="lic"><Icon name={row.icon} /></span>
          <span class="ltxt"><b>{row.name}</b><span>{row.sub}</span></span>
        </button>
        {#if row.eye}
          <button type="button" class="leye" aria-label={on ? 'Hide' : 'Show'} onclick={() => studio.toggleLayer(row.id)}><Icon name={on ? 'eye' : 'eyeoff'} /></button>
        {/if}
      </div>
    {/each}
  </div>
  {#if real}
    <p class="quiet realnote">Texts, pictures and the floor are for photos on a backdrop.</p>
  {:else}
    <div class="addrow addbar">
      <button type="button" class="ladd" disabled={settings.texts.length >= 3} onclick={() => studio.addText()}><Icon name="plus" />Text</button>
      <button type="button" class="ladd" disabled={settings.images.length >= 3} onclick={() => studio.addImage(library.pictures[0] || '')}><Icon name="plus" />Picture</button>
    </div>
  {/if}
  <div class="props" class:locked={studio.locked} bind:this={props}>
    {#key studio.layer}
      <div class="fadein"><LayerProps /></div>
    {/key}
  </div>
  {#if shot.testError}<p class="testerr">{shot.testError}</p>{/if}
  <footer class="foot studio">
    <button type="button" class="reset" onclick={() => studio.reset()}>Reset</button>
    <button type="button" class="second" disabled={!!session.block || shot.testing} onclick={() => shot.take()}>{shot.testing ? 'Taking photo' : 'Test shot'}</button>
    <button type="button" class="savebtn accent" title="The next photos are taken like this" onclick={() => studio.save()}>{studio.saved ? 'Saved' : 'Save'}</button>
  </footer>
</aside>
