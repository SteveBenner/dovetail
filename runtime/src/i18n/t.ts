import { runtime } from '../shell/state.svelte.js';
import { formatICU } from './icu.js';
import runtimeEnUS from './messages/en-US.json';

const warned = new Set<string>();
const runtimeMessages: Record<string, string> = runtimeEnUS;

function catalogFor(locale: string): Record<string, string> {
  const registry = runtime.registry;
  const merged: Record<string, string> = locale === 'en-US' ? { ...runtimeMessages } : {};
  if (!registry) return merged;
  Object.assign(merged, registry.messages[locale] ?? {});
  for (const panel of registry.panels) {
    Object.assign(merged, panel.messages[locale] ?? {});
  }
  return merged;
}

function lookup(key: string, params: Record<string, string | number>): string {
  const locale = runtime.locale;
  let catalog = catalogFor(locale);
  let pattern = catalog[key];
  if (pattern === undefined && locale !== 'en-US') {
    catalog = catalogFor('en-US');
    pattern = catalog[key];
  }
  if (pattern === undefined) {
    if (runtime.development && !warned.has(key)) {
      warned.add(key);
      console.warn(`Dovetail: missing message key ${key}`);
    }
    return key;
  }
  return formatICU(pattern, params, locale);
}

export function tFor(_module: string, key: string, params?: Record<string, string | number>): string {
  return lookup(key, params ?? {});
}

export function tInternal(key: string, params?: Record<string, string | number>): string {
  return lookup(key, params ?? {});
}
