<script lang="ts">
  import { View, States, t } from '@dovetail/runtime';
  import client from '$generated/client/{{module}}';

  let status: 'loading' | 'empty' | 'error' | 'unavailable' | 'ready' = $state('loading');
  let data: readonly { label: string }[] = $state([]);

  $effect(() => {
    client.items().then((result) => {
      if (result.ok) {
        data = result.data ?? [];
        status = data.length === 0 ? 'empty' : 'ready';
        return;
      }
      status = result.error.code === 'unavailable' ? 'unavailable' : 'error';
    });
  });
</script>

<div class="dt-panel">
  <h2>{t('{{module}}.title')}</h2>
  <View name="overview" {status}>
    <States>
      {#snippet ready()}
        <ul class="dt-list">
          {#each data as entry}
            <li>{entry.label}</li>
          {/each}
        </ul>
      {/snippet}
    </States>
  </View>
</div>

<style>
  .dt-panel {
    display: flex;
    flex-direction: column;
    gap: var(--space-4);
  }

  h2 {
    font-size: var(--type-lg);
    font-weight: var(--weight-semibold);
    color: var(--text);
    margin: 0;
  }

  .dt-list {
    display: flex;
    flex-direction: column;
    gap: var(--space-2);
    margin: 0;
    padding: 0;
    list-style: none;
  }

  .dt-list li {
    padding: var(--space-2) var(--space-3);
    background: var(--surface-2);
    border-radius: var(--corner-md);
    color: var(--text);
    font-size: var(--type-sm);
  }
</style>
