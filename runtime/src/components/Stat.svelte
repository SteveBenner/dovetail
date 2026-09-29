<script lang="ts">
  import TrendUpIcon from 'phosphor-svelte/lib/TrendUpIcon';
  import TrendDownIcon from 'phosphor-svelte/lib/TrendDownIcon';
  import MinusIcon from 'phosphor-svelte/lib/MinusIcon';

  interface Props {
    label: string;
    value: string;
    unit?: string;
    trend?: 'up' | 'down' | 'flat';
  }

  let { label, value, unit = '', trend }: Props = $props();
</script>

<div class="dt-stat">
  <span class="dt-stat__label">{label}</span>
  <span class="dt-stat__value">
    {value}
    {#if unit}
      <span class="dt-stat__unit">{unit}</span>
    {/if}
  </span>
  {#if trend}
    <span class="dt-stat__trend">
      {#if trend === 'up'}
        <TrendUpIcon aria-hidden="true" size="14" weight="regular" color="var(--success)" />
        <span class="dt-visually-hidden">Up</span>
      {:else if trend === 'down'}
        <TrendDownIcon aria-hidden="true" size="14" weight="regular" color="var(--danger)" />
        <span class="dt-visually-hidden">Down</span>
      {:else}
        <MinusIcon aria-hidden="true" size="14" weight="regular" color="var(--text-faint)" />
        <span class="dt-visually-hidden">Flat</span>
      {/if}
    </span>
  {/if}
</div>

<style>
  .dt-stat {
    display: flex;
    flex-direction: column;
    gap: var(--space-1);
  }
  .dt-stat__label {
    font-size: var(--type-xs);
    font-weight: var(--weight-medium);
    color: var(--text-dim);
  }
  .dt-stat__value {
    font-size: var(--type-2xl);
    line-height: var(--type-2xl-leading);
    font-weight: var(--weight-semibold);
    color: var(--text);
    font-variant-numeric: tabular-nums;
  }
  .dt-stat__unit {
    margin-left: var(--space-1);
    font-size: var(--type-sm);
    color: var(--text-dim);
  }
  .dt-stat__trend {
    display: inline-flex;
    align-items: center;
  }
  .dt-visually-hidden {
    position: absolute;
    width: 1px;
    height: 1px;
    overflow: hidden;
    clip: rect(0 0 0 0);
    white-space: nowrap;
  }
</style>
