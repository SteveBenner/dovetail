import { runtime, currentInstance, findPanel } from '../../shell/state.svelte.js';

export interface ShortcutSpec {
  mod: boolean;
  shift: boolean;
  alt: boolean;
  key: string;
}

export interface ShortcutRegistration {
  id: string;
  module: string;
  instance: number;
  keys: string;
  spec: ShortcutSpec;
  scope: 'panel' | 'view';
  handler: (event: KeyboardEvent) => void;
}

const registrations: ShortcutRegistration[] = [];
let seq = 0;

export function parseKeys(keys: string): ShortcutSpec {
  const parts = keys.split('+').map((p) => p.trim().toLowerCase());
  const spec: ShortcutSpec = { mod: false, shift: false, alt: false, key: '' };
  for (const part of parts) {
    if (part === 'mod') spec.mod = true;
    else if (part === 'shift') spec.shift = true;
    else if (part === 'alt') spec.alt = true;
    else spec.key = part;
  }
  return spec;
}

function isMac(): boolean {
  return typeof navigator !== 'undefined' && /Mac|iPhone|iPad/.test(navigator.platform ?? navigator.userAgent);
}

export function matchesEvent(spec: ShortcutSpec, event: KeyboardEvent): boolean {
  const modPressed = isMac() ? event.metaKey : event.ctrlKey;
  if (spec.mod !== modPressed) return false;
  if (spec.shift !== event.shiftKey) return false;
  if (spec.alt !== event.altKey) return false;
  return event.key.toLowerCase() === spec.key;
}

function isTextField(target: EventTarget | null): boolean {
  if (!(target instanceof HTMLElement)) return false;
  const tag = target.tagName;
  return tag === 'INPUT' || tag === 'TEXTAREA' || target.isContentEditable;
}

export function shortcutFor(module: string, keys: string, handler: (event: KeyboardEvent) => void): () => void {
  const instance = currentInstance(module);
  const panel = findPanel(module);
  if (runtime.development && !panel?.shortcuts.some((s) => s.keys === keys)) {
    runtime.runtimeViolations.push({ module, code: 'D-RUN-003', message: `ShortcutNotDeclared ${keys}` });
  }
  seq += 1;
  const declared = panel?.shortcuts.find((s) => s.keys === keys);
  const registration: ShortcutRegistration = {
    id: `sc-${seq}`,
    module,
    instance: instance.instance,
    keys,
    spec: parseKeys(keys),
    scope: declared?.scope ?? 'panel',
    handler
  };
  registrations.push(registration);
  instance.shortcutIds.add(registration.id);
  return () => {
    const idx = registrations.indexOf(registration);
    if (idx >= 0) registrations.splice(idx, 1);
    instance.shortcutIds.delete(registration.id);
  };
}

export function dispatchKeydown(event: KeyboardEvent): void {
  const blockingOverlay = runtime.overlays.find((o) => o.blocking);
  for (const registration of registrations) {
    if (!matchesEvent(registration.spec, event)) continue;
    if (isTextField(event.target) && !registration.spec.mod) continue;
    if (blockingOverlay && blockingOverlay.module !== registration.module) continue;
    if (registration.scope === 'view' && runtime.route.module !== registration.module) continue;
    registration.handler(event);
    return;
  }
}
