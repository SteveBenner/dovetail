import { runtime, findPanel } from '../../shell/state.svelte.js';
import { takePrefetched } from '../../shell/prefetch.js';
import { validate } from '../../validate/jsonschema.js';
import type { CallOptions, Result } from '../../types.js';

export async function callOperation<T, E extends string = never>(
  module: string,
  operation: string,
  input: unknown,
  options: CallOptions
): Promise<Result<T, E>> {
  if (!runtime.transport) {
    return {
      ok: false,
      error: { code: 'internal', message: 'Dovetail: no transport configured' }
    } as Result<T, E>;
  }
  const panel = findPanel(module);
  const declared = panel?.operations.find((o) => o.name === operation || o.id === `${module}.${operation}`);
  if (runtime.development && declared) {
    const errors = validate(declared.input_schema, input);
    if (errors.length > 0) {
      runtime.runtimeViolations.push({
        module,
        code: 'D-RUN-004',
        message: `PayloadInvalid input for ${module}.${operation}`
      });
    }
  }
  const held = takePrefetched(module, operation, input);
  const result = (held ? await held : await runtime.transport.call(module, operation, input, options)) as Result<T, E>;
  if (runtime.development && result.ok && result.negotiated) {
    const warnKey = `${module}.${operation}`;
    if (!runtime.negotiatedWarned.has(warnKey)) {
      runtime.negotiatedWarned.add(warnKey);
      console.warn(
        `D-RUN-008 ${warnKey} accepted at contract version ${result.negotiated.served}, requested ${result.negotiated.requested}`
      );
    }
  }
  if (runtime.development && declared && result.ok) {
    const errors = validate(declared.output_schema, result.data);
    if (errors.length > 0) {
      runtime.runtimeViolations.push({
        module,
        code: 'D-RUN-004',
        message: `PayloadInvalid output for ${module}.${operation}`
      });
    }
  }
  return result;
}
