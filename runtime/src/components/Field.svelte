<script lang="ts">
  import type { Snippet } from 'svelte';
  import { setContext } from 'svelte';
  import { useIdFor } from '../seams/identity/index.js';
  import { FIELD_CONTEXT } from './field-context.js';
  import WarningCircleIcon from 'phosphor-svelte/lib/WarningCircleIcon';

  interface Props {
    label: string;
    hint?: string;
    error?: string;
    required?: boolean;
    children?: Snippet;
  }

  let { label, hint = '', error = '', required = false, children }: Props = $props();

  const uid = Math.random().toString(36).slice(2, 8);
  const controlId = useIdFor(undefined, `field-${uid}`);
  const hintId = useIdFor(undefined, `field-${uid}-hint`);
  const errorId = useIdFor(undefined, `field-${uid}-error`);

  const describedBy = $derived([hint ? hintId : null, error ? errorId : null].filter(Boolean).join(' ') || undefined);

  setContext(FIELD_CONTEXT, {
    get controlId() {
      return controlId;
    },
    get describedBy() {
      return describedBy;
    },
    get invalid() {
      return Boolean(error);
    },
    get required() {
      return required;
    }
  });
</script>

<div class="dt-field">
  <label class="dt-field__label" for={controlId}>
    {label}
    {#if required}
      <span class="dt-field__required">Required</span>
    {/if}
  </label>
  {@render children?.()}
  {#if hint}
    <p id={hintId} class="dt-field__hint">{hint}</p>
  {/if}
  {#if error}
    <p id={errorId} class="dt-field__error">
      <WarningCircleIcon aria-hidden="true" size="12" weight="regular" />
      {error}
    </p>
  {/if}
</div>

<style>
  .dt-field {
    display: flex;
    flex-direction: column;
    gap: var(--space-1_5);
  }
  .dt-field__label {
    font-size: var(--type-sm);
    font-weight: var(--weight-medium);
    color: var(--text);
  }
  .dt-field__required {
    margin-left: var(--space-2);
    font-size: var(--type-xs);
    color: var(--text-faint);
  }
  .dt-field__hint {
    font-size: var(--type-xs);
    color: var(--text-dim);
  }
  .dt-field__error {
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
    font-size: var(--type-xs);
    color: var(--danger);
  }
</style>
