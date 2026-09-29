import { runtime, findPanel } from '../../shell/state.svelte.js';
import { validate, resolveSchemaRef } from '../../validate/jsonschema.js';
import { backendGetItem, backendSetItem, backendRemoveItem, backendKeysWithPrefix, isBrowserQuotaError } from './backend.js';

const QUOTA_BYTES = 256 * 1024;

class StorageQuotaExceeded extends Error {
  code = 'D-RUN-005';
}

function keyFor(module: string, version: number, key: string): string {
  return `dovetail:${module}:v${version}:${key}`;
}

function moduleUsage(module: string, version: number): number {
  let total = 0;
  const prefix = `dovetail:${module}:v${version}:`;
  for (const key of backendKeysWithPrefix(prefix)) {
    const value = backendGetItem(key) ?? '';
    total += value.length * 2;
  }
  return total;
}

export function storeFor(module: string, key: string) {
  const panel = findPanel(module);
  const version = panel?.contract_version ?? 1;
  const declared = panel?.storage_keys.find((s) => s.name === key);
  const storageKey = keyFor(module, version, key);
  return {
    get(): unknown {
      const raw = backendGetItem(storageKey);
      if (raw == null) return undefined;
      try {
        const envelope = JSON.parse(raw) as { v: unknown; e: number | null };
        if (envelope.e != null && Date.now() > envelope.e) {
          backendRemoveItem(storageKey);
          return undefined;
        }
        return envelope.v;
      } catch {
        return undefined;
      }
    },
    set(value: unknown): void {
      if (runtime.development) {
        const resolved = resolveSchemaRef(declared?.schema);
        if (resolved) {
          const errors = validate(resolved.schema, value, resolved.doc);
          if (errors.length > 0) {
            const error = new Error(`Dovetail: D-RUN-004 PayloadInvalid for storage key ${module}.${key}`);
            runtime.runtimeViolations.push({ module, code: 'D-RUN-004', message: error.message });
            throw error;
          }
        }
      }
      const expiry = declared?.ttl_days ? Date.now() + declared.ttl_days * 86400000 : null;
      const envelope = JSON.stringify({ v: value, e: expiry });
      const before = backendGetItem(storageKey);
      const beforeSize = before ? before.length * 2 : 0;
      const afterSize = envelope.length * 2;
      const usage = moduleUsage(module, version) - beforeSize + afterSize;
      if (usage > QUOTA_BYTES) {
        throw new StorageQuotaExceeded(`Dovetail: D-RUN-005 StorageQuotaExceeded for module ${module}`);
      }
      try {
        backendSetItem(storageKey, envelope);
      } catch (error) {
        if (isBrowserQuotaError(error)) {
          throw new StorageQuotaExceeded(`Dovetail: D-RUN-005 StorageQuotaExceeded for module ${module}`);
        }
        throw error;
      }
    },
    clear(): void {
      backendRemoveItem(storageKey);
    }
  };
}
