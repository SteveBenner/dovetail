import { runtime } from '../shell/state.svelte.js';

export interface LeakCounts {
  timers: number;
  intervals: number;
  frames: number;
  listeners: number;
  subscriptions: number;
  shortcuts: number;
  overlays: number;
}

export function leaksFor(module: string): LeakCounts {
  const instances = runtime.panels[module] ?? [];
  const counts: LeakCounts = { timers: 0, intervals: 0, frames: 0, listeners: 0, subscriptions: 0, shortcuts: 0, overlays: 0 };
  for (const instance of instances) {
    counts.timers += instance.timers.size;
    counts.intervals += instance.intervals.size;
    counts.frames += instance.frames.size;
    counts.listeners += instance.listeners.size;
    counts.subscriptions += instance.subscriptions.size;
    counts.shortcuts += instance.shortcutIds.size;
  }
  for (const overlay of runtime.overlays) {
    if (overlay.module === module) counts.overlays += 1;
  }
  return counts;
}
