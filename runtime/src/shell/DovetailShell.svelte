<script lang="ts">
  import type { Snippet } from 'svelte';
  import { untrack } from 'svelte';
  import { runtime } from './state.svelte.js';
  import { dispatchRouteChange } from '../seams/navigation/index.js';
  import { dispatchKeydown } from '../seams/keyboard/index.js';
  import { dismissTopDismissible } from '../seams/overlay/index.js';
  import { emitFor } from '../seams/events/index.js';
  import { installDevHooks, removeDevHooks } from '../dev/hooks.js';
  import { onDestroy } from 'svelte';
  import OverlayHost from './OverlayHost.svelte';
  import DevToolbar from '../dev/DevToolbar.svelte';
  import type { Registry, Theme, Transport } from '../types.js';

  interface Props {
    registry: Registry;
    theme: Theme;
    locale?: string;
    transport: Transport;
    onPanelError?: (module: string, error: unknown) => void;
    children?: Snippet;
  }

  let { registry, theme, locale = 'en-US', transport, onPanelError, children }: Props = $props();

  untrack(() => {
    runtime.registry = registry;
    runtime.locale = locale;
    runtime.transport = transport;
    runtime.onPanelError = onPanelError ?? null;
    runtime.theme = theme;
  });

  function themeStyle(activeTheme: Theme): string {
    const declarations = Object.entries(activeTheme.tokens)
      .map(([key, value]) => `--${key}: ${value};`)
      .join(' ');
    return `.dt-shell[data-theme="${activeTheme.id}"] { ${declarations} } @media (prefers-reduced-motion: reduce) { .dt-shell { --motion-fast: 0ms; --motion-base: 0ms; --motion-slow: 0ms; } }`;
  }

  $effect(() => {
    let styleEl = document.querySelector('style[data-dovetail-theme]');
    if (!styleEl) {
      styleEl = document.createElement('style');
      styleEl.setAttribute('data-dovetail-theme', '');
      document.head.appendChild(styleEl);
    }
    styleEl.textContent = themeStyle(theme);
  });

  function onDocumentClick(event: MouseEvent): void {
    const anchor = (event.target as Element)?.closest?.('a[href]') as HTMLAnchorElement | null;
    if (!anchor) return;
    if (anchor.target && anchor.target !== '_self') return;
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
    const url = new URL(anchor.href, location.href);
    if (url.origin !== location.origin) return;
    event.preventDefault();
    history.pushState({}, '', url.pathname + url.search);
    dispatchRouteChange();
  }

  function onDocumentKeydown(event: KeyboardEvent): void {
    if (event.key === 'Escape') {
      dismissTopDismissible();
      return;
    }
    dispatchKeydown(event);
  }

  $effect(() => {
    document.documentElement.style.overflow = runtime.scrollLockCount > 0 ? 'hidden' : '';
    document.documentElement.style.scrollbarGutter = runtime.scrollLockCount > 0 ? 'stable' : '';
  });

  untrack(() => {
    if (location.pathname === '/') {
      const homeModule = registry.layout.home ?? registry.layout.navigation[0]?.module ?? registry.panels[0]?.module ?? null;
      const homePanel = homeModule ? registry.panels.find((p) => p.module === homeModule) : null;
      const firstRoute = homePanel?.routes[0];
      if (firstRoute) {
        history.replaceState({}, '', firstRoute);
      }
    }
    dispatchRouteChange();
  });

  window.addEventListener('popstate', dispatchRouteChange);
  document.addEventListener('click', onDocumentClick);
  document.addEventListener('keydown', onDocumentKeydown);

  onDestroy(() => {
    window.removeEventListener('popstate', dispatchRouteChange);
    document.removeEventListener('click', onDocumentClick);
    document.removeEventListener('keydown', onDocumentKeydown);
  });

  const unsubscribeEvents = untrack(() => {
    const eventIds = [...new Set(registry.panels.flatMap((p) => [...p.emits.map((e) => e.id), ...p.consumes]))];
    (transport as unknown as { setEventIds?(ids: readonly string[]): void }).setEventIds?.(eventIds);
    const warnedVersions = new Set<string>();
    return transport.subscribe('events', (message) => {
      const module = message.event.slice(0, message.event.indexOf('.'));
      const producer = registry.panels.find((p) => p.module === module);
      if (producer && message.contract_version !== producer.contract_version) {
        if (registry.development && !warnedVersions.has(message.event)) {
          warnedVersions.add(message.event);
          console.warn(
            `D-RUN-004 ${message.event} arrived as contract version ${message.contract_version}, expected ${producer.contract_version}`
          );
        }
        return;
      }
      emitFor(module, message.event, message.data, 'server');
    });
  });

  if (untrack(() => registry.development)) {
    installDevHooks();
  }

  onDestroy(() => {
    unsubscribeEvents();
    if (registry.development) removeDevHooks();
  });
</script>

<div class="dt-shell" data-theme={theme.id} data-color-scheme={theme.color_scheme} style:color-scheme={theme.color_scheme}>
  {@render children?.()}
  <OverlayHost />
  {#if registry.development}
    <DevToolbar />
  {/if}
</div>

<style>
  .dt-shell {
    min-height: 100%;
    color: var(--text);
    background: var(--surface);
    font-family: var(--family-sans);
  }
</style>
