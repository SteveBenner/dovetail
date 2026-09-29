import type { Registry, RegistryPanel, SlotSize } from '../types.js';
import type { RouteState } from './state.svelte.js';

export interface Placement {
  module: string;
  panelSlot: string;
}

export function slotPlacements(layoutSlotName: string, registry: Registry, route: RouteState): Placement[] {
  const layoutSlot = registry.layout.slots.find((s) => s.name === layoutSlotName);
  if (!layoutSlot) return [];
  const firstOfSize: Record<string, string> = {};
  for (const s of registry.layout.slots) {
    if (!(s.size in firstOfSize)) firstOfSize[s.size] = s.name;
  }
  const result: Placement[] = [];
  for (const panel of registry.panels as readonly RegistryPanel[]) {
    for (const panelSlot of panel.slots) {
      const target = registry.layout.slots.some((s) => s.name === panelSlot.name)
        ? panelSlot.name
        : firstOfSize[panelSlot.size as SlotSize];
      if (target !== layoutSlotName) continue;
      if (!isActive(layoutSlot.region, layoutSlot.size, panel.module, route, registry)) continue;
      result.push({ module: panel.module, panelSlot: panelSlot.name });
    }
  }
  return result;
}

export function homeModule(registry: Registry): string | null {
  return registry.layout.home ?? registry.layout.navigation[0]?.module ?? registry.panels[0]?.module ?? null;
}

function isActive(region: string, size: SlotSize, module: string, route: RouteState, registry: Registry): boolean {
  if (region === 'dock') return true;
  if (size === 'main' || size === 'full') return route.module === module;
  if (size === 'aside') return route.module === module;
  if (size === 'tile') return route.module === homeModule(registry);
  return true;
}
