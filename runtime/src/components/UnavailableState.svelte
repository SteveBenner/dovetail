<script lang="ts">
  import { onDestroy } from 'svelte';
  import CloudSlashIcon from 'phosphor-svelte/lib/CloudSlashIcon';
  import { tInternal } from '../i18n/t.js';

  interface Props {
    what?: string;
    retry?: () => void;
    retry_after_s?: number;
  }

  let { what = '', retry, retry_after_s }: Props = $props();

  const initialSeconds = $derived(retry_after_s ?? 0);
  let remaining = $state(0);
  let timer: ReturnType<typeof setInterval> | null = null;

  $effect(() => {
    remaining = initialSeconds;
    if (timer) clearInterval(timer);
    if (retry_after_s && retry) {
      timer = setInterval(() => {
        remaining -= 1;
        if (remaining <= 0) {
          if (timer) clearInterval(timer);
          retry?.();
        }
      }, 1000);
    }
  });

  onDestroy(() => {
    if (timer) clearInterval(timer);
  });
</script>

<div class="dt-state" role="status" aria-live="polite">
  <CloudSlashIcon aria-hidden="true" size="20" weight="regular" color="var(--warning)" />
  <p class="dt-state__title">{tInternal('dovetail.unavailable.title', { what: what || tInternal('dovetail.unavailable.what_default') })}</p>
  {#if retry_after_s}
    <p class="dt-state__body">{tInternal('dovetail.unavailable.retrying', { seconds: Math.max(0, remaining) })}</p>
  {:else}
    <p class="dt-state__body">{tInternal('dovetail.unavailable.body')}</p>
  {/if}
</div>

<style>
  .dt-state {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: var(--space-2);
    padding: var(--space-6) var(--space-4);
  }
  .dt-state__title {
    font-size: var(--type-sm);
    font-weight: var(--weight-semibold);
    color: var(--text);
  }
  .dt-state__body {
    font-size: var(--type-sm);
    color: var(--text-dim);
    max-width: 60ch;
  }
</style>
