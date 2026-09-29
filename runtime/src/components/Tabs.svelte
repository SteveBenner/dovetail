<script lang="ts">
  interface Tab {
    id: string;
    label: string;
  }

  interface Props {
    tabs: Tab[];
    active?: string;
  }

  let { tabs, active = $bindable('') }: Props = $props();

  let refs: Record<string, HTMLButtonElement> = {};

  function move(index: number): void {
    const tab = tabs[index];
    if (!tab) return;
    active = tab.id;
    refs[tab.id]?.focus();
  }

  function onKeydown(event: KeyboardEvent, index: number): void {
    if (event.key === 'ArrowRight') {
      event.preventDefault();
      move((index + 1) % tabs.length);
    } else if (event.key === 'ArrowLeft') {
      event.preventDefault();
      move((index - 1 + tabs.length) % tabs.length);
    } else if (event.key === 'Home') {
      event.preventDefault();
      move(0);
    } else if (event.key === 'End') {
      event.preventDefault();
      move(tabs.length - 1);
    }
  }
</script>

<div role="tablist" class="dt-tabs">
  {#each tabs as tab, index (tab.id)}
    <button
      bind:this={refs[tab.id]}
      type="button"
      role="tab"
      aria-selected={active === tab.id}
      tabindex={active === tab.id ? 0 : -1}
      class="dt-tabs__tab"
      class:dt-tabs__tab--active={active === tab.id}
      onclick={() => (active = tab.id)}
      onkeydown={(event) => onKeydown(event, index)}
    >
      {tab.label}
    </button>
  {/each}
</div>

<style>
  .dt-tabs {
    display: flex;
    gap: var(--space-4);
    border-bottom: 1px solid var(--border);
  }
  .dt-tabs__tab {
    position: relative;
    height: calc(var(--space-1) * 9);
    padding-inline: 0;
    background: transparent;
    border: none;
    font-family: var(--family-sans);
    font-size: var(--type-sm);
    font-weight: var(--weight-medium);
    color: var(--text-dim);
    cursor: pointer;
  }
  .dt-tabs__tab:hover {
    color: var(--text);
  }
  .dt-tabs__tab:focus-visible {
    outline: 2px solid var(--accent);
    outline-offset: 2px;
  }
  .dt-tabs__tab--active {
    color: var(--text);
  }
  .dt-tabs__tab--active::after {
    content: '';
    position: absolute;
    left: 0;
    right: 0;
    bottom: 0;
    height: 2px;
    background: var(--accent);
  }
</style>
