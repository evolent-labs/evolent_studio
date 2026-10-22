<script lang="ts">
  import { gallery } from '../../stores';
  import { layersFor, paint } from '../../lib/photos';

  let { model, version, onsize }: { model: string; version?: number; onsize?: (w: number, h: number) => void } = $props();

  let image = $state('');
  let seen = $state(false);
  let el: HTMLImageElement;

  $effect(() => {
    const observer = new IntersectionObserver((entries) => {
      if (entries.some((entry) => entry.isIntersecting)) {
        seen = true;
        observer.disconnect();
      }
    });
    observer.observe(el);
    return () => observer.disconnect();
  });

  $effect(() => {
    if (!seen) return;

    const primary = gallery.primary;
    const secondary = gallery.secondary;
    let live = true;

    layersFor(model, version).then(async (layers) => {
      if (!layers || !live) return;

      const done = await paint(`${model}:${version ?? 0}`, layers, primary, secondary);
      if (!live) return;

      image = done.image;
      onsize?.(done.width, done.height);
    });

    return () => (live = false);
  });
</script>

<img bind:this={el} src={image || undefined} alt="" style:visibility={image ? 'visible' : 'hidden'} />
