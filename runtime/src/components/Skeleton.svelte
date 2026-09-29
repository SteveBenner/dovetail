<script lang="ts">
  interface Props {
    lines?: number;
    shape?: 'text' | 'block' | 'table';
  }

  let { lines = 3, shape = 'text' }: Props = $props();
</script>

<div class="dt-skeleton" role="status" aria-label="Loading">
  {#if shape === 'text'}
    {#each Array(lines) as _, i (i)}
      <div class="dt-skeleton__bar" class:dt-skeleton__bar--short={i === lines - 1}></div>
    {/each}
  {:else if shape === 'block'}
    <div class="dt-skeleton__block"></div>
  {:else}
    {#each Array(5) as _, row (row)}
      <div class="dt-skeleton__row">
        <div class="dt-skeleton__cell" style:width="40%"></div>
        <div class="dt-skeleton__cell" style:width="25%"></div>
        <div class="dt-skeleton__cell" style:width="15%"></div>
      </div>
    {/each}
  {/if}
</div>

<style>
  .dt-skeleton {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
  }
  .dt-skeleton__bar {
    height: var(--space-3);
    border-radius: var(--corner-sm);
    background: var(--surface-3);
    animation: dt-skeleton-pulse 1.6s ease-in-out infinite;
  }
  .dt-skeleton__bar--short {
    width: 60%;
  }
  .dt-skeleton__block {
    height: calc(var(--space-1) * 24);
    border-radius: var(--corner-md);
    background: var(--surface-3);
    animation: dt-skeleton-pulse 1.6s ease-in-out infinite;
  }
  .dt-skeleton__row {
    display: flex;
    align-items: center;
    gap: var(--space-3);
    height: calc(var(--space-1) * 9);
    border-bottom: 1px solid var(--border);
  }
  .dt-skeleton__cell {
    height: var(--space-3);
    border-radius: var(--corner-sm);
    background: var(--surface-3);
    animation: dt-skeleton-pulse 1.6s ease-in-out infinite;
  }
  @keyframes dt-skeleton-pulse {
    0%, 100% {
      opacity: 1;
    }
    50% {
      opacity: 0.55;
    }
  }
  @media (prefers-reduced-motion: reduce) {
    .dt-skeleton__bar,
    .dt-skeleton__block,
    .dt-skeleton__cell {
      animation: none;
    }
  }
</style>
