<script lang="ts">
  import registry from '$registry';
  import { DovetailShell, Slot, useNavigation, createDevelopmentTransport, createHttpTransport, t } from '@dovetail/runtime';

  const transport = registry.development && !import.meta.env.VITE_DOVETAIL_BACKEND
    ? createDevelopmentTransport()
    : createHttpTransport({ baseUrl: '' });

  const theme = registry.themes[0];
  const locale = 'en-US';

  const hasAside = registry.panels.some((p) => p.slots.some((s) => s.name === 'aside'));
  const hasDock = registry.panels.some((p) => p.slots.some((s) => s.name === 'dock'));
  const homeModule = registry.layout.home;

  const navigation = $derived(useNavigation());
</script>

<DovetailShell {registry} {theme} {locale} {transport} onPanelError={() => {}}>
  {#snippet children()}
    <div class="dt-app-root">
      <header class="dt-app-header">
        <h1>{t('shell.title')}</h1>
      </header>
      <nav class="dt-app-nav" aria-label={t('shell.nav')}>
        {#each navigation as item}
          <a href={item.href} class:active={item.active} aria-current={item.active ? 'page' : undefined}>{item.label}</a>
        {/each}
      </nav>
      <div class="dt-app-content" class:with-aside={hasAside}>
        <main class="dt-app-main">
          <Slot name="main" />
          {#if homeModule}
            <div class="dt-app-tiles">
              <Slot name="tiles" />
            </div>
          {/if}
        </main>
        {#if hasAside}
          <aside class="dt-app-aside">
            <Slot name="aside" />
          </aside>
        {/if}
      </div>
      {#if hasDock}
        <section class="dt-app-dock" aria-label={t('shell.dock')}>
          <Slot name="dock" />
        </section>
      {/if}
    </div>
  {/snippet}
</DovetailShell>

<style>
  .dt-app-root {
    min-height: 100dvh;
    background: var(--surface);
    color: var(--text);
    font-family: var(--family-sans);
    display: flex;
    flex-direction: column;
  }

  .dt-app-header {
    height: calc(var(--space-1) * 14);
    display: flex;
    align-items: center;
    padding-inline: var(--space-6);
    border-bottom: 1px solid var(--border);
  }

  .dt-app-header h1 {
    font-size: var(--type-base);
    font-weight: var(--weight-semibold);
    margin: 0;
  }

  .dt-app-nav {
    height: calc(var(--space-1) * 11);
    display: flex;
    align-items: center;
    gap: var(--space-5);
    padding-inline: var(--space-6);
    border-bottom: 1px solid var(--border);
    overflow-x: auto;
    white-space: nowrap;
  }

  .dt-app-nav a {
    font-size: var(--type-sm);
    font-weight: var(--weight-medium);
    color: var(--text-dim);
    text-decoration: none;
    position: relative;
    padding-bottom: var(--space-2);
  }

  .dt-app-nav a:hover {
    color: var(--text);
  }

  .dt-app-nav a.active {
    color: var(--text);
  }

  .dt-app-nav a.active::after {
    content: '';
    position: absolute;
    left: 0;
    right: 0;
    bottom: 0;
    height: 2px;
    background: var(--accent);
  }

  .dt-app-content {
    max-width: var(--max-width);
    margin-inline: auto;
    width: 100%;
    padding: var(--space-6);
    display: grid;
    grid-template-columns: minmax(0, 1fr);
    gap: var(--space-6);
    flex: 1;
  }

  @media (max-width: 767px) {
    .dt-app-content {
      padding: var(--space-4);
    }
  }

  @media (min-width: 768px) {
    .dt-app-content.with-aside {
      grid-template-columns: minmax(0, 1fr) minmax(calc(var(--space-1) * 70), calc(var(--space-1) * 90));
    }
  }

  .dt-app-main {
    min-width: 0;
  }

  .dt-app-tiles {
    margin-top: var(--space-4);
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(calc(var(--space-1) * 70), 1fr));
    gap: var(--space-4);
  }

  .dt-app-aside {
    min-width: 0;
  }

  .dt-app-dock {
    border-top: 1px solid var(--border);
    padding: var(--space-3) var(--space-6);
    max-height: calc(var(--space-1) * 40);
    overflow: auto;
  }
</style>
