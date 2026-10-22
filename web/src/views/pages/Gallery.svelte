<script lang="ts">
  import '../../styles/gallery.css';
  import { session, fleet, gallery, uploads, SWATCHES } from '../../stores';
  import { toClipboard } from '../../lib/clipboard';
  import Icon from '../components/Icon.svelte';
  import Painted from '../components/Painted.svelte';

  const MONTHS = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

  function ago(at?: number) {
    if (!at) return '';

    const days = Math.floor((Date.now() / 1000 - at) / 86400);
    if (days < 1) return 'Today';
    if (days === 1) return 'Yesterday';
    if (days < 7) return `${days} days ago`;
    if (days < 14) return '1 week ago';
    if (days < 31) return `${Math.floor(days / 7)} weeks ago`;
    if (days < 62) return '1 month ago';
    return `${Math.floor(days / 30)} months ago`;
  }

  function date(at?: number) {
    if (!at) return '';

    const taken = new Date(at * 1000);
    return `${taken.getDate()} ${MONTHS[taken.getMonth()]} ${taken.getFullYear()}`;
  }

  const term = $derived(gallery.search.trim().toLowerCase());
  const photos = $derived(
    fleet.photos.filter((vehicle) => !term || vehicle.name.toLowerCase().indexOf(term) > -1 || vehicle.id.indexOf(term) > -1),
  );
  const photo = $derived(gallery.detail ? fleet.byId.get(gallery.detail) : undefined);
  let size = $state('');
  let copied = $state(false);
  let busy = $state(false);

  function openPhoto(id: string) {
    gallery.detail = id;
    gallery.confirm = false;
    size = '';
  }

  function closePhoto() {
    gallery.detail = null;
    gallery.confirm = false;
  }

  function copyLink(url: string) {
    toClipboard(url);
    copied = true;
    setTimeout(() => (copied = false), 1500);
  }

  async function saveLink(id: string) {
    busy = true;
    await uploads.one(id);
    busy = false;
  }
</script>

{#if !photo}
  <div class="gtop">
    <div class="search">
      <Icon name="search" />
      <input type="text" placeholder="Search photos" bind:value={gallery.search} />
    </div>
    <div class="colours">
      {#each [['primary', 'Primary'], ['secondary', 'Secondary']] as [which, label] (which)}
        <div class="grp">
          <span>{label}</span>
          <div class="sw">
            {#each SWATCHES as hex (hex)}
              <button type="button" aria-label={hex} class:on={gallery[which as 'primary' | 'secondary'] === hex} style:background={hex}
                onclick={() => gallery.setColour(which as 'primary' | 'secondary', hex)}></button>
            {/each}
          </div>
        </div>
      {/each}
    </div>
    <div class="meta"><span>{fleet.photos.length} {fleet.photos.length === 1 ? 'photo' : 'photos'}</span><span>Newest first</span></div>
  </div>
  <div class="gscroll">
    {#if !fleet.photos.length}
      <div class="empty">
        <span class="icon"><Icon name="grid" /></span>
        <b>No photos yet</b>
        <p>Pick vehicles in the list and press Photograph. Each car shows up here in any colour you pick above.</p>
        <button type="button" onclick={() => (session.tab = 'vehicles')}>Open vehicle list</button>
      </div>
    {:else if !photos.length}
      <div class="empty">
        <b>No photo matches "{gallery.search}"</b>
        <p>Check the spelling, or search by spawn code.</p>
      </div>
    {/if}
    <div class="grid">
      {#each photos as vehicle (vehicle.id)}
        <button type="button" class="photo" onclick={() => openPhoto(vehicle.id)}>
          <span class="well"><Painted model={vehicle.id} version={vehicle.updatedAt} /></span>
          <span class="txt">
            <b>{vehicle.name}</b>
            <span class="mini"><span>{vehicle.id}</span><span>{ago(vehicle.updatedAt)}</span><span>{vehicle.sizeKb} KB</span></span>
          </span>
        </button>
      {/each}
    </div>
  </div>
{:else}
  <div class="scroll">
    <button type="button" class="back" onclick={closePhoto}><Icon name="back" /><span>Gallery</span></button>
    <div class="dgrid">
      <div class="bigimg"><Painted model={photo.id} version={photo.updatedAt} onsize={(w, h) => (size = `${w} × ${h}`)} /></div>
      <div class="dinfo">
        <h2>{photo.name}</h2>
        <div class="chips">
          <span class="chip">{photo.id}</span>
          <span class="chip dim2">Taken {date(photo.updatedAt)}</span>
          <span class="chip dim2">{photo.sizeKb} KB</span>
          {#if size}<span class="chip dim2">{size}</span>{/if}
        </div>
        {#if uploads.config.service !== 'off'}
          <div class="linkrow">
            {#if photo.url}
              <input type="text" readonly value={photo.url} onfocus={(e) => (e.currentTarget as HTMLInputElement).select()} />
              <button type="button" class="second" onclick={() => copyLink(photo.url || '')}>{copied ? 'Copied' : 'Copy link'}</button>
            {:else}
              <span class="quiet">No link yet.</span>
            {/if}
            <button type="button" class="second" disabled={busy || !uploads.config.hasToken} title={uploads.config.hasToken ? '' : 'Add the key in Settings'}
              onclick={() => saveLink(photo.id)}>{busy ? 'Saving' : photo.url ? 'Save again' : 'Save a link'}</button>
          </div>
          {#if uploads.error}<p class="quiet red">{uploads.error}</p>{/if}
        {/if}
        {#if !gallery.confirm}
          <div class="acts">
            <button type="button" class="act" disabled={!!session.block} onclick={() => gallery.retake(photo.id)}><Icon name="retake" /><span>Retake</span></button>
            <button type="button" class="act del" onclick={() => (gallery.confirm = true)}><Icon name="trash" /><span>Delete</span></button>
          </div>
        {:else}
          <div class="sure">
            <b>Delete this photo?</b>
            <p>Owners see the default image until you photograph this model again.</p>
            <div class="acts">
              <button type="button" class="cancel" onclick={() => (gallery.confirm = false)}>Cancel</button>
              <button type="button" class="kill" onclick={() => gallery.remove(photo.id)}>Delete photo</button>
            </div>
          </div>
        {/if}
      </div>
    </div>
  </div>
{/if}
