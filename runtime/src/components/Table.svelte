<script lang="ts">
  import type { Component } from 'svelte';
  import CaretUpIcon from 'phosphor-svelte/lib/CaretUpIcon';
  import CaretDownIcon from 'phosphor-svelte/lib/CaretDownIcon';
  import EmptyState from './EmptyState.svelte';
  import { runtime } from '../shell/state.svelte.js';
  import { formatNumberFor, formatMoneyFor, formatPercentFor } from '../i18n/format.js';

  interface Column {
    key: string;
    label: string;
    align?: 'left' | 'right';
    format?: 'number' | 'money' | 'percent';
    sortable?: boolean;
  }

  interface Props {
    columns: Column[];
    rows: readonly Record<string, unknown>[];
    sort?: { key: string; direction: 'asc' | 'desc' } | null;
    empty?: Component;
  }

  let { columns, rows, sort = $bindable(null), empty: EmptyComp }: Props = $props();

  const ROW_HEIGHT = 36;
  const OVERSCAN = 8;
  const MAX_HEIGHT = 480;

  let scrollTop = $state(0);
  let wrapper: HTMLElement | undefined = $state();
  let activeRow = $state(0);

  function cellValue(row: Record<string, unknown>, key: string): unknown {
    return row[key];
  }

  function displayValue(row: Record<string, unknown>, column: Column): string {
    const value = cellValue(row, column.key);
    if (value == null) return '';
    if (column.format === 'number') return formatNumberFor(runtime.locale, value as number | string);
    if (column.format === 'money') return formatMoneyFor(runtime.locale, value as any);
    if (column.format === 'percent') return formatPercentFor(runtime.locale, value as string | number);
    return String(value);
  }

  function compare(a: unknown, b: unknown): number {
    const an = typeof a === 'string' && /^-?\d+(\.\d+)?$/.test(a) ? Number(a) : a;
    const bn = typeof b === 'string' && /^-?\d+(\.\d+)?$/.test(b) ? Number(b) : b;
    if (typeof an === 'number' && typeof bn === 'number') return an - bn;
    return String(a ?? '').localeCompare(String(b ?? ''));
  }

  const sortedRows = $derived.by(() => {
    if (!sort) return rows;
    const copy = [...rows];
    copy.sort((a, b) => {
      const result = compare(cellValue(a, sort!.key), cellValue(b, sort!.key));
      return sort!.direction === 'asc' ? result : -result;
    });
    return copy;
  });

  function toggleSort(column: Column): void {
    if (!column.sortable) return;
    if (sort?.key === column.key) {
      sort = { key: column.key, direction: sort.direction === 'asc' ? 'desc' : 'asc' };
    } else {
      sort = { key: column.key, direction: 'asc' };
    }
  }

  const virtualized = $derived(sortedRows.length > 200);
  const totalHeight = $derived(sortedRows.length * ROW_HEIGHT);
  const startIndex = $derived(virtualized ? Math.max(0, Math.floor(scrollTop / ROW_HEIGHT) - OVERSCAN) : 0);
  const endIndex = $derived(
    virtualized ? Math.min(sortedRows.length, Math.ceil((scrollTop + MAX_HEIGHT) / ROW_HEIGHT) + OVERSCAN) : sortedRows.length
  );
  const visibleRows = $derived(sortedRows.slice(startIndex, endIndex));

  function onScroll(): void {
    if (wrapper) scrollTop = wrapper.scrollTop;
  }

  function moveActive(delta: number): void {
    activeRow = Math.min(sortedRows.length - 1, Math.max(0, activeRow + delta));
  }

  function onRowKeydown(event: KeyboardEvent): void {
    if (event.key === 'ArrowDown') {
      event.preventDefault();
      moveActive(1);
    } else if (event.key === 'ArrowUp') {
      event.preventDefault();
      moveActive(-1);
    } else if (event.key === 'Home') {
      event.preventDefault();
      activeRow = 0;
    } else if (event.key === 'End') {
      event.preventDefault();
      activeRow = sortedRows.length - 1;
    } else if (event.key === 'PageDown') {
      event.preventDefault();
      moveActive(10);
    } else if (event.key === 'PageUp') {
      event.preventDefault();
      moveActive(-10);
    }
  }
</script>

<div
  class="dt-table-wrapper"
  bind:this={wrapper}
  onscroll={onScroll}
  style:max-height={virtualized ? `${MAX_HEIGHT}px` : null}
>
  {#if sortedRows.length === 0}
    {#if EmptyComp}
      <EmptyComp />
    {:else}
      <EmptyState />
    {/if}
  {:else}
    <table class="dt-table">
      <thead>
        <tr>
          {#each columns as column (column.key)}
            <th
              class:dt-table__cell--right={column.align === 'right' || column.format}
              aria-sort={sort?.key === column.key ? (sort.direction === 'asc' ? 'ascending' : 'descending') : 'none'}
            >
              {#if column.sortable}
                <button type="button" class="dt-table__sort" onclick={() => toggleSort(column)}>
                  {column.label}
                  <CaretUpIcon aria-hidden="true" size="12" weight="regular" color={sort?.key === column.key && sort.direction === 'asc' ? 'var(--text)' : 'var(--text-faint)'} />
                  <CaretDownIcon aria-hidden="true" size="12" weight="regular" color={sort?.key === column.key && sort.direction === 'desc' ? 'var(--text)' : 'var(--text-faint)'} />
                </button>
              {:else}
                {column.label}
              {/if}
            </th>
          {/each}
        </tr>
      </thead>
      <tbody>
        {#if virtualized}
          <tr style:height="{startIndex * ROW_HEIGHT}px" aria-hidden="true"></tr>
        {/if}
        {#each visibleRows as row, i (startIndex + i)}
          <tr
            tabindex={startIndex + i === activeRow ? 0 : -1}
            class="dt-table__row"
            onkeydown={onRowKeydown}
            onclick={() => (activeRow = startIndex + i)}
          >
            {#each columns as column (column.key)}
              <td class:dt-table__cell--right={column.align === 'right' || column.format}>{displayValue(row, column)}</td>
            {/each}
          </tr>
        {/each}
        {#if virtualized}
          <tr style:height="{(sortedRows.length - endIndex) * ROW_HEIGHT}px" aria-hidden="true"></tr>
        {/if}
      </tbody>
    </table>
  {/if}
</div>

<style>
  .dt-table-wrapper {
    overflow: auto;
  }
  .dt-table {
    width: 100%;
    border-collapse: separate;
    border-spacing: 0;
  }
  thead th {
    position: sticky;
    top: 0;
    background: var(--surface);
    font-size: var(--type-xs);
    font-weight: var(--weight-medium);
    color: var(--text-dim);
    text-align: left;
    padding: var(--space-2) var(--space-3);
    border-bottom: 1px solid var(--border-strong);
  }
  .dt-table__sort {
    display: inline-flex;
    align-items: center;
    gap: var(--space-1);
    background: none;
    border: none;
    font: inherit;
    color: inherit;
    cursor: pointer;
    padding: 0;
  }
  td {
    padding: var(--space-2) var(--space-3);
    font-size: var(--type-sm);
    color: var(--text);
    border-bottom: 1px solid var(--border);
  }
  tr:last-child td {
    border-bottom: none;
  }
  .dt-table__cell--right {
    text-align: right;
    font-variant-numeric: tabular-nums;
  }
  .dt-table__row:hover {
    background: var(--surface-2);
  }
  .dt-table__row:focus-visible {
    outline: 2px solid var(--accent);
    outline-offset: -2px;
  }
</style>
