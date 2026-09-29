<script lang="ts">
  import { runtime, closeOverlayById, queryRoot, activeElementInRoot } from './state.svelte.js';
  import type { OverlayRecord } from './state.svelte.js';
  import { dismissTopDismissible } from '../seams/overlay/index.js';
  import { tInternal } from '../i18n/t.js';
  import IconButton from '../components/IconButton.svelte';
  import XIcon from 'phosphor-svelte/lib/XIcon';
  import InfoIcon from 'phosphor-svelte/lib/InfoIcon';
  import CheckCircleIcon from 'phosphor-svelte/lib/CheckCircleIcon';
  import WarningIcon from 'phosphor-svelte/lib/WarningIcon';
  import WarningOctagonIcon from 'phosphor-svelte/lib/WarningOctagonIcon';

  function focusables(container: HTMLElement): HTMLElement[] {
    return Array.from(
      container.querySelectorAll<HTMLElement>(
        'a[href], button:not([disabled]), textarea, input, select, [tabindex]:not([tabindex="-1"])'
      )
    );
  }

  function trapFocus(node: HTMLElement, active: boolean) {
    function onKeydown(event: KeyboardEvent) {
      if (event.key !== 'Tab') return;
      const items = focusables(node);
      if (items.length === 0) {
        event.preventDefault();
        node.focus();
        return;
      }
      const first = items[0];
      const last = items[items.length - 1];
      if (event.shiftKey && activeElementInRoot() === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && activeElementInRoot() === last) {
        event.preventDefault();
        first.focus();
      }
    }
    if (active) node.addEventListener('keydown', onKeydown);
    const items = focusables(node);
    (items[0] ?? node).focus();
    return {
      destroy() {
        node.removeEventListener('keydown', onKeydown);
      }
    };
  }

  function topLayer(node: HTMLElement, modal: boolean) {
    if (node.isConnected) {
      if (modal) (node as HTMLDialogElement).showModal();
      else node.showPopover();
    }
    return {
      destroy() {
        if (modal) {
          if ((node as HTMLDialogElement).open) (node as HTMLDialogElement).close();
        } else if (node.matches(':popover-open')) {
          node.hidePopover();
        }
      }
    };
  }

  function showWhileMounted(node: HTMLElement) {
    if (node.isConnected) node.showPopover();
    return {
      destroy() {
        if (node.matches(':popover-open')) node.hidePopover();
      }
    };
  }

  function onDialogClose(event: Event, overlay: OverlayRecord): void {
    const dialog = event.currentTarget as HTMLDialogElement;
    if (!runtime.overlays.some((o) => o.id === overlay.id)) return;
    if (overlay.dismissible) {
      closeOverlayById(overlay.id, undefined);
    } else {
      queueMicrotask(() => {
        if (dialog.isConnected && !dialog.open) dialog.showModal();
      });
    }
  }

  let toastRegion: HTMLElement | undefined = $state();
  let lastToastCount = 0;

  $effect(() => {
    const count = runtime.toasts.length;
    if (count > lastToastCount && toastRegion?.matches(':popover-open')) {
      toastRegion.hidePopover();
      toastRegion.showPopover();
    }
    lastToastCount = count;
  });

  const toneIcon = {
    info: InfoIcon,
    success: CheckCircleIcon,
    warning: WarningIcon,
    danger: WarningOctagonIcon
  };
</script>

