<script lang="ts">
  import { runtime, closeOverlayById } from './state.svelte.js';
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
      if (event.shiftKey && document.activeElement === first) {
        event.preventDefault();
        last.focus();
      } else if (!event.shiftKey && document.activeElement === last) {
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

  const toneIcon = {
    info: InfoIcon,
    success: CheckCircleIcon,
    warning: WarningIcon,
    danger: WarningOctagonIcon
  };
</script>

<div class="dt-overlay-host" data-dovetail-overlay-host>
  {#each runtime.overlays as overlay (overlay.id)}
    {@const OverlayComponent = overlay.component}
    {#if overlay.blocking}
      <div class="dt-scrim"></div>
    {/if}
    <div
      class="dt-overlay dt-overlay--{overlay.kind}"
      data-dovetail-overlay={overlay.id}
      tabindex="-1"
      role={overlay.kind === 'menu' ? 'menu' : 'dialog'}
      aria-modal={overlay.blocking}
      use:trapFocus={overlay.blocking}
      onkeydown={(event) => {
        if (event.key === 'Escape' && overlay.dismissible) closeOverlayById(overlay.id, undefined);
      }}
    >
      {#if overlay.dismissible && (overlay.kind === 'modal' || overlay.kind === 'drawer')}
        <div class="dt-overlay__close">
          <IconButton label={tInternal('dovetail.close')} icon={XIcon} variant="ghost" onclick={() => closeOverlayById(overlay.id, undefined)} />
        </div>
      {/if}
      <OverlayComponent {...overlay.props} close={(result?: unknown) => closeOverlayById(overlay.id, result)} />
    </div>
  {/each}
</div>

<div class="dt-toast-region" aria-live="polite">
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

<div class="dt-floating-layer" data-dovetail-floating-layer></div>

<svelte:window
  onpointerdown={(event) => {
    const top = runtime.overlays[runtime.overlays.length - 1];
    if (!top) return;
    if ((top.kind === 'popover' || top.kind === 'menu') && top.dismissible) {
      const host = document.querySelector('.dt-overlay-host');
      if (host && !host.contains(event.target as Node)) dismissTopDismissible();
    }
  }}
/>

<style>
  .dt-overlay-host {
    position: fixed;
    inset: 0;
    pointer-events: none;
  }
  .dt-scrim {
    position: fixed;
    inset: 0;
    background: var(--scrim);
    pointer-events: auto;
    transition: opacity var(--motion-base) var(--motion-ease);
  }
  .dt-overlay {
    position: fixed;
    pointer-events: auto;
  }
  .dt-overlay--modal {
    top: 50%;
    left: 50%;
    transform: translate(-50%, -50%);
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
    position: fixed;
    bottom: var(--space-6);
    right: var(--space-6);
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    z-index: 1100;
    color: var(--text);
  }
  .dt-toast {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    width: min(calc(var(--space-1) * 90), calc(100% - 2 * var(--space-4)));
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
    pointer-events: none;
    color: var(--text);
  }
</style>
