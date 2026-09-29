<script lang="ts">
  import WarningCircleIcon from 'phosphor-svelte/lib/WarningCircleIcon';
  import ArrowClockwiseIcon from 'phosphor-svelte/lib/ArrowClockwiseIcon';
  import Button from './Button.svelte';
  import { tInternal } from '../i18n/t.js';

  interface Props {
    title?: string;
    body?: string;
    retry?: () => void;
  }

  let { title = '', body = '', retry }: Props = $props();
</script>

<div class="dt-state" role="alert" aria-live="polite">
  <WarningCircleIcon aria-hidden="true" size="20" weight="regular" color="var(--danger)" />
  <p class="dt-state__title">{title || tInternal('dovetail.error.title')}</p>
  <p class="dt-state__body">{body || tInternal('dovetail.error.body')}</p>
  {#if retry}
    <Button variant="secondary" size="sm" onclick={retry}>
      <ArrowClockwiseIcon aria-hidden="true" size="16" weight="regular" />
      {tInternal('dovetail.error.retry')}
    </Button>
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
