<script lang="ts">
  import type { Snippet } from 'svelte';
  import { currentInstance, runtime, findPanel, nextOverlayId, closeOverlayById, activeElementInRoot } from '../shell/state.svelte.js';
  import type { OverlayRecord } from '../shell/state.svelte.js';
  import SnippetHost from './SnippetHost.svelte';

  interface Props {
    name: string;
    open?: boolean;
    anchor?: Element | null;
    children?: Snippet;
  }

  let { name, open = $bindable(false), anchor = null, children }: Props = $props();

  const instance = currentInstance();
  const panel = findPanel(instance.module);
  const declared = panel?.overlays.find((o) => o.name === name);

  let recordId: string | null = null;

  $effect(() => {
    if (open && !recordId && declared) {
      const id = `${instance.module}:${instance.instance}:${nextOverlayId()}`;
      const record: OverlayRecord = {
        id,
        module: instance.module,
        name,
        kind: declared.kind,
        dismissible: declared.dismissible,
        blocking: declared.blocking,
        component: SnippetHost,
        props: { snippet: children },
        anchor: anchor ?? null,
        openerElement: activeElementInRoot(),
        resolve: () => {
          open = false;
        }
      };
      runtime.overlays.push(record);
      instance.overlayIds.add(id);
      if (record.blocking) {
        runtime.scrollLockCount += 1;
        runtime.focusTrapStack.push(id);
      }
      recordId = id;
    } else if (!open && recordId) {
      closeOverlayById(recordId, undefined);
      recordId = null;
    }
  });
</script>
