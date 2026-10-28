import { runtime } from '../shell/state.svelte.js';

const MAX_KEYS = 40;
const MAX_VALUE = 200;
const LOCALE = /^[a-z]{2,3}-[A-Z]{2}$/;
const KEY = /^[A-Za-z0-9_.\-]+$/;

type Catalog = Record<string, Record<string, string>>;

const registrations = new Map<string, Catalog>();
const warned = new Set<string>();

function warn(text: string): void {
  if (!runtime.development || warned.has(text)) return;
  warned.add(text);
  console.warn(`Dovetail: ${text}`);
}

function isPlainObject(value: unknown): value is Record<string, unknown> {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) return false;
  const proto = Object.getPrototypeOf(value);
  return proto === Object.prototype || proto === null;
}

export function registerCutoutMessages(module: string | null, cutoutId: string, catalog: unknown): void {
  try {
    if (typeof cutoutId !== 'string' || !KEY.test(cutoutId)) {
      warn(`cutout messages dropped: ${String(cutoutId)} is not a valid cutout id`);
      return;
    }
    if (module !== null ? !cutoutId.startsWith(`${module}.`) : !cutoutId.includes('.')) {
      warn(`cutout messages ${cutoutId} dropped: the cutout id is outside its module`);
      return;
    }
    if (!isPlainObject(catalog) || !Object.values(catalog).every(isPlainObject)) {
      warn(`cutout messages ${cutoutId} dropped: the block is not an object of locale objects`);
      return;
    }
    const source = catalog as Record<string, Record<string, unknown>>;
    if (!Object.prototype.hasOwnProperty.call(source, 'en-US')) {
      warn(`cutout messages ${cutoutId} dropped: en-US is missing`);
      return;
    }
    const stored: Catalog = {};
    const locales = ['en-US', ...Object.keys(source).filter((name) => name !== 'en-US')];
    for (const locale of locales) {
      if (!LOCALE.test(locale)) {
        warn(`cutout messages ${cutoutId}: locale ${locale} dropped`);
        continue;
      }
      const entries = Object.keys(source[locale]);
      if (entries.length > MAX_KEYS) {
        warn(`cutout messages ${cutoutId}: ${locale} has more than ${MAX_KEYS} keys, the rest are dropped`);
      }
      const kept: Record<string, string> = {};
      for (const key of entries.slice(0, MAX_KEYS)) {
        const value = source[locale][key];
        if (!KEY.test(key) || !key.startsWith(`${cutoutId}.`)) {
          warn(`cutout messages ${cutoutId}: key ${key} dropped, it must start with ${cutoutId}.`);
        } else if (typeof value !== 'string' || value.length > MAX_VALUE) {
          warn(`cutout messages ${cutoutId}: key ${key} dropped, the value must be a string of at most ${MAX_VALUE} characters`);
        } else if (locale !== 'en-US' && !Object.prototype.hasOwnProperty.call(stored['en-US'], key)) {
          warn(`cutout messages ${cutoutId}: key ${key} in ${locale} dropped, en-US lacks it`);
        } else {
          kept[key] = value;
        }
      }
      stored[locale] = kept;
    }
    registrations.set(cutoutId, stored);
  } catch (error) {
    warn(`cutout messages ${String(cutoutId)} dropped: ${error instanceof Error ? error.message : String(error)}`);
  }
}

export function cutoutMessagesFor(locale: string): Record<string, string> {
  const merged: Record<string, string> = {};
  for (const catalog of registrations.values()) {
    Object.assign(merged, catalog[locale] ?? {});
  }
  return merged;
}
