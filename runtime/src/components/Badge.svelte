<script lang="ts">
  import type { Snippet } from 'svelte';

  interface Props {
    tone?: 'neutral' | 'success' | 'warning' | 'danger' | 'info';
    children?: Snippet;
  }

  let { tone = 'neutral', children }: Props = $props();
</script>

<span class="dt-badge dt-badge--{tone}">
  {@render children?.()}
</span>

<style>
  .dt-badge {
    display: inline-flex;
    align-items: center;
    height: calc(var(--space-1) * 5);
    padding-inline: var(--space-2);
    border-radius: var(--corner-full);
    font-size: var(--type-xs);
    font-weight: var(--weight-medium);
    border: 1px solid transparent;
  }
  .dt-badge--neutral {
    background: var(--surface-3);
    color: var(--text-dim);
  }
  .dt-badge--success {
    color: var(--success);
    background: color-mix(in srgb, var(--success) 14%, transparent);
    border-color: color-mix(in srgb, var(--success) 32%, transparent);
  }
  .dt-badge--warning {
    color: var(--warning);
    background: color-mix(in srgb, var(--warning) 14%, transparent);
    border-color: color-mix(in srgb, var(--warning) 32%, transparent);
  }
  .dt-badge--danger {
    color: var(--danger);
    background: color-mix(in srgb, var(--danger) 14%, transparent);
    border-color: color-mix(in srgb, var(--danger) 32%, transparent);
  }
  .dt-badge--info {
    color: var(--info);
    background: color-mix(in srgb, var(--info) 14%, transparent);
    border-color: color-mix(in srgb, var(--info) 32%, transparent);
  }
</style>
