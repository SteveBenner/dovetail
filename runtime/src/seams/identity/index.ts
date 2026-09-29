import { currentInstance } from '../../shell/state.svelte.js';

export function useIdFor(moduleHint: string | undefined, name: string): string {
  const instance = currentInstance(moduleHint);
  return `dt-${instance.module}-${instance.instance}-${name}`;
}
