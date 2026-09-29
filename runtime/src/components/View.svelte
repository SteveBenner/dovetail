<script lang="ts">
  import type { Snippet } from 'svelte';
  import { setContext } from 'svelte';
  import { VIEW_CONTEXT } from './view-context.js';
  import { currentInstance } from '../shell/state.svelte.js';
  import NotBuiltCard from '../shell/NotBuiltCard.svelte';
  import type { ViewStatus } from '../types.js';

  interface Props {
    name: string;
    status: ViewStatus;
    children?: Snippet;
  }

  let { name, status, children }: Props = $props();

  const instance: ReturnType<typeof currentInstance> | null = (() => {
    try {
      return currentInstance();
    } catch {
      return null;
    }
  })();

  $effect(() => {
    if (instance) instance.viewStatuses[name] = status;
  });

  setContext(VIEW_CONTEXT, {
    get name() {
      return name;
    },
    get status() {
      return status;
    }
  });
</script>

<div data-dovetail-view={name} data-status={status} class="dt-view">
  {#if status === 'not_built'}
    <NotBuiltCard view={name} module={instance?.module ?? ''} />
  {:else}
    {@render children?.()}
  {/if}
</div>

<style>
  .dt-view {
    display: block;
    min-width: 0;
  }
</style>
