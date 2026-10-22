<script lang="ts">
  import '../../styles/gallery.css';
  import '../../styles/studio.css';
  import '../../styles/settings.css';
  import { fleet, uploads, SWATCHES } from '../../stores';
  import { toClipboard } from '../../lib/clipboard';
  import Icon from '../components/Icon.svelte';

  const config = $derived(uploads.config);
  const on = $derived(config.service !== 'off');
  const ready = $derived(on && config.hasToken);
  const linked = $derived(fleet.photos.filter((photo) => photo.url).length);
  let token = $state('');
  const PLACES: [typeof config.service, string][] = [
    ['off', 'Nowhere'],
    ['fivemanage', 'Fivemanage'],
    ['discord', 'Discord'],
    ['folder', 'Server folder'],
  ];
  const KEYS: Record<string, { label: string; hint: string; help: string; cfg: string }> = {
    fivemanage: {
      label: 'API token',
      hint: 'Paste the token from fivemanage.com',
      cfg: 'evolent_studio:fivemanage',
      help: 'On fivemanage.com open your dashboard, make a token for images and paste it here.',
    },
    discord: {
      label: 'Webhook link',
      hint: 'https://discord.com/api/webhooks/...',
      cfg: 'evolent_studio:discord',
      help: 'In Discord open the channel settings, Integrations, Webhooks, make one and copy its link.',
    },
  };
  const WEBHOOK = /^https:\/\/([a-z]+\.)?discord(app)?\.com\/api\/webhooks\/\d+\/[\w-]+$/;
  const key = $derived(KEYS[config.service]);
  const fits = $derived(token.trim().length >= 8 && (config.service !== 'discord' || WEBHOOK.test(token.trim())));
  let copied = $state(false);

  function pickService(service: typeof config.service) {
    token = '';
    uploads.set({ service });
  }

  function saveToken() {
    uploads.set({ token: token.trim() });
    token = '';
  }

  function copyAll() {
    const links: Record<string, string> = {};
    for (const photo of fleet.photos) if (photo.url) links[photo.id] = photo.url;

    toClipboard(JSON.stringify(links, null, 2));
    copied = true;
    setTimeout(() => (copied = false), 1500);
  }
</script>

<div class="scroll settings">
  <section class="setcard">
    <div class="sethead">
      <span class="lens"><Icon name="link" /></span>
      <div>
        <b>Save pictures</b>
        <p>Save each photo somewhere and get a link that other scripts, a website or Discord can show. The garage app does not need this, it paints the photos itself.</p>
      </div>
    </div>

    <span class="plab">Save to</span>
    <div class="opts two">
      {#each PLACES as [id, label] (id)}
        <button type="button" class="opt" class:on={config.service === id} onclick={() => pickService(id)}>{label}</button>
      {/each}
    </div>

    {#if on}
      {#if config.service === 'discord'}
        <p class="quiet">Every photo is posted into the channel of the webhook. Discord's own links stop working outside Discord after about a day, so for a website pick another place.</p>
      {/if}
      {#if !key}
        <p class="quiet lead">Pictures go into the photos folder of this resource on the server, one file per model. No key is needed. Other pages can show a new file after the resource is restarted.</p>
      {:else}
      <span class="plab">{key.label}</span>
      {#if config.fixed}
        <p class="quiet lead">Set in server.cfg, it ends in {config.tokenEnd}. Change it there.</p>
      {:else if config.hasToken}
        <div class="tokenrow">
          <span class="chip ok"><Icon name="check" />Saved, ends in {config.tokenEnd}</span>
          <button type="button" class="second" onclick={() => uploads.set({ clearToken: true })}>Remove</button>
        </div>
      {:else}
        <div class="saveplace">
          <input type="password" maxlength="200" placeholder={key.hint} autocomplete="off" bind:value={token}
            onkeydown={(e) => { if (e.key === 'Enter' && fits) saveToken(); }} />
          <button type="button" class="second" disabled={!fits} onclick={saveToken}>Save</button>
        </div>
        <p class="quiet">{key.help} It is kept on the server and never shown again. Or put it in server.cfg: set {key.cfg} "..."</p>
      {/if}
      {/if}

      <div class="carrow setrow">
        <span>Save after every photo</span>
        <div class="seg">
          <button type="button" class:on={!config.auto} onclick={() => uploads.set({ auto: false })}>Off</button>
          <button type="button" class:on={config.auto} onclick={() => uploads.set({ auto: true })}>On</button>
        </div>
      </div>

      <div class="carrow">
        <span>File type</span>
        <div class="seg">
          <button type="button" class:on={config.format !== 'png'} onclick={() => uploads.set({ format: 'webp' })}>WebP</button>
          <button type="button" class:on={config.format === 'png'} onclick={() => uploads.set({ format: 'png' })}>PNG</button>
        </div>
      </div>
      <p class="quiet">WebP is several times smaller. Pick PNG when another script only reads .png files.</p>

      <span class="plab">Colours of the saved picture</span>
      <div class="colours setcolours">
        {#each [['primary', 'Primary'], ['secondary', 'Secondary']] as [which, label] (which)}
          <div class="grp">
            <span>{label}</span>
            <div class="sw">
              {#each SWATCHES as hex (hex)}
                <button type="button" aria-label={hex} class:on={config[which as 'primary' | 'secondary'] === hex} style:background={hex}
                  onclick={() => uploads.set({ [which]: hex })}></button>
              {/each}
            </div>
          </div>
        {/each}
      </div>
      <p class="quiet">A link shows one picture, so it has one paint. Pick the one your site or Discord should show.</p>

      <span class="plab">Photos</span>
      <div class="chips">
        <span class="chip num">{fleet.photos.length} {fleet.photos.length === 1 ? 'photo' : 'photos'}</span>
        <span class="chip num">{linked} with a link</span>
      </div>
      {#if uploads.progress}
        <div class="upbar"><i style="width:{(uploads.progress.done / Math.max(1, uploads.progress.total)) * 100}%"></i></div>
        <p class="quiet">Saving {uploads.progress.done} of {uploads.progress.total}. Keep the menu open.</p>
      {/if}
      {#if uploads.error}<p class="quiet red">{uploads.error}</p>{/if}
      <div class="acts small">
        <button type="button" class="act" disabled={!ready || !!uploads.progress || linked === fleet.photos.length} onclick={() => uploads.all(false)}>
          <Icon name="upload" /><span>Save the {fleet.photos.length - linked} without a link</span>
        </button>
        <button type="button" class="act" disabled={!ready || !!uploads.progress || !fleet.photos.length} onclick={() => uploads.all(true)}>
          <Icon name="retake" /><span>Save all again</span>
        </button>
      </div>
      <div class="acts small">
        <button type="button" class="act" disabled={!linked} onclick={copyAll}><Icon name="copy" /><span>{copied ? 'Copied' : 'Copy all links'}</span></button>
      </div>
      <p class="quiet">Other scripts get a link with exports.evolent_studio:GetUrl(model) on the server.</p>
    {/if}
  </section>
</div>
