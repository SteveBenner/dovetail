import { runtime, currentInstance, findPanel } from '../../shell/state.svelte.js';
import { validate, resolveSchemaRef } from '../../validate/jsonschema.js';

function warnUndeclared(module: string, code: string, message: string): void {
  if (runtime.development) {
    runtime.runtimeViolations.push({ module, code, message });
    throw new Error(`Dovetail: ${code} ${message}`);
  }
  console.warn(`Dovetail: ${message}`);
}

export function emitFor(module: string, event: string, payload: unknown, origin: 'local' | 'server' | 'hook' = 'local'): void {
  const panel = findPanel(module);
  const declaredEvent = panel?.emits.find((e) => e.id === event);
  if (!declaredEvent && origin !== 'hook') {
    warnUndeclared(module, 'D-RUN-003', `EventNotDeclared ${event}`);
    return;
  }
  if (runtime.development && declaredEvent) {
    const resolved = resolveSchemaRef(declaredEvent.payload_schema);
    if (resolved) {
      const errors = validate(resolved.schema, payload, resolved.doc);
      if (errors.length > 0) {
        runtime.runtimeViolations.push({ module, code: 'D-RUN-004', message: `PayloadInvalid for event ${event}` });
      }
    }
  }
  const subscribers = runtime.eventListeners[event] ?? [];
  for (const subscriber of [...subscribers]) {
    const consumerPanel = findPanel(subscriber.module);
    if (!consumerPanel?.consumes.includes(event)) continue;
    runtime.eventLog.push({ event, receiver: subscriber.module, origin });
    try {
      const start = performance.now();
      subscriber.handler(payload);
      const elapsed = performance.now() - start;
      if (runtime.development && elapsed > 50) {
        console.warn(`Dovetail: handler for ${event} in ${subscriber.module} took ${Math.round(elapsed)}ms`);
      }
    } catch (error) {
      runtime.failTriggers[subscriber.module]?.(error);
    }
  }
}

export function onFor(module: string, event: string, handler: (payload: unknown) => void): () => void {
  const instance = currentInstance(module);
  const panel = findPanel(module);
  if (!panel?.consumes.includes(event) && runtime.development) {
    runtime.runtimeViolations.push({ module, code: 'D-RUN-003', message: `EventNotDeclared ${event}` });
  }
  if (!runtime.eventListeners[event]) runtime.eventListeners[event] = [];
  const entry = { module, handler };
  runtime.eventListeners[event].push(entry);
  instance.listeners.add({ event });
  const cancelHandle = {
    cancel() {
      const list = runtime.eventListeners[event];
      if (!list) return;
      const idx = list.indexOf(entry);
      if (idx >= 0) list.splice(idx, 1);
    }
  };
  instance.subscriptions.add(cancelHandle);
  return () => cancelHandle.cancel();
}
