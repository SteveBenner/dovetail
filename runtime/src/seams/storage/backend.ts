const memoryStore = new Map<string, string>();
let useMemory = false;
let probed = false;

function isBrowserQuotaError(error: unknown): boolean {
  if (!(error instanceof DOMException)) return false;
  return error.name === 'QuotaExceededError' || error.name === 'NS_ERROR_DOM_QUOTA_REACHED';
}

function probe(): void {
  if (probed) return;
  probed = true;
  try {
    const testKey = '__dovetail_probe__';
    localStorage.setItem(testKey, '1');
    localStorage.removeItem(testKey);
  } catch {
    useMemory = true;
  }
}

export function backendGetItem(key: string): string | null {
  probe();
  if (useMemory) return memoryStore.get(key) ?? null;
  try {
    return localStorage.getItem(key);
  } catch {
    useMemory = true;
    return memoryStore.get(key) ?? null;
  }
}

export function backendSetItem(key: string, value: string): void {
  probe();
  if (useMemory) {
    memoryStore.set(key, value);
    return;
  }
  try {
    localStorage.setItem(key, value);
  } catch (error) {
    if (isBrowserQuotaError(error)) throw error;
    useMemory = true;
    memoryStore.set(key, value);
  }
}

export function backendRemoveItem(key: string): void {
  probe();
  if (useMemory) {
    memoryStore.delete(key);
    return;
  }
  try {
    localStorage.removeItem(key);
  } catch {
    useMemory = true;
    memoryStore.delete(key);
  }
}

export function backendKeysWithPrefix(prefix: string): string[] {
  probe();
  if (useMemory) {
    return [...memoryStore.keys()].filter((k) => k.startsWith(prefix));
  }
  try {
    const keys: string[] = [];
    for (let i = 0; i < localStorage.length; i += 1) {
      const k = localStorage.key(i);
      if (k && k.startsWith(prefix)) keys.push(k);
    }
    return keys;
  } catch {
    useMemory = true;
    return [...memoryStore.keys()].filter((k) => k.startsWith(prefix));
  }
}

export { isBrowserQuotaError };
