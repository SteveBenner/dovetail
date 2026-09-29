import { currentInstance, runtime } from './shell/state.svelte.js';
import { openOverlayFor, toastFor } from './seams/overlay/index.js';
import { navigateFor, linkFor, useRouteFor } from './seams/navigation/index.js';
import { storeFor } from './seams/storage/index.js';
import { emitFor, onFor } from './seams/events/index.js';
import { shortcutFor } from './seams/keyboard/index.js';
import { everyFor, afterFor, frameFor, subscribeFor } from './seams/lifecycle/index.js';
import { useIdFor } from './seams/identity/index.js';
import { tFor } from './i18n/t.js';
import { formatNumberFor, formatMoneyFor, formatDateFor, formatPercentFor } from './i18n/format.js';
import { findPanel } from './shell/state.svelte.js';
import type { Money } from './types.js';

export function createPanelApi<M = unknown>(module: string) {
  return {
    openOverlay(name: string, component: unknown, props: Record<string, unknown>) {
      return openOverlayFor(module, name, component, props);
    },
    toast(message: string, options?: { tone?: 'info' | 'success' | 'warning' | 'danger'; duration_ms?: number }) {
      return toastFor(message, options);
    },
    navigate(route: string, params?: Record<string, string>, options?: { replace?: boolean }) {
      return navigateFor(module, route, params, options);
    },
    link(route: string, params?: Record<string, string>) {
      return linkFor(module, route, params);
    },
    useRoute() {
      return useRouteFor(module);
    },
    store(key: string) {
      return storeFor(module, key);
    },
    emit(event: string, payload: unknown) {
      return emitFor(module, event, payload);
    },
    on(event: string, handler: (payload: unknown) => void) {
      return onFor(module, event, handler);
    },
    shortcut(keys: string, handler: (event: KeyboardEvent) => void) {
      return shortcutFor(module, keys, handler);
    },
    every(ms: number, fn: () => void) {
      return everyFor(module, ms, fn);
    },
    after(ms: number, fn: () => void) {
      return afterFor(module, ms, fn);
    },
    frame(fn: (t: number) => void) {
      return frameFor(module, fn);
    },
    subscribe<T>(source: any, fn: (value: T) => void) {
      return subscribeFor(module, source, fn);
    },
    useId(name: string) {
      return useIdFor(module, name);
    },
    useProps(): Record<string, unknown> {
      return currentInstance(module).props;
    },
    useContractVersion(): number {
      return findPanel(module)?.contract_version ?? 1;
    },
    t(key: string, params?: Record<string, string | number>) {
      return tFor(module, key, params);
    },
    formatNumber(value: number | string, options?: Intl.NumberFormatOptions) {
      return formatNumberFor(runtime.locale, value, options);
    },
    formatMoney(money: Money) {
      return formatMoneyFor(runtime.locale, money);
    },
    formatDate(value: string | Date, style?: 'short' | 'medium' | 'long') {
      return formatDateFor(runtime.locale, value, style);
    },
    formatPercent(value: string | number) {
      return formatPercentFor(runtime.locale, value);
    }
  };
}
