<script lang="ts">
  import type { Component, Snippet } from 'svelte';
  import { getContext } from 'svelte';
  import { VIEW_CONTEXT, type ViewContextValue } from './view-context.js';
  import { isSnippet } from './is-snippet.js';
  import Skeleton from './Skeleton.svelte';
  import EmptyState from './EmptyState.svelte';
  import ErrorState from './ErrorState.svelte';
  import UnavailableState from './UnavailableState.svelte';

  interface Failure {
    code: string;
    message: string;
    retry_after_s?: number;
  }

  type ErrorComponent = Component<{ title?: string; body?: string; retry?: () => void }>;
  type ErrorSnippet = Snippet<[Failure | undefined, (() => void) | undefined]>;
  type UnavailableComponent = Component<{ what?: string; retry?: () => void; retry_after_s?: number }>;
  type UnavailableSnippet = Snippet<[Failure | undefined, (() => void) | undefined]>;
  type ReadyComponent = Component<{ data?: unknown }>;
  type ReadySnippet = Snippet<[unknown]>;

  interface Props {
    data?: unknown;
    failure?: Failure;
    retry?: () => void;
    loading?: Component | Snippet<[]>;
    empty?: Component | Snippet<[]>;
    error?: ErrorComponent | ErrorSnippet;
    unavailable?: UnavailableComponent | UnavailableSnippet;
    ready?: ReadyComponent | ReadySnippet;
  }

  let { data, failure, retry, loading: loadingSlot, empty: emptySlot, error: errorSlot, unavailable: unavailableSlot, ready: readySlot }: Props = $props();

  const view = getContext<ViewContextValue>(VIEW_CONTEXT);
</script>

{#if view.status === 'loading'}
  {#if loadingSlot && isSnippet(loadingSlot)}
    {@render (loadingSlot as Snippet<[]>)()}
  {:else if loadingSlot}
    {@const LoadingComp = loadingSlot as Component}
    <LoadingComp />
  {:else}
    <Skeleton />
  {/if}
{:else if view.status === 'empty'}
  {#if emptySlot && isSnippet(emptySlot)}
    {@render (emptySlot as Snippet<[]>)()}
  {:else if emptySlot}
    {@const EmptyComp = emptySlot as Component}
    <EmptyComp />
  {:else}
    <EmptyState />
  {/if}
{:else if view.status === 'error'}
  {#if errorSlot && isSnippet(errorSlot)}
    {@render (errorSlot as ErrorSnippet)(failure, retry)}
  {:else if errorSlot}
    {@const ErrorComp = errorSlot as ErrorComponent}
    <ErrorComp body={failure?.message} {retry} />
  {:else}
    <ErrorState body={failure?.message} {retry} />
  {/if}
{:else if view.status === 'unavailable'}
  {#if unavailableSlot && isSnippet(unavailableSlot)}
    {@render (unavailableSlot as UnavailableSnippet)(failure, retry)}
  {:else if unavailableSlot}
    {@const UnavailableComp = unavailableSlot as UnavailableComponent}
    <UnavailableComp {retry} retry_after_s={failure?.retry_after_s} />
  {:else}
    <UnavailableState {retry} retry_after_s={failure?.retry_after_s} />
  {/if}
{:else if view.status === 'ready'}
  {#if readySlot && isSnippet(readySlot)}
    {@render (readySlot as ReadySnippet)(data)}
  {:else if readySlot}
    {@const ReadyComp = readySlot as ReadyComponent}
    <ReadyComp {data} />
  {/if}
{/if}
