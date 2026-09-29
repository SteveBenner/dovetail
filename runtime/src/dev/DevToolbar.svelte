<script lang="ts">
  import { runtime } from '../shell/state.svelte.js';
  import Button from '../components/Button.svelte';
  import Badge from '../components/Badge.svelte';
  import Select from '../components/Select.svelte';
  import { Z_DEV_TOOLBAR } from '../shell/zindex.js';
  import { tInternal } from '../i18n/t.js';

  interface Finding {
    file: string;
    line: number;
    column?: number;
    rule: string;
    seam?: string;
    severity?: string;
    message: string;
    fix?: unknown;
  }

  interface ShapeReport {
    panel: string;
    shape_version: number;
    findings: Finding[];
    summary: { errors: number; warnings: number };
  }

  interface FindingsPayload {
    contract: Finding[];
    panels: Record<string, ShapeReport>;
  }

  function emptyFindings(): FindingsPayload {
    return { contract: [], panels: {} };
  }

  let expanded = $state(false);
  let findings = $state<FindingsPayload>(emptyFindings());

  function normalizeFindings(payload: unknown): FindingsPayload {
    const raw = (payload ?? {}) as Partial<FindingsPayload>;
    return {
      contract: Array.isArray(raw.contract) ? raw.contract : [],
      panels: raw.panels && typeof raw.panels === 'object' ? raw.panels : {}
    };
  }

  $effect(() => {
    const meta = import.meta as unknown as { hot?: { on: (event: string, cb: (payload: unknown) => void) => void } };
    meta.hot?.on('dovetail:findings', (payload: unknown) => {
      findings = normalizeFindings(payload);
    });
  });

  const panelFindingsCount = $derived(
    Object.values(findings.panels).reduce((sum, report) => sum + (report.findings?.length ?? 0), 0)
  );
  const staticCount = $derived(findings.contract.length + panelFindingsCount);
  const totalCount = $derived(staticCount + runtime.runtimeViolations.length);

  function stateOptions() {
    return [
      { value: 'live', label: tInternal('dovetail.toolbar.live') },
      { value: 'loading', label: 'Loading' },
      { value: 'empty', label: 'Empty' },
      { value: 'error', label: 'Error' },
      { value: 'unavailable', label: 'Unavailable' },
      { value: 'ready', label: 'Ready' }
    ];
  }

  function setViewState(module: string, view: string, value: string): void {
    runtime.forcedStates[`${module}:${view}`] = value === 'live' ? null : (value as any);
  }
</script>

<div class="dt-dev-toolbar" style:z-index={Z_DEV_TOOLBAR}>
  {#if !expanded}
    <Button variant="secondary" size="sm" onclick={() => (expanded = true)}>
      {tInternal('dovetail.toolbar.label')}
      <Badge tone={totalCount > 0 ? 'danger' : 'neutral'}>{totalCount}</Badge>
    </Button>
  {:else}
    <div class="dt-dev-toolbar__panel">
      <div class="dt-dev-toolbar__header">
        <strong>{tInternal('dovetail.toolbar.label')}</strong>
        <Button variant="ghost" size="sm" onclick={() => (expanded = false)}>Close</Button>
      </div>
      <section>
        <h3>{tInternal('dovetail.toolbar.panels')}</h3>
        {#each runtime.registry?.panels ?? [] as panel (panel.module)}
          <div class="dt-dev-toolbar__row">
            <span>{panel.title}</span>
            <Button variant="ghost" size="sm" onclick={() => runtime.crashTriggers[panel.module]?.()}>
              {tInternal('dovetail.toolbar.crash')}
            </Button>
            {#each panel.views as view (view.name)}
              <Select
                bind:value={
                  () => runtime.forcedStates[`${panel.module}:${view.name}`] ?? 'live',
                  (v) => setViewState(panel.module, view.name, v)
                }
                options={stateOptions()}
              />
            {/each}
          </div>
        {/each}
      </section>
      <section>
        <h3>{tInternal('dovetail.toolbar.findings')}</h3>
        {#each findings.contract as finding, i (i)}
          <div class="dt-dev-toolbar__finding">{finding.file}:{finding.line} {finding.rule} {finding.message}</div>
        {/each}
        {#each Object.entries(findings.panels) as [panelName, report] (panelName)}
          {#each report.findings as finding, i (i)}
            <div class="dt-dev-toolbar__finding">{finding.file}:{finding.line} {finding.rule} {finding.message}</div>
          {/each}
        {/each}
      </section>
      <section>
        <h3>{tInternal('dovetail.toolbar.runtime')}</h3>
        {#each runtime.runtimeViolations as violation, i (i)}
          <div class="dt-dev-toolbar__finding">{violation.module} {violation.code} {violation.message}</div>
        {/each}
      </section>
    </div>
  {/if}
</div>

<style>
  .dt-dev-toolbar {
    position: fixed;
    bottom: var(--space-4);
    left: var(--space-4);
  }
  .dt-dev-toolbar__panel {
    width: calc(var(--space-1) * 90);
    max-height: 60%;
    overflow: auto;
    background: var(--surface-2);
    border: 1px solid var(--border);
    border-radius: var(--corner-lg);
    padding: var(--space-4);
    display: flex;
    flex-direction: column;
    gap: var(--space-3);
  }
  .dt-dev-toolbar__header {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .dt-dev-toolbar__row {
    display: flex;
    align-items: center;
    gap: var(--space-2);
    padding-block: var(--space-1);
  }
  .dt-dev-toolbar__finding {
    font-family: var(--family-mono);
    font-size: var(--type-xs);
    color: var(--text-dim);
  }
</style>
