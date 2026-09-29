<script lang="ts">
  import { runtime } from './state.svelte.js';
  import { slotPlacements } from './placement.js';
  import PanelHost from './PanelHost.svelte';

  interface Props {
    name: string;
  }

  let { name }: Props = $props();

  const layoutSlot = $derived(runtime.registry?.layout.slots.find((s) => s.name === name));
  const placements = $derived(
    runtime.registry ? slotPlacements(name, runtime.registry, runtime.route).filter((p) => !runtime.hiddenModules[p.module]) : []
  );
</script>

<div class="dt-slot" data-slot={name}>
  {#each placements as placement (placement.module)}
    {@const panel = runtime.registry?.panels.find((p) => p.module === placement.module)}
    {#if panel}
      <PanelHost {panel} slotName={placement.panelSlot} headingLevel={layoutSlot?.heading_level ?? 2} />
    {/if}
  {/each}
</div>

<style>
  .dt-slot {
    display: contents;
  }
</style>
