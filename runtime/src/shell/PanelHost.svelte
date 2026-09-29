<script lang="ts">
  import { setContext, untrack } from 'svelte';
  import type { RegistryPanel } from '../types.js';
  import { runtime, registerInstance, unregisterInstance, closeOverlayById, type PanelInstance } from './state.svelte.js';
  import { HEADING_CONTEXT } from './heading-context.js';
  import FallbackCard from './FallbackCard.svelte';
  import CrashTrigger from './CrashTrigger.svelte';

  interface Props {
    panel: RegistryPanel;
    slotName: string;
    headingLevel: number;
  }

  let { panel, slotName, headingLevel }: Props = $props();

  const initialHeadingLevel = untrack(() => headingLevel);
  const moduleId = untrack(() => panel.module);

  setContext(HEADING_CONTEXT, initialHeadingLevel);

  const instance: PanelInstance = registerInstance(moduleId);
  let errorSummary = $state('');
  let renderKey = $state(0);
  let crashOnce = $state(false);

  function releaseHandlers(): void {
    for (const overlayId of [...instance.overlayIds]) closeOverlayById(overlayId, undefined);
    for (const timer of instance.timers) clearTimeout(timer);
    instance.timers.clear();
    for (const interval of instance.intervals) interval.cancel();
    instance.intervals.clear();
    for (const frame of instance.frames) frame.cancel();
    instance.frames.clear();
    for (const sub of instance.subscriptions) sub.cancel();
    instance.subscriptions.clear();
  }

  function fail(error: unknown): void {
    const now = Date.now();
    instance.failureTimestamps.push(now);
    instance.failureTimestamps = instance.failureTimestamps.filter((t) => now - t < 5 * 60 * 1000);
    instance.crashed = true;
    errorSummary = error instanceof Error ? error.message : String(error);
    if (instance.failureTimestamps.length >= 3) {
      instance.parked = true;
    }
    releaseHandlers();
    runtime.onPanelError?.(panel.module, error);
    if (runtime.development) {
      console.warn(`D-RUN-006 ${panel.module} crashed: ${errorSummary}`);
    }
  }

  function reload(): void {
    instance.crashed = false;
    crashOnce = false;
    errorSummary = '';
    renderKey += 1;
  }

  function crashNext(): void {
    crashOnce = true;
    renderKey += 1;
  }

  runtime.crashTriggers[moduleId] = crashNext;
  runtime.failTriggers[moduleId] = fail;

  $effect(() => {
    return () => {
      if (runtime.crashTriggers[moduleId] === crashNext) delete runtime.crashTriggers[moduleId];
      if (runtime.failTriggers[moduleId] === fail) delete runtime.failTriggers[moduleId];
      unregisterInstance(instance);
    };
  });
</script>

<div data-dovetail-panel={panel.module} data-slot={slotName} class="dt-panel-slot">
  {#if instance.parked}
    <FallbackCard module={panel.title} summary={errorSummary} parked={true} onreload={() => {}} />
  {:else if instance.crashed}
    <FallbackCard module={panel.title} summary={errorSummary} parked={false} onreload={reload} />
  {:else}
    {#key renderKey}
      <svelte:boundary onerror={(error) => fail(error)}>
        {#if crashOnce}
          <CrashTrigger />
        {:else}
          {@const PanelComponent = panel.component}
          <PanelComponent slot={slotName} />
        {/if}
      </svelte:boundary>
    {/key}
  {/if}
</div>

<style>
  .dt-panel-slot {
    container-type: inline-size;
    contain: layout paint;
    min-width: 0;
  }
</style>
