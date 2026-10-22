<script lang="ts">
  import '../../styles/studio.css';
  import { session, shot } from '../../stores';
  import Icon from '../components/Icon.svelte';

  const test = $derived(shot.test);
</script>

{#if test}
  <div class="test" class:over={test.big}>
    <div class="checker">
      <img src={test.image} alt="" />
      <button type="button" class="shut" aria-label="Close test shot" onclick={() => (shot.test = null)}><Icon name="close" /></button>
    </div>
    <div class="info">
      <div class="chips">
        <span class="chip">Test shot</span>
        <span class="chip num">{test.w} × {test.h}</span>
        <span class="chip num" class:redtext={test.big}>{test.kb} KB per layer</span>
        <span class="chip state" class:over={test.big}>{test.big ? 'Too large' : 'Preview only'}</span>
      </div>
      {#if test.big}
        <p>This photo is {test.kb} KB per layer. The limit is {session.limitKb} KB, so pick a smaller width.</p>
      {/if}
    </div>
  </div>
{/if}
