<script lang="ts">
  interface Props {
    name: string;
    close: (result?: unknown) => void;
  }

  let { name, close }: Props = $props();
</script>

<div class="dt-probe">
  <h2 class="dt-probe__title">{name}</h2>
  <button type="button" class="dt-probe__button" onclick={() => close()}>Close</button>
</div>

<style>
  .dt-probe {
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }
  .dt-probe__title {
    font-size: var(--type-sm);
    font-weight: var(--weight-semibold);
    color: var(--text);
  }
  .dt-probe__button {
    align-self: flex-start;
    height: calc(var(--space-1) * 8);
    padding-inline: var(--space-3);
    border-radius: var(--corner-md);
    border: 1px solid var(--border-strong);
    background: var(--surface-2);
    color: var(--text);
    cursor: pointer;
  }
</style>
