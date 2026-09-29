<script lang="ts">
  import { mount, unmount } from 'svelte';
  import { loadLive } from './loader.js';

  interface Props {
    specifier: string;
    rel: string;
    module: string;
    [key: string]: unknown;
  }

  let { specifier, rel, module: mod, ...rest }: Props = $props();

  let container: HTMLDivElement | undefined = $state(undefined);
  let error: unknown = $state(null);
  let Component: unknown = $state(null);

  $effect(() => {
    let cancelled = false;
    loadLive(specifier, rel, mod)
      .then((component) => {
        if (!cancelled) Component = component;
      })
      .catch((caught) => {
        if (cancelled) return;
        console.error(`dovetail live: ${rel}: ${caught instanceof Error ? caught.message : String(caught)}`);
        error = caught instanceof Error ? caught : new Error(String(caught));
      });
    return () => {
      cancelled = true;
    };
  });

  $effect(() => {
    if (!Component || !container) return;
    const instance = mount(Component as never, { target: container, props: rest });
    return () => {
      unmount(instance);
    };
  });

  $effect(() => {
    if (error) throw error;
  });
</script>

<div bind:this={container} class="dt-live-host"></div>

<style>
  .dt-live-host {
    display: contents;
  }
</style>
