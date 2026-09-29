import { currentInstance, queryRoot } from '../../shell/state.svelte.js';

export function everyFor(module: string, ms: number, fn: () => void): () => void {
  const instance = currentInstance(module);
  let cancelled = false;
  let timer: ReturnType<typeof setTimeout> | null = null;
  const tick = () => {
    if (cancelled) return;
    if (typeof document === 'undefined' || !document.hidden) {
      try {
        fn();
      } catch (error) {
        reportPanelError(module, error);
      }
    }
    schedule();
  };
  const schedule = () => {
    timer = setTimeout(tick, ms);
  };
  schedule();
  const handle = {
    cancel() {
      cancelled = true;
      if (timer) clearTimeout(timer);
    }
  };
  instance.intervals.add(handle);
  return () => {
    handle.cancel();
    instance.intervals.delete(handle);
  };
}

export function afterFor(module: string, ms: number, fn: () => void): () => void {
  const instance = currentInstance(module);
  const timer = setTimeout(() => {
    instance.timers.delete(timer);
    try {
      fn();
    } catch (error) {
      reportPanelError(module, error);
    }
  }, ms);
  instance.timers.add(timer);
  return () => {
    clearTimeout(timer);
    instance.timers.delete(timer);
  };
}

export function frameFor(module: string, fn: (t: number) => void): () => void {
  const instance = currentInstance(module);
  let cancelled = false;
  let raf = 0;
  const loop = (t: number) => {
    if (cancelled) return;
    try {
      fn(t);
    } catch (error) {
      reportPanelError(module, error);
    }
    raf = requestAnimationFrame(loop);
  };
  raf = requestAnimationFrame(loop);
  const handle = {
    cancel() {
      cancelled = true;
      cancelAnimationFrame(raf);
    }
  };
  instance.frames.add(handle);
  return () => {
    handle.cancel();
    instance.frames.delete(handle);
  };
}

export function subscribeFor<T>(
  module: string,
  source: { subscribe(run: (value: T) => void): (() => void) | { unsubscribe(): void } } | AsyncIterable<T>,
  fn: (value: T) => void
): () => void {
  const instance = currentInstance(module);
  let cancelled = false;
  let unsub: () => void = () => {};
  if (source && typeof (source as any).subscribe === 'function') {
    const result = (source as any).subscribe((value: T) => {
      if (!cancelled) fn(value);
    });
    unsub = typeof result === 'function' ? result : () => result.unsubscribe();
  } else if (source && typeof (source as any)[Symbol.asyncIterator] === 'function') {
    (async () => {
      for await (const value of source as AsyncIterable<T>) {
        if (cancelled) break;
        fn(value);
      }
    })();
    unsub = () => {
      cancelled = true;
    };
  }
  const handle = {
    cancel() {
      cancelled = true;
      unsub();
    }
  };
  instance.subscriptions.add(handle);
  return () => {
    handle.cancel();
    instance.subscriptions.delete(handle);
  };
}

export function reportPanelError(module: string, error: unknown): void {
  const target = queryRoot(`[data-dovetail-panel="${module}"]`);
  const event = new CustomEvent('dovetail:panelerror', { detail: { module, error }, bubbles: true });
  if (target) target.dispatchEvent(event);
  else console.error(error);
}
