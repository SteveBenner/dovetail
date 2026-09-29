<script lang="ts">
  import WrenchIcon from 'phosphor-svelte/lib/WrenchIcon';
  import { tInternal } from '../i18n/t.js';

  interface Props {
    view: string;
    module: string;
  }

  let { view, module }: Props = $props();

  const viewLabel = $derived(view.split('_').map((w) => w.charAt(0).toUpperCase() + w.slice(1)).join(' '));
</script>

<div class="dt-not-built">
  <WrenchIcon aria-hidden="true" size="20" weight="regular" color="var(--text-faint)" />
  <p class="dt-not-built__title">{tInternal('dovetail.notbuilt.title', { view: viewLabel })}</p>
  <p class="dt-not-built__body">{tInternal('dovetail.notbuilt.body', { module })}</p>
</div>

<style>
  .dt-not-built {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: var(--space-2);
    padding: var(--space-5);
    border: 1px dashed var(--border-strong);
    border-radius: var(--corner-lg);
    background: transparent;
  }
  .dt-not-built__title {
    font-size: var(--type-sm);
    font-weight: var(--weight-semibold);
    color: var(--text);
  }
  .dt-not-built__body {
    font-size: var(--type-sm);
    color: var(--text-dim);
  }
</style>
