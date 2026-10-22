<script lang="ts">
  import '../../styles/queue.css';
  import { session, queue, fleet, LAYERS } from '../../stores';
  import Icon from '../components/Icon.svelte';

  const run = $derived(queue.state);
  const width = $derived(run ? Math.round(((run.done || 0) / (run.total || 1)) * 100) : 0);
</script>

<div class="scroll">
  {#if !run}
    <div class="empty">
      <span class="icon"><Icon name="list" /></span>
      <b>Queue is empty</b>
      <p>Select vehicles in the list and press Photograph. Progress shows up here.</p>
      <button type="button" onclick={() => (session.tab = 'vehicles')}>Open vehicle list</button>
    </div>
  {:else if run.status !== 'done'}
    <div class="qcard" class:running={run.status === 'running'}>
      <span>{run.status === 'paused' ? 'Paused' : 'Photographing now'}</span>
      <b>{fleet.nameOf(run.current)}</b>
      <div class="chips">
        <span class="chip">{run.current || ''}</span>
        <span class="chip dim2">Layer {run.layer || 1} of {run.steps || 3}</span>
        <span class="chip dim2">{LAYERS[(run.layer || 1) - 1]}</span>
      </div>
      <div class="prog">
        <div class="bar" class:paused={run.status === 'paused'}><i style="width:{width}%"></i></div>
        <span>{run.done || 0} of {run.total}</span>
      </div>
      <div class="acts">
        <button type="button" class="qbtn" onclick={() => queue.act(run.status === 'paused' ? 'resume' : 'pause')}>{run.status === 'paused' ? 'Resume' : 'Pause'}</button>
        <button type="button" class="qbtn stop" onclick={() => queue.act('stop')}>Stop queue</button>
      </div>
    </div>
    <div class="qhead"><span>Up next</span><span>{run.list.length} left</span></div>
    {#each run.list.slice(0, 6) as id, i (id)}
      <div class="next">
        <span class="n">{(run.done || 0) + i + 2}</span>
        <span class="t"><b>{fleet.nameOf(id)}</b><span>{id}</span></span>
        <span class="q">Queued</span>
      </div>
    {/each}
  {:else}
    <div class="qcard done">
      <b>Queue finished</b>
      <div class="stats">
        <div><span>Done</span><b class="g">{run.ok}</b></div>
        <div><span>Failed</span><b class="r">{run.fail}</b></div>
      </div>
      <div class="acts">
        {#if run.fail > 0}<button type="button" class="qbtn accent" onclick={() => queue.act('retry')}>Retry failed</button>{/if}
        <button type="button" class="qbtn plain" onclick={() => queue.act('dismiss')}>Clear</button>
      </div>
    </div>
    {#if run.fail > 0}
      <span class="flabel">Failed</span>
      {#each run.failed as failure (failure.id)}
        <div class="frow">
          <span class="t"><b>{fleet.nameOf(failure.id)}</b><span>{failure.error}</span></span>
          <span class="code">{failure.id}</span>
        </div>
      {/each}
    {/if}
  {/if}
</div>
