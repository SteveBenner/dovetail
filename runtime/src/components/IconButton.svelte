<script lang="ts">
  import type { Component } from 'svelte';
  import Tooltip from './Tooltip.svelte';

  interface Props {
    label: string;
    icon: Component<any>;
    variant?: 'secondary' | 'ghost';
    onclick?: (event: MouseEvent) => void;
    [key: string]: unknown;
  }

  let { label, icon: Icon, variant = 'secondary', onclick, ...rest }: Props = $props();
</script>

<Tooltip text={label}>
  {#snippet children()}
    <button
      type="button"
      class="dt-icon-button dt-icon-button--{variant}"
      aria-label={label}
      {onclick}
      {...rest}
    >
      <Icon aria-hidden="true" size="16" weight="regular" />
    </button>
  {/snippet}
</Tooltip>

<style>
  .dt-icon-button {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: calc(var(--space-1) * 8);
    height: calc(var(--space-1) * 8);
    border-radius: var(--corner-md);
    border: 1px solid transparent;
    cursor: pointer;
    transition: background-color var(--motion-fast) var(--motion-ease), color var(--motion-fast) var(--motion-ease);
  }
  .dt-icon-button:focus-visible {
    outline: 2px solid var(--accent);
    outline-offset: 2px;
  }
  .dt-icon-button--secondary {
    background: var(--surface-2);
    color: var(--text);
    border-color: var(--border-strong);
  }
  .dt-icon-button--secondary:hover {
    background: var(--surface-3);
  }
  .dt-icon-button--ghost {
    background: transparent;
    color: var(--text-dim);
  }
  .dt-icon-button--ghost:hover {
    background: var(--surface-2);
    color: var(--text);
  }
</style>
