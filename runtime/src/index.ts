import { currentInstance } from './shell/state.svelte.js';
import { openOverlayFor, toastFor } from './seams/overlay/index.js';
import { navigateFor, linkFor, useRouteFor, useNavigation as useNavigationImpl } from './seams/navigation/index.js';
import { storeFor } from './seams/storage/index.js';
import { emitFor, onFor } from './seams/events/index.js';
import { shortcutFor } from './seams/keyboard/index.js';
import { everyFor, afterFor, frameFor, subscribeFor } from './seams/lifecycle/index.js';
import { useIdFor } from './seams/identity/index.js';
import { tInternal } from './i18n/t.js';
import { formatNumberFor, formatMoneyFor, formatDateFor, formatPercentFor } from './i18n/format.js';
import { callOperation as callOperationImpl } from './seams/data/index.js';
import { createHttpTransport as createHttpTransportImpl } from './transport/http.js';
import { createDevelopmentTransport as createDevelopmentTransportImpl } from './transport/development.js';
import { runtime, findPanel } from './shell/state.svelte.js';
import type { Money } from './types.js';

function resolveModule(name: string): string {
  try {
    return currentInstance().module;
  } catch {
    throw new Error(`Dovetail: ${name} was called outside a panel`);
  }
}

export function openOverlay(name: string, component: unknown, props: Record<string, unknown>) {
  const module = resolveModule('openOverlay');
  return openOverlayFor(module, name, component, props);
}

export function toast(message: string, options?: { tone?: 'info' | 'success' | 'warning' | 'danger'; duration_ms?: number }) {
  return toastFor(message, options);
}

export function navigate(route: string, params?: Record<string, string>, options?: { replace?: boolean }) {
  const module = resolveModule('navigate');
  return navigateFor(module, route, params, options);
}

export function link(route: string, params?: Record<string, string>) {
  const module = resolveModule('link');
  return linkFor(module, route, params);
}

export function useRoute() {
  const module = resolveModule('useRoute');
  return useRouteFor(module);
}

export function store(key: string) {
  const module = resolveModule('store');
  return storeFor(module, key);
}

export function emit(event: string, payload: unknown) {
  const module = resolveModule('emit');
  return emitFor(module, event, payload);
}

export function on(event: string, handler: (payload: unknown) => void) {
  const module = resolveModule('on');
  return onFor(module, event, handler);
}

export function shortcut(keys: string, handler: (event: KeyboardEvent) => void) {
  const module = resolveModule('shortcut');
  return shortcutFor(module, keys, handler);
}

export function every(ms: number, fn: () => void) {
  const module = resolveModule('every');
  return everyFor(module, ms, fn);
}

export function after(ms: number, fn: () => void) {
  const module = resolveModule('after');
  return afterFor(module, ms, fn);
}

export function frame(fn: (t: number) => void) {
  const module = resolveModule('frame');
  return frameFor(module, fn);
}

export function subscribe<T>(source: any, fn: (value: T) => void) {
  const module = resolveModule('subscribe');
  return subscribeFor(module, source, fn);
}

export function useId(name: string) {
  const module = resolveModule('useId');
  return useIdFor(module, name);
}

export function useProps(): Record<string, unknown> {
  const module = resolveModule('useProps');
  return currentInstance(module).props;
}

export function useContractVersion(): number {
  const module = resolveModule('useContractVersion');
  return findPanel(module)?.contract_version ?? 1;
}

export function t(key: string, params?: Record<string, string | number>): string {
  return tInternal(key, params);
}

export function formatNumber(value: number | string, options?: Intl.NumberFormatOptions): string {
  return formatNumberFor(runtime.locale, value, options);
}

export function formatMoney(money: Money): string {
  return formatMoneyFor(runtime.locale, money);
}

export function formatDate(value: string | Date, style?: 'short' | 'medium' | 'long'): string {
  return formatDateFor(runtime.locale, value, style);
}

export function formatPercent(value: string | number): string {
  return formatPercentFor(runtime.locale, value);
}

export function useNavigation() {
  return useNavigationImpl();
}

export const callOperation = callOperationImpl;
export const createHttpTransport = createHttpTransportImpl;
export const createDevelopmentTransport = createDevelopmentTransportImpl;

export { default as DovetailShell } from './shell/DovetailShell.svelte';
export { default as Slot } from './shell/Slot.svelte';
export { default as Button } from './components/Button.svelte';
export { default as IconButton } from './components/IconButton.svelte';
export { default as Field } from './components/Field.svelte';
export { default as TextInput } from './components/TextInput.svelte';
export { default as NumberInput } from './components/NumberInput.svelte';
export { default as Select } from './components/Select.svelte';
export { default as Checkbox } from './components/Checkbox.svelte';
export { default as Switch } from './components/Switch.svelte';
export { default as Tabs } from './components/Tabs.svelte';
export { default as Table } from './components/Table.svelte';
export { default as Card } from './components/Card.svelte';
export { default as Badge } from './components/Badge.svelte';
export { default as Stat } from './components/Stat.svelte';
export { default as Skeleton } from './components/Skeleton.svelte';
export { default as EmptyState } from './components/EmptyState.svelte';
export { default as ErrorState } from './components/ErrorState.svelte';
export { default as UnavailableState } from './components/UnavailableState.svelte';
export { default as Tooltip } from './components/Tooltip.svelte';
export { default as View } from './components/View.svelte';
export { default as States } from './components/States.svelte';
export { default as Overlay } from './components/Overlay.svelte';

export type {
  Decimal,
  IsoDate,
  IsoDateTime,
  Id,
  CurrencyCode,
  Money,
  Result,
  CommonErrorCode,
  DovetailErrorValue,
  OverlayHandle,
  Transport,
  CallOptions,
  Registry,
  RegistryPanel,
  Theme,
  ModuleTypes,
  SlotSize,
  OverlayKind
} from './types.js';
