<script lang="ts">
  import type { Snippet } from 'svelte';
  import { Z_FLOATING } from '../shell/zindex.js';
  import { runtime, queryRoot } from '../shell/state.svelte.js';

  interface Props {
    text: string;
    trigger?: Snippet;
    children?: Snippet;
  }

  let { text, trigger, children }: Props = $props();

  let wrapper: HTMLElement | undefined = $state();
  let visible = $state(false);
  let coords = $state({ top: 0, left: 0, placement: 'above' as 'above' | 'below' });
  let showTimer: ReturnType<typeof setTimeout> | null = null;

  function position(): void {
    if (!wrapper) return;
    const target = (wrapper.firstElementChild as HTMLElement | null) ?? wrapper;
    const rect = target.getBoundingClientRect();
    const above = rect.top > 48;
    coords = {
      top: above ? rect.top - 8 : rect.bottom + 8,
      left: rect.left + rect.width / 2,
      placement: above ? 'above' : 'below'
    };
  }

  function show(delay: number): void {
    if (showTimer) clearTimeout(showTimer);
    showTimer = setTimeout(() => {
      position();
      visible = true;
    }, delay);
  }

  function hide(): void {
    if (showTimer) clearTimeout(showTimer);
    showTimer = null;
    queueMicrotask(() => {
      if (visible) visible = false;
    });
  }

  function attach(node: HTMLElement) {
    const onEnter = () => show(400);
    const onLeave = () => hide();
    const onFocusIn = (event: FocusEvent) => {
      const target = event.target as HTMLElement | null;
      if (target?.matches?.(':focus-visible')) show(0);
    };
    const onFocusOut = () => hide();
    const onKeydown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') hide();
    };
    node.addEventListener('pointerenter', onEnter);
    node.addEventListener('pointerleave', onLeave);
    node.addEventListener('focusin', onFocusIn);
    node.addEventListener('focusout', onFocusOut);
    node.addEventListener('keydown', onKeydown);
    return {
      destroy() {
        if (showTimer) clearTimeout(showTimer);
        showTimer = null;
        node.removeEventListener('pointerenter', onEnter);
        node.removeEventListener('pointerleave', onLeave);
        node.removeEventListener('focusin', onFocusIn);
        node.removeEventListener('focusout', onFocusOut);
        node.removeEventListener('keydown', onKeydown);
      }
    };
  }

  function portal(node: HTMLElement) {
    const layer: Node =
      wrapper?.closest('[data-dovetail-overlay]') ??
      queryRoot('[data-dovetail-floating-layer]') ??
      (runtime.root instanceof ShadowRoot ? runtime.root : document.body);
    layer.appendChild(node);
    return {
      destroy() {
        node.remove();
      }
    };
  }
</script>

<span bind:this={wrapper} class="dt-tooltip-wrapper" use:attach>
  {@render (trigger ?? children)?.()}
</span>

{#if visible}
  <span
    role="tooltip"
    class="dt-tooltip dt-tooltip--{coords.placement}"
    style:top="{coords.top}px"
    style:left="{coords.left}px"
    style:z-index={Z_FLOATING}
    use:portal
  >
    {text}
  </span>
{/if}

<style>
  .dt-tooltip-wrapper {
    display: contents;
  }
  .dt-tooltip {
    position: fixed;
    transform: translate(-50%, -100%);
    background: var(--surface-3);
    color: var(--text);
    border: 1px solid var(--border-strong);
    border-radius: var(--corner-sm);
    padding: var(--space-1) var(--space-2);
    font-size: var(--type-xs);
    box-shadow: var(--elevation-sm);
    max-width: calc(var(--space-1) * 60);
    pointer-events: none;
  }
  .dt-tooltip--below {
    transform: translate(-50%, 0);
  }
</style>
