import { runtime, findPanel } from '../shell/state.svelte.js';
import { resolveSchemaRef } from '../validate/jsonschema.js';
import { fixture, emptyFixture } from './fixtures.js';
import type { CallOptions, Result, ServerEventMessage, Transport } from '../types.js';

export interface DevelopmentTransportOptions {
  latency_ms?: number;
  responses?: Record<string, unknown>;
}

export function createDevelopmentTransport(options: DevelopmentTransportOptions = {}): Transport {
  const latency = options.latency_ms ?? 120;
  const responses = options.responses ?? {};

  return {
    async call(module: string, operation: string, input: unknown, callOptions: CallOptions): Promise<Result<unknown, string>> {
      const panel = findPanel(module);
      const declared = panel?.operations.find((o) => o.name === operation);
      const resolvedOutput = resolveSchemaRef(declared?.output_schema);
      const outputSchema = resolvedOutput?.schema;
      const schemaDoc = resolvedOutput?.doc;
      const view = panel?.views.find((v) => v.data_operation === `${module}.${operation}`);
      const forced = view ? runtime.forcedStates[`${module}:${view.name}`] : null;
      await new Promise((resolve) => setTimeout(resolve, latency));
      if (forced === 'loading') {
        return new Promise<Result<unknown, string>>(() => {});
      }
      if (forced === 'error') {
        return { ok: false, error: { code: 'internal', message: 'Simulated error' }, contract_version: callOptions.contract_version };
      }
      if (forced === 'unavailable') {
        return {
          ok: false,
          error: { code: 'unavailable', message: 'Simulated unavailable', retry_after_s: 30 },
          contract_version: callOptions.contract_version
        };
      }
      if (forced === 'empty') {
        if (outputSchema && (outputSchema as any).type === 'array') {
          return { ok: true, data: [], contract_version: callOptions.contract_version };
        }
        return { ok: true, data: emptyFixture(outputSchema, schemaDoc), contract_version: callOptions.contract_version };
      }
      if (Object.prototype.hasOwnProperty.call(responses, operation)) {
        return { ok: true, data: responses[operation], contract_version: callOptions.contract_version };
      }
      if (outputSchema) {
        return { ok: true, data: fixture(outputSchema, schemaDoc), contract_version: callOptions.contract_version };
      }
      return { ok: true, data: null, contract_version: callOptions.contract_version };
    },
    subscribe(_stream: 'events', _handler: (message: ServerEventMessage) => void): () => void {
      return () => {};
    }
  };
}
