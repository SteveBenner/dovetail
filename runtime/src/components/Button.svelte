<script lang="ts">
  import type { Snippet } from 'svelte';
  import Tooltip from './Tooltip.svelte';

  interface Props {
    variant?: 'primary' | 'secondary' | 'ghost' | 'danger';
    size?: 'sm' | 'md';
    disabled?: boolean;
    reason?: string;
    loading?: boolean;
    onclick?: (event: MouseEvent) => void;
    children?: Snippet;
    [key: string]: unknown;
  }

  let {
    variant = 'primary',
    size = 'md',
    disabled = false,
    reason = '',
    loading = false,
    onclick,
    children,
    ...rest
  }: Props = $props();

  function handleClick(event: MouseEvent) {
    if (disabled || loading) {
      event.preventDefault();
      return;
    }
    onclick?.(event);
  }
</script>

{#snippet buttonEl()}
  <button
    type="button"
    class="dt-button dt-button--{variant} dt-button--{size}"
    class:dt-button--loading={loading}
    aria-disabled={disabled}
    aria-busy={loading}
    onclick={handleClick}
    {...rest}
  >
    <span class="dt-button__label">{@render children?.()}</span>
  </button>
{/snippet}

{#if disabled && reason}
  <Tooltip text={reason} trigger={buttonEl} />
{:else}
  {@render buttonEl()}
{/if}

<style>
  .dt-button {
    position: relative;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    gap: var(--space-2);
    border-radius: var(--corner-md);
    border: 1px solid transparent;
    white-space: nowrap;
    font-family: var(--family-sans);
    font-weight: var(--weight-medium);
    cursor: pointer;
    transition: background-color var(--motion-fast) var(--motion-ease), border-color var(--motion-fast) var(--motion-ease),
      color var(--motion-fast) var(--motion-ease), transform var(--motion-fast) var(--motion-ease);
  }
  .dt-button:active {
    transform: translateY(1px);
  }
  .dt-button:focus-visible {
    outline: 2px solid var(--accent);
    outline-offset: 2px;
  }
  .dt-button--md {
    height: calc(var(--space-1) * 8);
    padding-inline: var(--space-3);
    font-size: var(--type-sm);
    line-height: var(--type-sm-leading);
  }
  .dt-button--sm {
    height: calc(var(--space-1) * 7);
    padding-inline: var(--space-2);
    font-size: var(--type-sm);
    line-height: var(--type-sm-leading);
  }
  .dt-button--primary {
    background: var(--accent);
    color: var(--accent-contrast);
  }
  .dt-button--primary:hover {
    background: var(--accent-hover);
  }
  .dt-button--secondary {
    background: var(--surface-2);
    color: var(--text);
    border-color: var(--border-strong);
  }
  .dt-button--secondary:hover {
    background: var(--surface-3);
  }
  .dt-button--ghost {
    background: transparent;
    color: var(--text-dim);
  }
  .dt-button--ghost:hover {
    background: var(--surface-2);
    color: var(--text);
  }
  .dt-button--danger {
    background: var(--danger);
    color: var(--danger-contrast);
  }
  .dt-button--danger:hover {
    background: color-mix(in srgb, var(--danger) 88%, var(--text));
  }
  .dt-button[aria-disabled='true'] {
    background: var(--surface-2);
    color: var(--text-faint);
    border-color: var(--border);
    cursor: not-allowed;
  }
  .dt-button__label {
    display: inline-flex;
    align-items: center;
    gap: var(--space-2);
  }
  .dt-button--loading .dt-button__label {
    opacity: 0.72;
  }
  .dt-button--loading {
    overflow: hidden;
  }
  .dt-button--loading::after {
    content: '';
    position: absolute;
    left: 0;
    bottom: 0;
    height: 2px;
    width: 40%;
    background: currentColor;
    animation: dt-button-loading 1.1s linear infinite;
  }
  @media (prefers-reduced-motion: reduce) {
    .dt-button--loading::after {
      animation: none;
      width: 100%;
      opacity: 0.4;
    }
  }
  @keyframes dt-button-loading {
    from {
      transform: translateX(-100%);
    }
    to {
      transform: translateX(250%);
    }
  }
</style>
