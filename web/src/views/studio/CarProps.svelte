<script lang="ts">
  import '../../styles/studio.css';
  import { fleet, studio } from '../../stores';
  import { nui } from '../../lib/nui';
  import Icon from '../components/Icon.svelte';
  import Range from '../components/Range.svelte';
  import ColourPicker from '../components/ColourPicker.svelte';
  import { DOORS, INDICATORS, SWITCHES, TINTS, signed } from './options';

  const settings = $derived(studio.settings);
  const real = $derived(settings.place !== 'green');

  let face = $state(0);

  $effect(() => {
    face = studio.face;
  });

  let carSearch = $state('');
  const carTerm = $derived(carSearch.trim().toLowerCase());
  const carHits = $derived(
    carTerm
      ? fleet.list
        .filter((vehicle) => vehicle.name.toLowerCase().indexOf(carTerm) > -1 || vehicle.id.indexOf(carTerm) > -1)
        .slice(0, 6)
      : [],
  );
  const typedCode = $derived(
    /^[a-z0-9_-]+$/.test(carTerm) && !carHits.some((vehicle) => vehicle.id === carTerm) ? carTerm : '',
  );

  function showCar(id: string) {
    carSearch = '';
    studio.showCar(id);
  }

  function stepCar(by: number) {
    const list = fleet.list;
    if (!list.length) return;

    const at = list.findIndex((vehicle) => vehicle.id === studio.model);
    showCar(list[(at + by + list.length) % list.length].id);
  }

  function pickTyped(event: KeyboardEvent) {
    if (event.key === 'Enter' && (carHits[0] || typedCode)) showCar(carHits[0]?.id || typedCode);
  }

  function turnTo(heading: number) {
    face = heading;
    nui('car:setHeading', { h: heading });
  }

  function typePlate(event: Event) {
    const input = event.currentTarget as HTMLInputElement;
    input.value = input.value.toUpperCase().replace(/[^A-Z0-9 ]/g, '');
    studio.change({ plate: input.value }, true);
  }
</script>

<span class="plab lead">Car in the studio</span>
<div class="carpick">
  <button type="button" class="sq" aria-label="Car before" title="The car before this one" onclick={() => stepCar(-1)}><Icon name="back" /></button>
  <input type="text" maxlength="40" placeholder={fleet.nameOf(studio.model) || 'Search a car'} bind:value={carSearch}
    onkeydown={pickTyped} />
  <button type="button" class="sq fwd" aria-label="Car after" title="The car after this one" onclick={() => stepCar(1)}><Icon name="back" /></button>
