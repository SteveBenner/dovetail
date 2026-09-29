<script lang="ts">
  import WarningOctagonIcon from 'phosphor-svelte/lib/WarningOctagonIcon';
  import ArrowClockwiseIcon from 'phosphor-svelte/lib/ArrowClockwiseIcon';
  import Button from '../components/Button.svelte';
  import { tInternal } from '../i18n/t.js';

  interface Props {
    module: string;
    summary: string;
    parked: boolean;
    onreload: () => void;
  }

  let { module, summary, parked, onreload }: Props = $props();
</script>

<div class="dt-fallback" role="alert">
  <WarningOctagonIcon aria-hidden="true" size="20" weight="regular" color="var(--danger)" />
  <p class="dt-fallback__title">{tInternal('dovetail.fallback.title', { module })}</p>
  <p class="dt-fallback__summary">{summary}</p>
  {#if parked}
    <p class="dt-fallback__parked">{tInternal('dovetail.fallback.parked')}</p>
  {:else}
    <Button variant="secondary" size="sm" onclick={onreload}>
      <ArrowClockwiseIcon aria-hidden="true" size="16" weight="regular" />
      {tInternal('dovetail.fallback.reload')}
    </Button>
  {/if}
</div>

<style>
  .dt-fallback {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: var(--space-2);
    background: var(--surface-2);
    border: 1px solid var(--border);
    border-radius: var(--corner-lg);
    padding: var(--space-5);
    box-shadow: inset 0 2px 0 var(--danger);
  }
  .dt-fallback__title {
    font-size: var(--type-sm);
    font-weight: var(--weight-semibold);
    color: var(--text);
  }
  .dt-fallback__summary {
    font-size: var(--type-xs);
    font-family: var(--family-mono);
    color: var(--text-dim);
    display: -webkit-box;
    -webkit-line-clamp: 3;
    line-clamp: 3;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  .dt-fallback__parked {
    font-size: var(--type-sm);
    color: var(--text-dim);
  }
</style>
