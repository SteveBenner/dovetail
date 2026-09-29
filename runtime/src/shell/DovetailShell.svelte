<script lang="ts">
  import type { Snippet } from 'svelte';
  import { untrack } from 'svelte';
  import { runtime, styleContainer, closeOverlayById } from './state.svelte.js';
  import { createHistoryLocation, createMemoryLocation } from './location.svelte.js';
  import { createHttpTransport } from '../transport/http.js';
  import { dispatchRouteChange } from '../seams/navigation/index.js';
  import { dispatchKeydown } from '../seams/keyboard/index.js';
  import { dismissTopDismissible } from '../seams/overlay/index.js';
  import { startPrefetch } from './prefetch.js';
  import { validate } from '../validate/jsonschema.js';
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
    routing?: 'history' | 'memory';
    initialPath?: string;
    versionPolicy?: 'strict' | 'tolerant';
    prefetch?: boolean;
    children?: Snippet;
  }

  let { registry, theme, locale = 'en-US', transport, onPanelError, routing = 'history', initialPath = '/', versionPolicy = 'strict', prefetch = true, children }: Props = $props();

  untrack(() => {
    runtime.registry = registry;
    runtime.locale = runtime.hostOptions?.locale ?? locale;
    const apiBase = runtime.hostOptions?.apiBase;
    runtime.transport = typeof apiBase === 'string' ? createHttpTransport({ baseUrl: apiBase }) : transport;
    runtime.onPanelError = onPanelError ?? null;
    runtime.versionPolicy = runtime.hostOptions?.versionPolicy ?? versionPolicy;
    runtime.prefetchEnabled = runtime.hostOptions?.prefetch ?? prefetch;
    runtime.theme = registry.themes.find((t) => t.id === runtime.hostOptions?.theme) ?? theme;
  });

  const activeTheme = $derived(runtime.theme ?? theme);

  function themeStyle(activeTheme: Theme): string {
    const declarations = Object.entries(activeTheme.tokens)
      .map(([key, value]) => `--${key}: ${value};`)
      .join(' ');
    return `.dt-shell[data-theme="${activeTheme.id}"] { ${declarations} } @media (prefers-reduced-motion: reduce) { .dt-shell { --motion-fast: 0ms; --motion-base: 0ms; --motion-slow: 0ms; } }`;
  }

  $effect(() => {
    const container = styleContainer() as ParentNode & Node;
    let styleEl = container.querySelector('style[data-dovetail-theme]');
    if (!styleEl) {
      styleEl = document.createElement('style');
      styleEl.setAttribute('data-dovetail-theme', '');
      container.appendChild(styleEl);
    }
    styleEl.textContent = themeStyle(activeTheme);
  });

  function onRootClick(event: Event): void {
    const mouse = event as MouseEvent;
    const origin = (mouse.composedPath()[0] ?? mouse.target) as Element | null;
    const anchor = origin?.closest?.('a[href]') as HTMLAnchorElement | null;
    if (!anchor) return;
    if (anchor.target && anchor.target !== '_self') return;
    if (mouse.defaultPrevented || mouse.button !== 0 || mouse.metaKey || mouse.ctrlKey || mouse.shiftKey || mouse.altKey) return;
    const url = new URL(anchor.href, location.href);
    if (url.origin !== location.origin) return;
    mouse.preventDefault();
    runtime.location.push(url.pathname + url.search);
    dispatchRouteChange();
  }

  function onRootKeydown(event: Event): void {
    const keyEvent = event as KeyboardEvent;
    if (keyEvent.key === 'Escape') {
      if (dismissTopDismissible()) keyEvent.preventDefault();
      return;
    }
    dispatchKeydown(keyEvent);
  }

  $effect(() => {
    document.documentElement.style.overflow = runtime.scrollLockCount > 0 ? 'hidden' : '';
    document.documentElement.style.scrollbarGutter = runtime.scrollLockCount > 0 ? 'stable' : '';
  });

  const root = runtime.root;

  const stopListening = untrack(() => {
    const effectiveRouting = runtime.hostOptions?.routing ?? routing;
    const effectivePath = runtime.hostOptions?.path ?? initialPath;
    runtime.location = effectiveRouting === 'memory' ? createMemoryLocation(effectivePath) : createHistoryLocation();
    if (runtime.location.path() === '/') {
      const homeModule = registry.layout.home ?? registry.layout.navigation[0]?.module ?? registry.panels[0]?.module ?? null;
      const homePanel = homeModule ? registry.panels.find((p) => p.module === homeModule) : null;
      const firstRoute = homePanel?.routes[0];
      if (firstRoute) {
        runtime.location.replace(firstRoute);
      }
    }
    dispatchRouteChange();
    return runtime.location.listen(dispatchRouteChange);
  });
  root.addEventListener('click', onRootClick);
  root.addEventListener('keydown', onRootKeydown);

  onDestroy(() => {
    stopListening();
    root.removeEventListener('click', onRootClick);
    root.removeEventListener('keydown', onRootKeydown);
    for (const overlay of [...runtime.overlays]) closeOverlayById(overlay.id, undefined);
    runtime.toasts.length = 0;
    document.documentElement.style.overflow = '';
    document.documentElement.style.scrollbarGutter = '';
  });

  const unsubscribeEvents = untrack(() => {
    const eventIds = [...new Set(registry.panels.flatMap((p) => [...p.emits.map((e) => e.id), ...p.consumes]))];
    (runtime.transport as unknown as { setEventIds?(ids: readonly string[]): void }).setEventIds?.(eventIds);
    const warnedVersions = new Set<string>();
    return runtime.transport!.subscribe('events', (message) => {
      const module = message.event.slice(0, message.event.indexOf('.'));
      const producer = registry.panels.find((p) => p.module === module);
      if (producer && message.contract_version !== producer.contract_version) {
        const emitted = producer.emits.find((e) => e.id === message.event);
        if (runtime.versionPolicy === 'tolerant' && emitted && validate(emitted.payload_schema, message.data).length === 0) {
          if (registry.development && !runtime.negotiatedWarned.has(message.event)) {
            runtime.negotiatedWarned.add(message.event);
            console.warn(
              `D-RUN-008 ${message.event} accepted at contract version ${message.contract_version}, expected ${producer.contract_version}`
            );
          }
          emitFor(module, message.event, message.data, 'server');
          return;
        }
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

  $effect.pre(() => {
    const path = runtime.route.path;
    const module = runtime.route.module;
    void path;
    void module;
    if (!runtime.prefetchEnabled || !runtime.transport || !runtime.registry) return;
    untrack(() => startPrefetch(runtime.route));
  });

  if (untrack(() => registry.development)) {
    installDevHooks();
  }

  onDestroy(() => {
    unsubscribeEvents();
    if (registry.development) removeDevHooks();
  });
</script>

<div class="dt-shell" data-theme={activeTheme.id} data-color-scheme={activeTheme.color_scheme} style:color-scheme={activeTheme.color_scheme}>
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
