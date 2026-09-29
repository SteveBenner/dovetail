<script lang="ts">
  import type { Snippet } from 'svelte';
  import { getContext } from 'svelte';
  import { HEADING_CONTEXT } from '../shell/heading-context.js';

  interface Props {
    title?: string;
    tone?: 'default' | 'accent' | 'warning' | 'danger';
    children?: Snippet;
  }

  let { title = '', tone = 'default', children }: Props = $props();

  const slotLevel = getContext<number>(HEADING_CONTEXT) ?? 2;
  const headingTag = `h${Math.min(6, slotLevel + 1)}`;
</script>

<section class="dt-card dt-card--{tone}">
  {#if title}
    <svelte:element this={headingTag} class="dt-card__title">{title}</svelte:element>
  {/if}
  {@render children?.()}
</section>

<style>
  .dt-card {
    background: var(--surface-2);
    border: 1px solid var(--border);
    border-radius: var(--corner-lg);
    padding: var(--space-4);
  }
  .dt-card__title {
    margin: 0 0 var(--space-3) 0;
    font-size: var(--type-sm);
    font-weight: var(--weight-semibold);
    color: var(--text);
  }
  .dt-card--accent {
    box-shadow: inset 0 2px 0 var(--accent);
  }
  .dt-card--warning {
    box-shadow: inset 0 2px 0 var(--warning);
  }
  .dt-card--danger {
    box-shadow: inset 0 2px 0 var(--danger);
  }
</style>
