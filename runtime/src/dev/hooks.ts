import { tick } from 'svelte';
import { runtime, findPanel, closeOverlayById, nextOverlayId } from '../shell/state.svelte.js';
import { dispatchRouteChange } from '../seams/navigation/index.js';
import { emitFor } from '../seams/events/index.js';
import { fixture } from '../transport/fixtures.js';
import { resolveSchemaRef } from '../validate/jsonschema.js';
import { leaksFor } from './leaks.js';
import { homeModule } from '../shell/placement.js';
import Probe from './Probe.svelte';
import type { OverlayRecord } from '../shell/state.svelte.js';
import type { ViewStatus } from '../types.js';

declare global {
  interface Window {
    __dovetail?: unknown;
  }
}

export function installDevHooks(): void {
  const hooks = {
    version: '0.1.0',
    ready(): boolean {
      return runtime.registry != null;
    },
    panels() {
      return (runtime.registry?.panels ?? []).map((panel) => {
        const instances = runtime.panels[panel.module] ?? [];
        const mounted = instances.length > 0;
        const crashed = instances.some((i) => i.crashed);
        const parked = instances.some((i) => i.parked);
        const failures = instances.reduce((sum, i) => sum + i.failureTimestamps.length, 0);
        return { module: panel.module, title: panel.title, slots: panel.slots.map((s) => s.name), mounted, crashed, failures, parked };
      });
    },
    overlays: {
      async open(module: string, name: string): Promise<string> {
        const panel = findPanel(module);
        const declared = panel?.overlays.find((o) => o.name === name);
        if (!declared) throw new Error(`Dovetail: overlay ${name} is not declared for ${module}`);
        const id = `${module}:probe:${nextOverlayId()}`;
        let resolveClosed: (value: unknown) => void = () => {};
        const record: OverlayRecord = {
          id,
          module,
          name,
          kind: declared.kind,
          dismissible: declared.dismissible,
          blocking: declared.blocking,
          component: Probe,
          props: { name },
          anchor: null,
          openerElement: document.activeElement instanceof Element ? document.activeElement : null,
          resolve: (value: unknown) => resolveClosed(value),
          probe: true
        };
        runtime.overlays.push(record);
        if (record.blocking) {
          runtime.scrollLockCount += 1;
          runtime.focusTrapStack.push(id);
        }
        await tick();
        return id;
      },
      stack() {
        return runtime.overlays.map((o) => ({ id: o.id, module: o.module, name: o.name, kind: o.kind, blocking: o.blocking, dismissible: o.dismissible }));
      },
      close(id: string): void {
        closeOverlayById(id, undefined);
      }
    },
    scrollLocked(): boolean {
      return runtime.scrollLockCount > 0;
    },
    focusTrapTop(): string | null {
      return runtime.focusTrapStack[runtime.focusTrapStack.length - 1] ?? null;
    },
    focusInside(id: string): boolean {
      const active = document.activeElement;
      return active != null && active.closest(`[data-dovetail-overlay="${CSS.escape(id)}"]`) != null;
    },
    homeModule(): string | null {
      return runtime.registry ? homeModule(runtime.registry) : null;
    },
    async navigate(path: string): Promise<void> {
      history.pushState({}, '', path);
      dispatchRouteChange();
      await tick();
    },
    currentRoute() {
      return { path: runtime.route.path, module: runtime.route.module, pattern: runtime.route.pattern, params: runtime.route.params };
    },
    routeLog() {
      return [...runtime.routeLog];
    },
    clearRouteLog(): void {
      runtime.routeLog.length = 0;
    },
    emit(eventId: string, payload?: unknown): void {
      const [module, name] = [eventId.slice(0, eventId.indexOf('.')), eventId];
      const panel = findPanel(module);
      const declared = panel?.emits.find((e) => e.id === name);
      let actualPayload = payload;
      if (actualPayload === undefined && declared) {
        const resolved = resolveSchemaRef(declared.payload_schema);
        actualPayload = resolved ? fixture(resolved.schema, resolved.doc) : undefined;
      }
      emitFor(module, name, actualPayload, 'hook');
    },
    eventLog() {
      return [...runtime.eventLog];
    },
    clearEventLog(): void {
      runtime.eventLog.length = 0;
    },
    fixture(schemaRef: unknown): unknown {
      const resolved = resolveSchemaRef(schemaRef as any);
      return resolved ? fixture(resolved.schema, resolved.doc) : null;
    },
    forceState(module: string, view: string, state: ViewStatus | null): void {
      runtime.forcedStates[`${module}:${view}`] = state;
    },
    viewStates(module: string): Record<string, string> {
      const instances = runtime.panels[module] ?? [];
      const out: Record<string, string> = {};
      for (const instance of instances) {
        Object.assign(out, instance.viewStatuses);
      }
      return out;
    },
    async unmount(module: string): Promise<void> {
      runtime.hiddenModules[module] = true;
      await tick();
    },
    async mount(module: string): Promise<void> {
      delete runtime.hiddenModules[module];
      await tick();
    },
    leaks(module: string) {
      return leaksFor(module);
    },
    async crash(module: string): Promise<void> {
      if (!runtime.crashTriggers[module]) {
        delete runtime.hiddenModules[module];
        await tick();
      }
      const trigger = runtime.crashTriggers[module];
      if (!trigger) {
        throw new Error(`Dovetail: cannot crash ${module}: the panel is not mounted (it is not placed under the current route or slot)`);
      }
      trigger();
      await tick();
    },
    slotRects() {
      const out: Array<{ module: string; slot: string; rect: { x: number; y: number; width: number; height: number }; scroll: { width: number; height: number } }> = [];
      document.querySelectorAll('[data-dovetail-panel]').forEach((el) => {
        const module = el.getAttribute('data-dovetail-panel');
        const slot = el.getAttribute('data-slot');
        if (!module || !slot || !(el instanceof HTMLElement)) return;
        const rect = el.getBoundingClientRect();
        out.push({
          module,
          slot,
          rect: { x: rect.x, y: rect.y, width: rect.width, height: rect.height },
          scroll: { width: el.scrollWidth, height: el.scrollHeight }
        });
      });
      return out;
    },
    setSlotWidth(slot: string, px: number | null): void {
      const el = document.querySelector(`[data-slot="${slot}"]`);
      if (el instanceof HTMLElement) {
        el.style.width = px == null ? '' : `${px}px`;
        el.style.flex = px == null ? '' : '0 0 auto';
      }
    },
    runtimeViolations() {
      return [...runtime.runtimeViolations];
    },
    transportStats(): Record<string, unknown> {
      const transport = runtime.transport as unknown as { stats?: () => Record<string, unknown> };
      return transport?.stats ? transport.stats() : {};
    },
    consoleErrors(): string[] {
      return [...runtime.consoleErrors];
    }
  };

  originalConsoleError = console.error;
  console.error = (...args: unknown[]) => {
    runtime.consoleErrors.push(args.map((a) => String(a)).join(' '));
    originalConsoleError?.(...args);
  };

  window.__dovetail = hooks;
}

let originalConsoleError: typeof console.error | null = null;

export function removeDevHooks(): void {
  delete window.__dovetail;
  if (originalConsoleError) {
    console.error = originalConsoleError;
    originalConsoleError = null;
  }
}
