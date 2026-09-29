<script lang="ts">
  import { getContext } from 'svelte';
  import { FIELD_CONTEXT, type FieldContextValue } from './field-context.js';

  interface Props {
    value?: string;
    placeholder?: string;
    maxlength?: number;
    [key: string]: unknown;
  }

  let { value = $bindable(''), placeholder = '', maxlength, ...rest }: Props = $props();

  const field = getContext<FieldContextValue | undefined>(FIELD_CONTEXT);
</script>

<input
  type="text"
  class="dt-text-input"
  id={field?.controlId}
  aria-describedby={field?.describedBy}
  aria-invalid={field?.invalid || undefined}
  aria-required={field?.required || undefined}
  bind:value
  {placeholder}
  {maxlength}
  {...rest}
/>

<style>
  .dt-text-input {
    height: calc(var(--space-1) * 8);
    padding-inline: var(--space-3);
    background: var(--surface);
    border: 1px solid var(--border-strong);
    border-radius: var(--corner-md);
    color: var(--text);
    font-family: var(--family-sans);
    font-size: var(--type-sm);
    transition: border-color var(--motion-fast) var(--motion-ease), box-shadow var(--motion-fast) var(--motion-ease);
  }
  .dt-text-input::placeholder {
    color: var(--text-faint);
  }
  .dt-text-input:hover {
    border-color: var(--text-faint);
  }
  .dt-text-input:focus-visible {
    outline: none;
    border-color: var(--accent);
    box-shadow: 0 0 0 3px var(--accent-soft);
  }
  .dt-text-input[aria-invalid='true'] {
    border-color: var(--danger);
    box-shadow: 0 0 0 3px color-mix(in srgb, var(--danger) 25%, transparent);
  }
  .dt-text-input:disabled {
    background: var(--surface-2);
    color: var(--text-faint);
  }
</style>
