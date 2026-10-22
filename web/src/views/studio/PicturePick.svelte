<script lang="ts">
  import '../../styles/studio.css';
  import { library } from '../../stores';

  let { value, onpick }: { value: string; onpick: (src: string) => void } = $props();
  let link = $state('');
</script>

<span class="plab">Picture</span>
{#if library.pictures.length}
  <div class="opts two">
    {#each library.pictures as file (file)}
      <button type="button" class="opt" class:on={value === file} onclick={() => onpick(file)}>{file}</button>
    {/each}
  </div>
{:else}
  <p class="quiet lead">Put pictures in the images folder of the resource and list them in config.lua, or paste a link.</p>
{/if}
<div class="saveplace">
  <input type="text" maxlength="300" placeholder="Or paste a picture link" value={/^https?:/i.test(value) ? value : link}
    oninput={(e) => (link = (e.currentTarget as HTMLInputElement).value)} />
  <button type="button" class="second" disabled={!/^https?:\/\/\S+$/i.test(link.trim())} onclick={() => onpick(link.trim())}>Use</button>
</div>
