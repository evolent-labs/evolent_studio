<script lang="ts">
  let { name }: { name: string } = $props();
</script>

{#if name === 'car'}
  <svg class="s" viewBox="0 0 16 16"><path d="M2 10.5V8.5l1.3-3.2A1.5 1.5 0 0 1 4.7 4.3h6.6a1.5 1.5 0 0 1 1.4 1l1.3 3.2v2z"></path><path d="M2 10.5v1.8M14 10.5v1.8M2 8.5h12"></path><circle cx="4.8" cy="10.2" r=".4"></circle><circle cx="11.2" cy="10.2" r=".4"></circle></svg>
{:else if name === 'camera'}
  <svg class="s" viewBox="0 0 16 16"><path d="M2.5 5.5h2l1-1.5h5l1 1.5h2v7h-11z"></path><circle cx="8" cy="8.8" r="2.2"></circle></svg>
{:else if name === 'pin'}
  <svg class="s" viewBox="0 0 16 16"><path d="M8 14s4.5-4.1 4.5-7.6a4.5 4.5 0 0 0-9 0C3.5 9.9 8 14 8 14z"></path><circle cx="8" cy="6.4" r="1.6"></circle></svg>
{:else if name === 'grid'}
  <svg class="s" viewBox="0 0 16 16"><rect x="2.5" y="2.5" width="4.5" height="4.5" rx="1"></rect><rect x="9" y="2.5" width="4.5" height="4.5" rx="1"></rect><rect x="2.5" y="9" width="4.5" height="4.5" rx="1"></rect><rect x="9" y="9" width="4.5" height="4.5" rx="1"></rect></svg>
{:else if name === 'list'}
  <svg class="s" viewBox="0 0 16 16"><path d="M5.5 4h8M5.5 8h8M5.5 12h8M2.5 4h.1M2.5 8h.1M2.5 12h.1"></path></svg>
{:else if name === 'close'}
  <svg class="s" viewBox="0 0 16 16"><path d="M4 4l8 8M12 4l-8 8"></path></svg>
{:else if name === 'check'}
  <svg class="s" viewBox="0 0 16 16"><path d="M3.5 8.5l3 3 6-7"></path></svg>
{:else if name === 'search'}
  <svg class="s" viewBox="0 0 16 16"><circle cx="7" cy="7" r="4.5"></circle><path d="M10.5 10.5 14 14"></path></svg>
{:else if name === 'plus'}
  <svg class="s" viewBox="0 0 16 16"><path d="M8 3v10M3 8h10"></path></svg>
{:else if name === 'warn'}
  <svg class="s" viewBox="0 0 16 16"><path d="M8 2.5 14 13H2z"></path><path d="M8 6.5v3M8 11.3v.1"></path></svg>
{:else if name === 'pause'}
  <svg class="s" viewBox="0 0 16 16"><path d="M6 4v8M10 4v8"></path></svg>
{:else if name === 'play'}
  <svg viewBox="0 0 16 16" style="fill:currentColor"><path d="M5 3.5v9l7-4.5z"></path></svg>
{:else if name === 'stop'}
  <svg viewBox="0 0 16 16" style="fill:currentColor"><rect x="3.5" y="3.5" width="9" height="9" rx="1.5"></rect></svg>
{:else if name === 'lock'}
  <svg class="s" viewBox="0 0 16 16"><rect x="3.5" y="7" width="9" height="6.5" rx="1"></rect><path d="M5.5 7V5a2.5 2.5 0 0 1 5 0v2"></path></svg>
{:else if name === 'mouse'}
  <svg class="s" viewBox="0 0 16 16"><rect x="5" y="2.5" width="6" height="11" rx="3"></rect><path d="M8 5v2"></path></svg>
{:else if name === 'back'}
  <svg class="s" viewBox="0 0 16 16"><path d="M10 3 5 8l5 5"></path></svg>
{:else if name === 'retake'}
  <svg class="s" viewBox="0 0 16 16"><path d="M13 8a5 5 0 1 1-1.5-3.5M13 3v2.5h-2.5"></path></svg>
{:else if name === 'bulb'}
  <svg class="s" viewBox="0 0 16 16"><path d="M6 12h4M6.5 14h3M8 2a4 4 0 0 0-2.4 7.2c.5.4.9 1 .9 1.8h3c0-.8.4-1.4.9-1.8A4 4 0 0 0 8 2z"></path></svg>
{:else if name === 'text'}
  <svg class="s" viewBox="0 0 16 16"><path d="M3.5 4.5V3h9v1.5M8 3v10M6 13h4"></path></svg>
{:else if name === 'floor'}
  <svg class="s" viewBox="0 0 16 16"><ellipse cx="8" cy="11" rx="5.5" ry="1.8"></ellipse><path d="M5 9V5.5h6V9"></path></svg>
{:else if name === 'image'}
  <svg class="s" viewBox="0 0 16 16"><rect x="2.5" y="3" width="11" height="10" rx="1.2"></rect><path d="M2.5 11l3.5-3.5 3 3 1.5-1.5 3 3"></path><circle cx="10.5" cy="6" r="1"></circle></svg>
{:else if name === 'eye'}
  <svg class="s" viewBox="0 0 16 16"><path d="M1.5 8S4 3.5 8 3.5 14.5 8 14.5 8 12 12.5 8 12.5 1.5 8 1.5 8z"></path><circle cx="8" cy="8" r="2"></circle></svg>
{:else if name === 'eyeoff'}
  <svg class="s" viewBox="0 0 16 16"><path d="M2.5 2.5l11 11M6.6 4A6.6 6.6 0 0 1 8 3.5c4 0 6.5 4.5 6.5 4.5a11 11 0 0 1-1.9 2.4M10.8 11.6A6 6 0 0 1 8 12.5C4 12.5 1.5 8 1.5 8a11.3 11.3 0 0 1 2.8-3.2"></path></svg>
{:else if name === 'undo'}
  <svg class="s" viewBox="0 0 16 16"><path d="M5 4 2.5 6.5 5 9"></path><path d="M2.5 6.5h7a3.5 3.5 0 0 1 0 7H7"></path></svg>
{:else if name === 'redo'}
  <svg class="s" viewBox="0 0 16 16"><path d="M11 4l2.5 2.5L11 9"></path><path d="M13.5 6.5h-7a3.5 3.5 0 0 0 0 7H9"></path></svg>
{:else if name === 'copy'}
  <svg class="s" viewBox="0 0 16 16"><rect x="5.5" y="5.5" width="8" height="8" rx="1"></rect><path d="M10.5 5.5V3.5a1 1 0 0 0-1-1h-6a1 1 0 0 0-1 1v6a1 1 0 0 0 1 1h2"></path></svg>
{:else if name === 'minus'}
  <svg class="s" viewBox="0 0 16 16"><path d="M3 8h10"></path></svg>
{:else if name === 'frame'}
  <svg class="s" viewBox="0 0 16 16"><path d="M4.5 2v10.5H14M2 4.5h10.5V14"></path></svg>
{:else if name === 'picture'}
  <svg class="s" viewBox="0 0 16 16"><rect x="2.5" y="2.5" width="11" height="11" rx="2"></rect><path d="M5.5 10.5 8 8l2.5 2.5"></path><circle cx="6" cy="6" r=".9"></circle></svg>
{:else if name === 'layers'}
  <svg class="s" viewBox="0 0 16 16"><path d="M8 2.5 14 5.5 8 8.5 2 5.5z"></path><path d="M2 8.5l6 3 6-3M2 11.5l6 3 6-3"></path></svg>
{:else if name === 'gear'}
  <svg class="s" viewBox="0 0 16 16"><circle cx="8" cy="8" r="2.2"></circle><path d="M8 1.8v1.7M8 12.5v1.7M1.8 8h1.7M12.5 8h1.7M3.6 3.6l1.2 1.2M11.2 11.2l1.2 1.2M12.4 3.6l-1.2 1.2M4.8 11.2l-1.2 1.2"></path></svg>
{:else if name === 'link'}
  <svg class="s" viewBox="0 0 16 16"><path d="M6.8 9.2a2.6 2.6 0 0 0 3.7 0l2.2-2.2a2.6 2.6 0 0 0-3.7-3.7l-.9.9"></path><path d="M9.2 6.8a2.6 2.6 0 0 0-3.7 0L3.3 9a2.6 2.6 0 0 0 3.7 3.7l.9-.9"></path></svg>
{:else if name === 'upload'}
  <svg class="s" viewBox="0 0 16 16"><path d="M8 10.5V3M5 5.8 8 2.8l3 3M3 10.5v2.5h10v-2.5"></path></svg>
{:else if name === 'trash'}
  <svg class="s" viewBox="0 0 16 16"><path d="M3 4.5h10M6.5 4.5V3h3v1.5M4.5 4.5l.5 8.5h6l.5-8.5"></path></svg>
{/if}
