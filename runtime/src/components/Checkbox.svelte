<script lang="ts">
  import CheckIcon from 'phosphor-svelte/lib/CheckIcon';

  interface Props {
    checked?: boolean;
    label?: string;
  }

  let { checked = $bindable(false), label = '' }: Props = $props();
</script>

<label class="dt-checkbox">
  <input type="checkbox" class="dt-checkbox__input" bind:checked />
  <span class="dt-checkbox__box">
    {#if checked}
      <CheckIcon aria-hidden="true" size="12" weight="bold" />
    {/if}
  </span>
  {#if label}
    <span class="dt-checkbox__label">{label}</span>
  {/if}
</label>

<style>
  .dt-checkbox {
    display: inline-flex;
    align-items: center;
    gap: var(--space-2);
    cursor: pointer;
  }
  .dt-checkbox__input {
    position: absolute;
    width: 1px;
    height: 1px;
    overflow: hidden;
    clip: rect(0 0 0 0);
    white-space: nowrap;
  }
  .dt-checkbox__box {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: calc(var(--space-1) * 4);
    height: calc(var(--space-1) * 4);
    border-radius: var(--corner-sm);
    border: 1px solid var(--border-strong);
    background: var(--surface);
    color: var(--accent-contrast);
  }
  .dt-checkbox__input:checked + .dt-checkbox__box {
    background: var(--accent);
    border-color: var(--accent);
  }
  .dt-checkbox__input:focus-visible + .dt-checkbox__box {
    outline: 2px solid var(--accent);
    outline-offset: 2px;
  }
  .dt-checkbox__label {
    font-size: var(--type-sm);
    color: var(--text);
  }
</style>
