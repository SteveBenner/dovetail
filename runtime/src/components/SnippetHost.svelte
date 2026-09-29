<script lang="ts">
  import type { Snippet } from 'svelte';

  interface Props {
    snippet: Snippet;
  }

  let { snippet }: Props = $props();
</script>

{@render snippet()}
