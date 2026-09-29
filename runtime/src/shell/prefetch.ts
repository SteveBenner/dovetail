import { runtime, type RouteState } from './state.svelte.js';
import { slotPlacements } from './placement.js';
import type { Registry, Result } from '../types.js';

export const PREFETCH_HOLD_MS = 5000;

export function placedModules(registry: Registry, route: RouteState): string[] {
  const modules: string[] = [];
  for (const slot of registry.layout.slots) {
    for (const placement of slotPlacements(slot.name, registry, route)) {
      if (!modules.includes(placement.module)) modules.push(placement.module);
    }
  }
  return modules;
}

function fresh(startedAt: number): boolean {
  return Date.now() - startedAt < PREFETCH_HOLD_MS;
}

export function startPrefetch(route: RouteState): void {
  const registry = runtime.registry;
  const transport = runtime.transport;
  if (!registry || !transport) return;
  const now = Date.now();
  for (const [key, held] of [...runtime.prefetchHeld]) {
    if (now - held.startedAt >= PREFETCH_HOLD_MS) runtime.prefetchHeld.delete(key);
  }
  for (const module of placedModules(registry, route)) {
    const panel = registry.panels.find((p) => p.module === module);
    if (!panel) continue;
    for (const name of panel.prefetch) {
      const key = `${module}.${name}`;
      const existing = runtime.prefetchHeld.get(key);
      if (existing && fresh(existing.startedAt)) continue;
      const op = panel.operations.find((o) => o.name === name);
      if (!op) continue;
      let promise: Promise<Result<unknown, string>>;
      try {
        promise = transport
          .call(module, name, {}, { timeout_ms: op.timeout_ms, idempotent: op.idempotent, contract_version: panel.contract_version })
          .catch((error): Result<unknown, string> => ({ ok: false, error: { code: 'internal', message: String(error) } }));
      } catch (error) {
        promise = Promise.resolve({ ok: false, error: { code: 'internal', message: String(error) } } as Result<unknown, string>);
      }
      runtime.prefetchHeld.set(key, { startedAt: Date.now(), promise });
    }
  }
}

export function takePrefetched(module: string, operation: string, input: unknown): Promise<Result<unknown, string>> | null {
  if (!runtime.prefetchEnabled) return null;
  if (input === null || typeof input !== 'object' || Object.keys(input as object).length > 0) return null;
  const key = `${module}.${operation}`;
  const held = runtime.prefetchHeld.get(key);
  if (!held || !fresh(held.startedAt)) return null;
  runtime.prefetchHeld.delete(key);
  return held.promise;
}
