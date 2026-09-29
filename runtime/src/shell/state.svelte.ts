import { getContext, setContext } from 'svelte';
import type { Registry, Result, Theme, Transport, OverlayKind, ViewStatus, HostOptions, LocationAdapter } from '../types.js';
import { createHistoryLocation } from './location.svelte.js';

export const PANEL_CONTEXT = Symbol('dovetail.panel');

export interface PanelInstance {
  module: string;
  instance: number;
  parked: boolean;
  crashed: boolean;
  crashNext: boolean;
  failureTimestamps: number[];
  viewStatuses: Record<string, ViewStatus>;
  overlayIds: Set<string>;
  timers: Set<ReturnType<typeof setTimeout>>;
  intervals: Set<{ cancel: () => void }>;
  frames: Set<{ cancel: () => void }>;
  listeners: Set<{ event: string }>;
  subscriptions: Set<{ cancel: () => void }>;
  shortcutIds: Set<string>;
  props: Record<string, unknown>;
}

export interface OverlayRecord {
  id: string;
  module: string;
  name: string;
  kind: OverlayKind;
  dismissible: boolean;
  blocking: boolean;
  component: any;
  props: Record<string, unknown>;
  anchor: Element | null;
  openerElement: Element | null;
  resolve: (value: unknown) => void;
  probe?: boolean;
}

export interface ToastRecord {
  id: string;
  message: string;
  tone: 'info' | 'success' | 'warning' | 'danger';
  duration_ms: number;
  createdAt: number;
  paused: boolean;
}

export interface RouteState {
  path: string;
  module: string | null;
  pattern: string | null;
  params: Record<string, string>;
  query: Record<string, string>;
}

export interface EventLogEntry {
  event: string;
  receiver: string;
  origin: 'local' | 'server' | 'hook';
}

export interface RuntimeViolation {
  module: string;
  code: string;
  message: string;
}

interface EventSubscription {
  module: string;
  handler: (payload: unknown) => void;
}

function createRuntime() {
  let registry = $state<Registry | null>(null);
  let theme = $state<Theme | null>(null);
  let locale = $state('en-US');
  let transport = $state<Transport | null>(null);
  let onPanelError: ((module: string, error: unknown) => void) | null = null;
  let root: Document | ShadowRoot = document;
  let hostElement: HTMLElement | null = null;
  let hostOptions: HostOptions | null = null;
  let location = $state.raw<LocationAdapter>(createHistoryLocation());
  let versionPolicy: 'strict' | 'tolerant' = 'strict';
  let prefetchEnabled = true;
  const prefetchHeld = new Map<string, { startedAt: number; promise: Promise<Result<unknown, string>> }>();
  const negotiatedWarned = new Set<string>();
  const panels = $state<Record<string, PanelInstance[]>>({});
  const overlays = $state<OverlayRecord[]>([]);
  const toasts = $state<ToastRecord[]>([]);
  let route = $state<RouteState>({ path: '/', module: null, pattern: null, params: {}, query: {} });
  const routeLog = $state<Array<{ module: string; pattern: string; path: string }>>([]);
  const eventLog = $state<EventLogEntry[]>([]);
  const runtimeViolations = $state<RuntimeViolation[]>([]);
  const consoleErrors = $state<string[]>([]);
  const forcedStates = $state<Record<string, ViewStatus | null>>({});
  const hiddenModules = $state<Record<string, boolean>>({});
  let scrollLockCount = $state(0);
  const eventListeners: Record<string, EventSubscription[]> = {};
  const focusTrapStack: string[] = [];
  const lastInstanceFor: Record<string, PanelInstance> = {};
  const crashTriggers: Record<string, () => void> = {};
  const failTriggers: Record<string, (error: unknown) => void> = {};

  return {
    get registry() { return registry; },
    set registry(value) { registry = value; },
    get theme() { return theme; },
    set theme(value) { theme = value; },
    get locale() { return locale; },
    set locale(value) { locale = value; },
    get transport() { return transport; },
    set transport(value) { transport = value; },
    get onPanelError() { return onPanelError; },
    set onPanelError(value) { onPanelError = value; },
    get development() { return registry?.development ?? false; },
    get root() { return root; },
    set root(value) { root = value; },
    get hostElement() { return hostElement; },
    set hostElement(value) { hostElement = value; },
    get hostOptions() { return hostOptions; },
    set hostOptions(value) { hostOptions = value; },
    get versionPolicy() { return versionPolicy; },
    set versionPolicy(value) { versionPolicy = value; },
    get prefetchEnabled() { return prefetchEnabled; },
    set prefetchEnabled(value) { prefetchEnabled = value; },
    prefetchHeld,
    negotiatedWarned,
    get location() { return location; },
    set location(value) { location = value; },
    panels,
    overlays,
    toasts,
    get route() { return route; },
    set route(value) { route = value; },
    routeLog,
    eventLog,
    runtimeViolations,
    consoleErrors,
    forcedStates,
    hiddenModules,
    get scrollLockCount() { return scrollLockCount; },
    set scrollLockCount(value) { scrollLockCount = value; },
    eventListeners,
    focusTrapStack,
    lastInstanceFor,
    crashTriggers,
    failTriggers
  };
}

