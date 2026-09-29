<script lang="ts">
  interface Props {
    checked?: boolean;
    label?: string;
  }

  let { checked = $bindable(false), label = '' }: Props = $props();
</script>

<span class="dt-switch">
  <button
    type="button"
    role="switch"
    aria-checked={checked}
    aria-label={label}
    class="dt-switch__track"
    class:dt-switch__track--on={checked}
    onclick={() => (checked = !checked)}
  >
    <span class="dt-switch__thumb"></span>
  </button>
  {#if label}
    <span class="dt-switch__label">{label}</span>
  {/if}
</span>

<style>
  .dt-switch {
    display: inline-flex;
    align-items: center;
    gap: var(--space-2);
  }
  .dt-switch__track {
    position: relative;
    width: calc(var(--space-1) * 8);
    height: calc(var(--space-1) * 4.5);
    border-radius: var(--corner-full);
    border: 1px solid var(--border-strong);
    background: var(--surface-3);
    cursor: pointer;
  }
  .dt-switch__track--on {
    background: var(--accent);
    border-color: var(--accent);
  }
  .dt-switch__track:focus-visible {
    outline: 2px solid var(--accent);
    outline-offset: 2px;
  }
  .dt-switch__thumb {
    position: absolute;
    top: calc(var(--space-1) * 0.5);
    left: calc(var(--space-1) * 0.5);
    width: calc(var(--space-1) * 3);
    height: calc(var(--space-1) * 3);
    border-radius: var(--corner-full);
    background: var(--text-dim);
    transition: transform var(--motion-fast) var(--motion-ease), background-color var(--motion-fast) var(--motion-ease);
  }
  .dt-switch__track--on .dt-switch__thumb {
    background: var(--accent-contrast);
    transform: translateX(calc(var(--space-1) * 3.5));
  }
  .dt-switch__label {
    font-size: var(--type-sm);
    color: var(--text);
  }
</style>