</div>
{#if studio.carError}<p class="quiet red">{studio.carError}</p>{/if}
{#if carTerm}
  <div class="carhits">
    {#each carHits as vehicle (vehicle.id)}
      <button type="button" class="carhit" onclick={() => showCar(vehicle.id)}><b>{vehicle.name}</b><span>{vehicle.id}</span></button>
    {/each}
    {#if typedCode}
      <button type="button" class="carhit" onclick={() => showCar(typedCode)}><b>Try spawn code</b><span>{typedCode}</span></button>
    {/if}
    {#if !carHits.length && !typedCode}<p class="quiet">No car with that name.</p>{/if}
  </div>
{:else}
  <p class="quiet">Type a name or spawn code, or step through the list with the arrows.</p>
{/if}
{#if real}
  <div class="facerow">
    <div class="sliders flush">
      <Range label="Facing" value={face} min={0} max={359} text="{face}°" onchange={turnTo} />
    </div>
    <button type="button" class="second" onclick={() => nui('car:resetPosition')}>Back to start</button>
  </div>
  <div class="carrow">
    <span>Sit on the ground</span>
    <div class="seg">
      <button type="button" class:on={settings.ground === 'on'} onclick={() => studio.change({ ground: 'on' }, true)}>On</button>
      <button type="button" class:on={settings.ground === 'off'} onclick={() => studio.change({ ground: 'off' }, true)}>Off</button>
    </div>
  </div>
  {#if settings.ground === 'on'}
    <button type="button" class="ladd" onclick={() => nui('settle')}><Icon name="floor" />Drop it on the ground again</button>
    <p class="quiet">After every move the car sits down on its tyres and leans with the slope under it.</p>
  {/if}
{/if}
<div class="prows" class:lead={!real}>
  {#each SWITCHES as { key, label, options } (key)}
    <div class="carrow">
      <span>{label}</span>
      <div class="seg">
        {#each options as option (option.value)}
          <button type="button" class:on={settings[key] === option.value} onclick={() => studio.change({ [key]: option.value }, true)}>{option.label}</button>
        {/each}
      </div>
    </div>
  {/each}
  <div class="carrow">
    <span>Paint</span>
    <div class="seg">
      <button type="button" class:on={settings.paint === 'gloss'} onclick={() => studio.change({ paint: 'gloss' }, true)}>Glossy</button>
      <button type="button" class:on={settings.paint === 'matte'} onclick={() => studio.change({ paint: 'matte' }, true)}>Matte</button>
    </div>
  </div>
  <div class="carrow">
    <span>Tint</span>
    <div class="seg">
      {#each TINTS as tint (tint.value)}
        <button type="button" class:on={settings.tint === tint.value} onclick={() => studio.change({ tint: tint.value }, true)}>{tint.label}</button>
      {/each}
    </div>
  </div>
  <div class="carrow">
    <span>Indicators</span>
    <div class="seg">
      {#each INDICATORS as indicator (indicator.value)}
        <button type="button" class:on={settings.indicators === indicator.value} onclick={() => studio.change({ indicators: indicator.value }, true)}>{indicator.label}</button>
      {/each}
    </div>
  </div>
  {#if studio.isAircraft}
    <div class="carrow">
      <span>Landing gear</span>
      <div class="seg">
        <button type="button" class:on={settings.gear === 'down'} onclick={() => studio.change({ gear: 'down' }, true)}>Down</button>
        <button type="button" class:on={settings.gear === 'up'} onclick={() => studio.change({ gear: 'up' }, true)}>Up</button>
      </div>
    </div>
  {/if}
  <div class="carrow">
    <span>Neon</span>
    <div class="seg">
      <button type="button" class:on={settings.neon === 'off'} onclick={() => studio.change({ neon: 'off' }, true)}>Off</button>
      <button type="button" class:on={settings.neon === 'on'} onclick={() => studio.change({ neon: 'on' }, true)}>On</button>
    </div>
  </div>
</div>
{#if settings.neon === 'on'}
  <ColourPicker label="Neon colour" value={settings.neonColour} onchange={(neonColour) => studio.change({ neonColour }, true)} />
{/if}
<span class="plab">Open</span>
<div class="opts three">
  {#each DOORS as door (door.value)}
    <button type="button" class="opt" class:on={settings.doors.includes(door.value)} onclick={() => studio.toggleDoor(door.value)}>{door.label}</button>
  {/each}
</div>
<div class="sliders">
  <Range label="Steering" value={settings.steer} min={-40} max={40} text={signed(settings.steer, '°')} onchange={(steer) => studio.change({ steer }, true)} />
  <Range label="Nose up or down" value={settings.pitch} min={-15} max={15} text={signed(settings.pitch, '°')} onchange={(pitch) => studio.change({ pitch }, true)} />
  <Range label="Lean to the side" value={settings.roll} min={-15} max={15} text={signed(settings.roll, '°')} onchange={(roll) => studio.change({ roll }, true)} />
  <Range label="Ride height" value={settings.ride} min={-10} max={10} text={signed(settings.ride, ' cm')} onchange={(ride) => studio.change({ ride }, true)} />
</div>
<div class="platerow">
  <span>Plate</span>
  <input type="text" maxlength="8" value={settings.plate} oninput={typePlate} />
</div>
