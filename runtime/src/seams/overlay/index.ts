import {
  runtime,
  currentInstance,
  findPanel,
  nextOverlayId,
  nextToastId,
  closeOverlayById,
  type OverlayRecord
} from '../../shell/state.svelte.js';
import type { OverlayHandle } from '../../types.js';

function warnUndeclaredOverlay(module: string, name: string): void {
  if (runtime.development) {
    runtime.runtimeViolations.push({ module, code: 'D-RUN-001', message: `OverlayNotDeclared ${name}` });
    throw new Error(`Dovetail: D-RUN-001 OverlayNotDeclared ${name}`);
  }
  console.warn(`Dovetail: overlay ${name} is not declared for ${module}`);
}

export function openOverlayFor<P extends Record<string, unknown>, R = unknown>(
  module: string,
  name: string,
  component: unknown,
  props: P,
  anchor: Element | null = null,
  probe = false
): OverlayHandle<R, P> {
  const instance = currentInstance(module);
  const panel = findPanel(module);
  const declared = panel?.overlays.find((o) => o.name === name);
  if (!declared) {
    warnUndeclaredOverlay(module, name);
    return {
      id: 'noop',
      close() {},
      closed: Promise.resolve(undefined),
      update() {}
    };
  }
  const id = `${module}:${instance.instance}:${nextOverlayId()}`;
  let resolveClosed: (value: R | undefined) => void = () => {};
  const closed = new Promise<R | undefined>((resolve) => {
    resolveClosed = resolve;
  });
  const record: OverlayRecord = {
    id,
    module,
    name,
    kind: declared.kind,
    dismissible: declared.dismissible,
    blocking: declared.blocking,
    component,
    props,
    anchor: anchor ?? (document.activeElement instanceof Element ? document.activeElement : null),
    openerElement: document.activeElement instanceof Element ? document.activeElement : null,
    resolve: resolveClosed as (value: unknown) => void,
    probe
  };
  runtime.overlays.push(record);
  instance.overlayIds.add(id);
  if (record.blocking) {
    runtime.scrollLockCount += 1;
    runtime.focusTrapStack.push(id);
  }
  return {
    id,
    close(result?: R) {
      closeOverlayById(id, result);
    },
    closed,
    update(next: Partial<P>) {
      const current = runtime.overlays.find((o) => o.id === id);
      if (current) Object.assign(current.props, next);
    }
  };
}

export function toastFor(
  message: string,
  options?: { tone?: 'info' | 'success' | 'warning' | 'danger'; duration_ms?: number }
): void {
  const tone = options?.tone ?? 'info';
  const duration = options?.duration_ms ?? (tone === 'danger' ? 8000 : 5000);
  runtime.toasts.push({
    id: nextToastId(),
    message,
    tone,
    duration_ms: duration,
    createdAt: Date.now(),
    paused: false
  });
  while (runtime.toasts.filter((t) => !t.paused).length > 3 && runtime.toasts.length > 3) {
    break;
  }
}

export function dismissTopDismissible(): void {
  for (let i = runtime.overlays.length - 1; i >= 0; i -= 1) {
    if (runtime.overlays[i].dismissible) {
      closeOverlayById(runtime.overlays[i].id, undefined);
      return;
    }
  }
}
