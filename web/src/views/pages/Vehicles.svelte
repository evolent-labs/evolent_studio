<script lang="ts">
  import '../../styles/vehicles.css';
  import { session, queue, fleet, type Filter, type Status } from '../../stores';
  import Icon from '../components/Icon.svelte';

  const FILTERS: [Filter, string][] = [
    ['all', 'All'],
    ['owned', 'Owned'],
    ['missing', 'Missing'],
    ['ready', 'Ready'],
    ['failed', 'Failed'],
  ];
  const LABEL: Record<Status, string> = {
    ready: 'Ready',
    missing: 'Missing',
    failed: 'Failed',
    queued: 'Queued',
    shooting: 'Shooting',
  };
  const SKELETON = [70, 52, 64, 46, 58, 40];

  const PITCH = 43;
  let scrollTop = $state(0);
  let viewHeight = $state(600);
  const first = $derived(Math.max(0, Math.floor(scrollTop / PITCH) - 4));
  const last = $derived(Math.min(fleet.rows.length, Math.ceil((scrollTop + viewHeight) / PITCH) + 4));

  const allChecked = $derived(fleet.rows.length > 0 && fleet.rows.every((row) => fleet.sel[row.id]));
  const count = $derived(fleet.selected.length);
  const disabled = $derived(count === 0 || !!session.block);
  const cta = $derived.by(() => {
    if (count === 0) return 'Select vehicles to photograph';
    return queue.active ? `Add ${count} to queue` : `Photograph ${count} selected`;
  });
  const noResults = $derived(!fleet.loading && fleet.rows.length === 0 && !!fleet.search.trim());

  function owners(own: number) {
    return own === 0 ? 'No owners' : own === 1 ? '1 owner' : `${own} owners`;
  }

  function toggleAddon() {
    fleet.addonOpen = !fleet.addonOpen;
    fleet.addonErr = '';
  }

  function selectOwned() {
    fleet.filter = 'owned';
    fleet.selectWhere((vehicle) => vehicle.owned > 0);
  }

  function addSearchAsAddon() {
    fleet.addonOpen = true;
    fleet.addonCode = fleet.search.trim();
    fleet.addonErr = '';
  }
</script>

<div class="vbody">
  <aside>
    {#each FILTERS as [key, label] (key)}
      <button type="button" class="filt" class:on={fleet.filter === key} onclick={() => (fleet.filter = key)}>
        <span>{label}</span>
        <span class="c" class:red={key === 'failed' && fleet.counts.failed > 0}>{fleet.loading ? '' : fleet.counts[key]}</span>
      </button>
    {/each}
    <button type="button" class="dashed" onclick={() => fleet.selectWhere((vehicle) => vehicle.status === 'missing')}>Select all missing</button>
    <button type="button" class="addbtn" class:on={fleet.addonOpen} onclick={toggleAddon}>
      <Icon name="plus" /><span>Add addon</span>
    </button>
  </aside>
  <div class="vcol">
    <div class="search">
      <Icon name="search" />
      <input type="text" placeholder="Search name or spawn code" bind:value={fleet.search} />
    </div>
    {#if fleet.addonOpen}
      <div class="card addon">
        <span>Add a vehicle that is not in the framework list</span>
        <div class="line">
          <input type="text" placeholder="Spawn code" class:err={!!fleet.addonErr} bind:value={fleet.addonCode}
            oninput={() => (fleet.addonErr = '')} onkeydown={(e) => e.key === 'Enter' && fleet.addAddon()} />
          <button type="button" class="add accent" onclick={() => fleet.addAddon()}>Add</button>
        </div>
        {#if fleet.addonErr}<span class="msg">{fleet.addonErr}</span>{/if}
      </div>
    {/if}
    {#if fleet.firstRun}
      <div class="card first">
        <div>
          <b>Photograph each model once</b>
          <p>Three shots on a green screen. The garage app then shows every car in its owner's colours.</p>
        </div>
        <button type="button" onclick={selectOwned}>Select {fleet.counts.owned} owned</button>
      </div>
    {/if}
    <div class="visible">
      <button type="button" onclick={() => fleet.selectVisible(!allChecked)}>
        <span class="box" class:on={allChecked}>{#if allChecked}<Icon name="check" />{/if}</span>
        <span>Select visible</span>
      </button>
    </div>
    <div class="list" bind:clientHeight={viewHeight} onscroll={(e) => (scrollTop = (e.currentTarget as HTMLElement).scrollTop)}>
      {#if fleet.loading}
        <div class="loadline"><span class="spin"></span><span>Loading vehicles from the server</span></div>
        {#each SKELETON as w, i (i)}
          <div class="skel"><span class="b1"></span><span class="col"><span style="width:{w}%"></span><span></span></span><span class="b2"></span></div>
        {/each}
      {:else if noResults}
        <div class="none">
          <b>No vehicles match "{fleet.search}"</b>
          <p>Check the spelling. If it is an addon car, add it with its spawn code.</p>
          <button type="button" onclick={addSearchAsAddon}>Add {fleet.search} as addon</button>
        </div>
      {:else if !fleet.rows.length}
        <div class="none">
          <b>Nothing in this list</b>
          <p>No vehicle fits this filter right now. Pick All to see every vehicle.</p>
          <button type="button" onclick={() => (fleet.filter = 'all')}>Show all</button>
        </div>
      {:else}
        <div style="height:{first * PITCH}px"></div>
        {#each fleet.rows.slice(first, last) as vehicle (vehicle.id)}
          {@const status = fleet.statusOf(vehicle)}
          {@const on = !!fleet.sel[vehicle.id]}
          <button type="button" class="row" class:on onclick={() => fleet.toggle(vehicle.id)}>
            <span class="box" class:on>{#if on}<Icon name="check" />{/if}</span>
            <span class="mid">
              <b>{vehicle.name}</b>
              <span class="code">{vehicle.id}</span>
              <span class="sub" class:red={status === 'failed' && !!vehicle.error}>{status === 'failed' && vehicle.error ? vehicle.error : owners(vehicle.owned)}</span>
            </span>
            <span class="tag {status}">{LABEL[status]}</span>
          </button>
        {/each}
        <div style="height:{(fleet.rows.length - last) * PITCH}px"></div>
      {/if}
    </div>
  </div>
</div>
<footer class="foot">
  {#if count > 0}
    <span class="selcount">{count} selected</span>
    <button type="button" class="clear" onclick={() => fleet.clearSel()}>Clear</button>
  {/if}
  <button type="button" class="cta accent" {disabled} onclick={() => fleet.start()}>
    <Icon name="camera" />
    <span>{cta}</span>
  </button>
</footer>