{#snippet body(overlay: OverlayRecord)}
  {@const OverlayComponent = overlay.component}
  {#if overlay.dismissible && (overlay.kind === 'modal' || overlay.kind === 'drawer')}
    <div class="dt-overlay__close">
      <IconButton label={tInternal('dovetail.close')} icon={XIcon} variant="ghost" onclick={() => closeOverlayById(overlay.id, undefined)} />
    </div>
  {/if}
  <OverlayComponent {...overlay.props} close={(result?: unknown) => closeOverlayById(overlay.id, result)} />
{/snippet}

<div class="dt-overlay-host" data-dovetail-overlay-host>
  {#each runtime.overlays as overlay (overlay.id)}
    {#if overlay.blocking}
      <dialog
        class="dt-overlay dt-overlay--{overlay.kind}"
        data-dovetail-overlay={overlay.id}
        tabindex="-1"
        aria-modal="true"
        role={overlay.kind === 'menu' ? 'menu' : undefined}
        use:topLayer={true}
        use:trapFocus={true}
        oncancel={(event) => event.preventDefault()}
        onclose={(event) => onDialogClose(event, overlay)}
      >
        {@render body(overlay)}
      </dialog>
    {:else}
      <div
        popover="manual"
        class="dt-overlay dt-overlay--{overlay.kind}"
        data-dovetail-overlay={overlay.id}
        tabindex="-1"
        role={overlay.kind === 'menu' ? 'menu' : 'dialog'}
        aria-modal="false"
        use:topLayer={false}
        use:trapFocus={false}
      >
        {@render body(overlay)}
      </div>
    {/if}
  {/each}
</div>

<div class="dt-toast-region" popover="manual" aria-live="polite" bind:this={toastRegion} use:showWhileMounted>
  {#each runtime.toasts as toast (toast.id)}
    {@const ToneIcon = toneIcon[toast.tone]}
    <div class="dt-toast dt-toast--{toast.tone}" role={toast.tone === 'danger' ? 'alert' : 'status'}>
      <ToneIcon aria-hidden="true" size="16" weight="regular" />
      <span class="dt-toast__message">{toast.message}</span>
      <IconButton
        label={tInternal('dovetail.dismiss')}
        icon={XIcon}
        variant="ghost"
        onclick={() => {
          const idx = runtime.toasts.indexOf(toast);
          if (idx >= 0) runtime.toasts.splice(idx, 1);
        }}
      />
    </div>
  {/each}
</div>

<div class="dt-floating-layer" popover="manual" data-dovetail-floating-layer use:showWhileMounted></div>

<svelte:window
  onpointerdown={(event) => {
    const top = runtime.overlays[runtime.overlays.length - 1];
    if (!top) return;
    if ((top.kind === 'popover' || top.kind === 'menu') && top.dismissible) {
      const host = queryRoot('.dt-overlay-host');
      const origin = (event.composedPath()[0] ?? event.target) as Node;
      if (host && !host.contains(origin)) dismissTopDismissible();
    }
  }}
/>

<style>
  .dt-overlay-host {
    position: fixed;
    inset: 0;
    pointer-events: none;
  }
  .dt-overlay {
    margin: 0;
    inset: auto;
    border: none;
    padding: 0;
    max-width: none;
    max-height: none;
    background: transparent;
    color: inherit;
    overflow: visible;
    position: fixed;
    pointer-events: auto;
  }
  dialog.dt-overlay::backdrop {
    background: var(--scrim);
    transition: opacity var(--motion-base) var(--motion-ease);
  }
  .dt-overlay--modal {
    inset: 0;
    margin: auto;
    height: fit-content;
    width: min(calc(var(--space-1) * 140), calc(100% - 2 * var(--space-6)));
    max-height: calc(100% - 2 * var(--space-10));
    overflow: auto;
    background: var(--surface-2);
    color: var(--text);
    border: 1px solid var(--border);
    border-radius: var(--corner-lg);
    box-shadow: var(--elevation-lg);
    padding: var(--space-6);
  }
  .dt-overlay--drawer {
    top: 0;
    right: 0;
    height: 100%;
    width: min(calc(var(--space-1) * 120), 100%);
    background: var(--surface-2);
    color: var(--text);
    border-left: 1px solid var(--border);
    box-shadow: var(--elevation-lg);
    padding: var(--space-6);
    overflow: auto;
  }
  .dt-overlay--popover {
    background: var(--surface-3);
    color: var(--text);
    border: 1px solid var(--border-strong);
    border-radius: var(--corner-md);
    box-shadow: var(--elevation-md);
    padding: var(--space-3);
    max-width: calc(var(--space-1) * 80);
  }
  .dt-overlay--menu {
    background: var(--surface-3);
    color: var(--text);
    border: 1px solid var(--border-strong);
    border-radius: var(--corner-md);
    box-shadow: var(--elevation-md);
    padding: var(--space-1);
  }
  .dt-overlay__close {
    position: absolute;
    top: var(--space-3);
    right: var(--space-3);
  }
  .dt-toast-region {
    inset: auto;
    margin: 0;
    border: none;
    padding: 0;
    background: transparent;
    overflow: visible;
    position: fixed;
    bottom: var(--space-6);
    right: var(--space-6);
    flex-direction: column;
    gap: var(--space-2);
    color: var(--text);
    pointer-events: none;
  }
  .dt-toast-region:popover-open {
    display: flex;
  }
  .dt-toast {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    width: min(calc(var(--space-1) * 90), calc(100% - 2 * var(--space-4)));
    pointer-events: auto;
    background: var(--surface-3);
    color: var(--text);
    border: 1px solid var(--border-strong);
    border-radius: var(--corner-md);
    box-shadow: var(--elevation-md);
    padding: var(--space-3) var(--space-4);
  }
  .dt-toast__message {
    flex: 1;
    font-size: var(--type-sm);
    color: var(--text);
  }
  @media (max-width: 640px) {
    .dt-toast-region {
      right: var(--space-4);
      left: var(--space-4);
    }
  }
  .dt-floating-layer {
    position: fixed;
    inset: 0;
    margin: 0;
    border: none;
    padding: 0;
    background: transparent;
    width: auto;
    height: auto;
    overflow: visible;
    pointer-events: none;
    color: var(--text);
  }
</style>