export const runtime = createRuntime();

export function queryRoot(selector: string): Element | null {
  return runtime.root.querySelector(selector);
}

export function queryRootAll(selector: string): NodeListOf<Element> {
  return runtime.root.querySelectorAll(selector);
}

export function activeElementInRoot(): Element | null {
  return runtime.root.activeElement;
}

export function styleContainer(): Node {
  return runtime.root instanceof ShadowRoot ? runtime.root : document.head;
}

export function hostEvent(name: string, detail: unknown): void {
  const host = runtime.hostElement;
  if (!host) return;
  host.dispatchEvent(new CustomEvent(name, { detail, bubbles: true, composed: true }));
}

export function registerInstance(module: string): PanelInstance {
  if (!runtime.panels[module]) runtime.panels[module] = [];
  const instance = runtime.panels[module].length + 1;
  const record: PanelInstance = $state({
    module,
    instance,
    parked: false,
    crashed: false,
    crashNext: false,
    failureTimestamps: [],
    viewStatuses: {},
    overlayIds: new Set(),
    timers: new Set(),
    intervals: new Set(),
    frames: new Set(),
    listeners: new Set(),
    subscriptions: new Set(),
    shortcutIds: new Set(),
    props: {}
  });
  runtime.panels[module].push(record);
  runtime.lastInstanceFor[module] = record;
  setContext(PANEL_CONTEXT, record);
  return record;
}

export function unregisterInstance(record: PanelInstance): void {
  const list = runtime.panels[record.module];
  if (list) {
    const idx = list.indexOf(record);
    if (idx >= 0) list.splice(idx, 1);
  }
  for (const overlay of [...runtime.overlays]) {
    if (overlay.module === record.module && overlay.id.startsWith(`${record.module}:${record.instance}:`)) {
      closeOverlayById(overlay.id, undefined);
    }
  }
  for (const timer of record.timers) clearTimeout(timer);
  for (const interval of record.intervals) interval.cancel();
  for (const frame of record.frames) frame.cancel();
  for (const sub of record.subscriptions) sub.cancel();
  if (runtime.lastInstanceFor[record.module] === record) {
    delete runtime.lastInstanceFor[record.module];
  }
}

export function currentInstance(module?: string): PanelInstance {
  try {
    const ctx = getContext<PanelInstance>(PANEL_CONTEXT);
    if (ctx) return ctx;
  } catch {
    if (module && runtime.lastInstanceFor[module]) return runtime.lastInstanceFor[module];
    throw new Error('Dovetail: no active panel instance');
  }
  if (module && runtime.lastInstanceFor[module]) return runtime.lastInstanceFor[module];
  throw new Error('Dovetail: no active panel instance');
}

let overlaySeq = 0;
export function nextOverlayId(): string {
  overlaySeq += 1;
  return `ov-${overlaySeq}`;
}

export function closeOverlayById(id: string, result: unknown): void {
  const idx = runtime.overlays.findIndex((o) => o.id === id);
  if (idx < 0) return;
  const [record] = runtime.overlays.splice(idx, 1);
  const trapIdx = runtime.focusTrapStack.indexOf(id);
  if (trapIdx >= 0) runtime.focusTrapStack.splice(trapIdx, 1);
  if (record.blocking && runtime.scrollLockCount > 0) runtime.scrollLockCount -= 1;
  record.resolve(result);
  if (record.openerElement instanceof HTMLElement) {
    record.openerElement.focus();
  }
}

let toastSeq = 0;
export function nextToastId(): string {
  toastSeq += 1;
  return `toast-${toastSeq}`;
}

export function panelRecordsFor(module: string): PanelInstance[] {
  return runtime.panels[module] ?? [];
}

export function findPanel(module: string) {
  return runtime.registry?.panels.find((p) => p.module === module) ?? null;
}
