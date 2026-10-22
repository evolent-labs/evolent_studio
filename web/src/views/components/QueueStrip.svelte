<script lang="ts">
  import '../../styles/queue.css';
  import { queue, fleet } from '../../stores';
  import Icon from './Icon.svelte';

  const run = $derived(queue.state!);
  const width = $derived(Math.round(((run.done || 0) / (run.total || 1)) * 100));
</script>

<section class="strip" class:running={run.status === 'running'}>
  {#if run.status !== 'done'}
    <div class="line">
      <div class="txt">
        <span>{run.status === 'paused' ? 'Paused' : 'Photographing now'}</span>
        <b>{fleet.nameOf(run.current)}</b>
      </div>
      <button type="button" class="sq" aria-label={run.status === 'paused' ? 'Resume' : 'Pause'}
        onclick={() => queue.act(run.status === 'paused' ? 'resume' : 'pause')}>
        <Icon name={run.status === 'paused' ? 'play' : 'pause'} />
      </button>
      <button type="button" class="sq stop" aria-label="Stop queue" onclick={() => queue.act('stop')}><Icon name="stop" /></button>
    </div>
    <div class="prog">
      <div class="bar" class:paused={run.status === 'paused'}><i style="width:{width}%"></i></div>
      <span>{run.done || 0} of {run.total}</span>
    </div>
  {:else}
    <div class="done">
      <div class="txt">
        <b>Queue finished</b>
        <div class="chips">
          <span class="okchip">{run.ok} done</span>
          {#if run.fail > 0}<span class="failchip">{run.fail} failed</span>{/if}
        </div>
      </div>
      {#if run.fail > 0}<button type="button" class="retry" onclick={() => queue.act('retry')}>Retry failed</button>{/if}
      <button type="button" class="dismiss" aria-label="Clear" title="Clear" onclick={() => queue.act('dismiss')}><Icon name="close" /></button>
    </div>
  {/if}
</section>
