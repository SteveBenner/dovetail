<script lang="ts">
  import { getContext } from 'svelte';
  import { FIELD_CONTEXT, type FieldContextValue } from './field-context.js';
  import { runtime } from '../shell/state.svelte.js';

  interface Props {
    value?: string;
    min?: string;
    max?: string;
    step?: string;
    [key: string]: unknown;
  }

  let { value = $bindable(''), min, max, step, ...rest }: Props = $props();

  const field = getContext<FieldContextValue | undefined>(FIELD_CONTEXT);

  let text = $state(value);
  let invalid = $state(false);

  function separators(): { group: string; decimal: string } {
    const parts = new Intl.NumberFormat(runtime.locale).formatToParts(1234.5);
    const group = parts.find((p) => p.type === 'group')?.value ?? ',';
    const decimal = parts.find((p) => p.type === 'decimal')?.value ?? '.';
    return { group, decimal };
  }

  function handleBlur(): void {
    queueMicrotask(normalize);
  }

  function normalize(): void {
    const { group, decimal } = separators();
    const normalized = text.split(group).join('').split(decimal).join('.').trim();
    if (normalized === '' || Number.isNaN(Number(normalized))) {
      invalid = true;
      return;
    }
    invalid = false;
    value = normalized;
    text = normalized;
  }
</script>

<input
  type="text"
  inputmode="decimal"
  class="dt-number-input"
  id={field?.controlId}
  aria-describedby={field?.describedBy}
  aria-invalid={field?.invalid || invalid || undefined}
  aria-required={field?.required || undefined}
  bind:value={text}
  onblur={handleBlur}
  data-min={min}
  data-max={max}
  data-step={step}
  {...rest}
/>

<style>
  .dt-number-input {
    height: calc(var(--space-1) * 8);
    padding-inline: var(--space-3);
    background: var(--surface);
    border: 1px solid var(--border-strong);
    border-radius: var(--corner-md);
    color: var(--text);
    font-family: var(--family-sans);
    font-size: var(--type-sm);
    text-align: right;
    font-variant-numeric: tabular-nums;
    transition: border-color var(--motion-fast) var(--motion-ease), box-shadow var(--motion-fast) var(--motion-ease);
  }
  .dt-number-input:hover {
    border-color: var(--text-faint);
  }
  .dt-number-input:focus-visible {
    outline: none;
    border-color: var(--accent);
    box-shadow: 0 0 0 3px var(--accent-soft);
  }
  .dt-number-input[aria-invalid='true'] {
    border-color: var(--danger);
    box-shadow: 0 0 0 3px color-mix(in srgb, var(--danger) 25%, transparent);
  }
</style>
