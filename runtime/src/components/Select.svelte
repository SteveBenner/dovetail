<script lang="ts">
  import { getContext } from 'svelte';
  import { FIELD_CONTEXT, type FieldContextValue } from './field-context.js';
  import { Z_FLOATING } from '../shell/zindex.js';
  import CaretDownIcon from 'phosphor-svelte/lib/CaretDownIcon';
  import CheckIcon from 'phosphor-svelte/lib/CheckIcon';

  interface Option {
    value: string;
    label: string;
  }

  interface Props {
    value?: string;
    options: Option[];
    'aria-label'?: string;
    'data-testid'?: string;
  }

  let { value = $bindable(''), options, 'aria-label': ariaLabel, 'data-testid': testId }: Props = $props();

  const field = getContext<FieldContextValue | undefined>(FIELD_CONTEXT);

  let open = $state(false);
  let active = $state(0);
  let trigger: HTMLButtonElement | undefined = $state();
  let coords = $state({ top: 0, left: 0, width: 0 });
  let typeahead = '';
  let typeaheadTimer: ReturnType<typeof setTimeout> | null = null;

  const selected = $derived(options.find((o) => o.value === value));

  function position(): void {
    if (!trigger) return;
    const rect = trigger.getBoundingClientRect();
    coords = { top: rect.bottom + 4, left: rect.left, width: rect.width };
  }

  function openList(): void {
    position();
    active = Math.max(0, options.findIndex((o) => o.value === value));
    open = true;
  }

  function closeList(): void {
    open = false;
  }

  function choose(index: number): void {
    const option = options[index];
    if (!option) return;
    value = option.value;
    closeList();
    trigger?.focus();
  }

  function onTriggerKeydown(event: KeyboardEvent): void {
    if (['Enter', ' ', 'ArrowDown', 'ArrowUp'].includes(event.key)) {
      event.preventDefault();
      openList();
    }
  }

  function onListKeydown(event: KeyboardEvent): void {
    if (event.key === 'ArrowDown') {
      event.preventDefault();
      active = Math.min(options.length - 1, active + 1);
    } else if (event.key === 'ArrowUp') {
      event.preventDefault();
      active = Math.max(0, active - 1);
    } else if (event.key === 'Home') {
      event.preventDefault();
      active = 0;
    } else if (event.key === 'End') {
      event.preventDefault();
      active = options.length - 1;
    } else if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      choose(active);
    } else if (event.key === 'Escape') {
      event.preventDefault();
      closeList();
      trigger?.focus();
    } else if (event.key === 'Tab') {
      closeList();
    } else if (event.key.length === 1) {
      typeahead += event.key.toLowerCase();
      if (typeaheadTimer) clearTimeout(typeaheadTimer);
      typeaheadTimer = setTimeout(() => {
        typeahead = '';
      }, 500);
      const match = options.findIndex((o) => o.label.toLowerCase().startsWith(typeahead));
      if (match >= 0) active = match;
    }
  }
</script>

<button
  type="button"
  class="dt-select-trigger"
  id={field?.controlId}
  aria-label={ariaLabel}
  data-testid={testId}
  aria-describedby={field?.describedBy}
  aria-haspopup="listbox"
  aria-expanded={open}
  bind:this={trigger}
  onclick={() => (open ? closeList() : openList())}
  onkeydown={onTriggerKeydown}
>
  <span>{selected?.label ?? ''}</span>
  <CaretDownIcon aria-hidden="true" size="16" weight="regular" />
</button>

{#if open}
  <div
    role="listbox"
    tabindex="-1"
    class="dt-select-listbox"
    style:top="{coords.top}px"
    style:left="{coords.left}px"
    style:width="{coords.width}px"
    style:z-index={Z_FLOATING}
    onkeydown={onListKeydown}
    onpointerleave={() => {}}
  >
    {#each options as option, index (option.value)}
      <div
        role="option"
        tabindex="-1"
        aria-selected={option.value === value}
        class="dt-select-option"
        class:dt-select-option--active={index === active}
        onpointerenter={() => (active = index)}
        onclick={() => choose(index)}
        onkeydown={onListKeydown}
      >
        <span>{option.label}</span>
        {#if option.value === value}
          <CheckIcon aria-hidden="true" size="14" weight="bold" />
        {/if}
      </div>
    {/each}
  </div>
{/if}

<svelte:window
  onpointerdown={(event) => {
    if (open && trigger && !trigger.contains(event.target as Node)) closeList();
  }}
/>

<style>
  .dt-select-trigger {
    display: inline-flex;
    align-items: center;
    justify-content: space-between;
    gap: var(--space-2);
    width: 100%;
    height: calc(var(--space-1) * 8);
    padding-inline: var(--space-3);
    background: var(--surface);
    border: 1px solid var(--border-strong);
    border-radius: var(--corner-md);
    color: var(--text);
    font-family: var(--family-sans);
    font-size: var(--type-sm);
    cursor: pointer;
  }
  .dt-select-trigger:hover {
    border-color: var(--text-faint);
  }
  .dt-select-trigger:focus-visible {
    outline: none;
    border-color: var(--accent);
    box-shadow: 0 0 0 3px var(--accent-soft);
  }
  .dt-select-listbox {
    position: fixed;
    background: var(--surface-3);
    border: 1px solid var(--border-strong);
    border-radius: var(--corner-md);
    box-shadow: var(--elevation-md);
    padding: var(--space-1);
    max-height: calc(var(--space-1) * 70);
    overflow: auto;
  }
  .dt-select-option {
    display: flex;
    align-items: center;
    justify-content: space-between;
    height: calc(var(--space-1) * 8);
    padding-inline: var(--space-2);
    border-radius: var(--corner-sm);
    font-size: var(--type-sm);
    color: var(--text);
    cursor: pointer;
  }
  .dt-select-option--active {
    background: var(--surface-2);
  }
  .dt-select-option :global(svg) {
    color: var(--accent);
  }
</style>
