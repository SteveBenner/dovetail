import { connectEventStream } from './sse.js';
import { runtime } from '../shell/state.svelte.js';
import { validate } from '../validate/jsonschema.js';
import type { CallOptions, CommonErrorCode, Result, ServerEventMessage, Transport } from '../types.js';

export interface BreakerOptions {
  failures: number;
  cooldown_ms: number;
}

export interface HttpTransportOptions {
  baseUrl?: string;
  disabled?: boolean;
  disabledModules?: string[];
  fetch?: typeof globalThis.fetch;
  maxInFlightPerModule?: number;
  ratePerSecond?: number;
  burst?: number;
  breaker?: BreakerOptions;
  streamPath?: string;
}

interface ModuleStats {
  requests: number;
  ok: number;
  errors: Record<string, number>;
  rate_limited_responses: number;
  retries: number;
  in_flight: number;
  queued: number;
  latencies: number[];
}

interface BreakerState {
  state: 'closed' | 'open' | 'half-open';
  consecutiveFailures: number;
  openedAt: number;
  halfOpenInFlight: boolean;
}

interface ModuleState {
  tokens: number;
  lastRefill: number;
  inFlight: number;
  queue: Array<() => void>;
  breaker: BreakerState;
  stats: ModuleStats;
}

function errorForStatus(code: string): boolean {
  return code === 'unavailable' || code === 'internal' || code === 'timeout';
}

function percentile(sorted: number[], p: number): number {
  if (sorted.length === 0) return 0;
  const idx = Math.min(sorted.length - 1, Math.floor((p / 100) * sorted.length));
  return sorted[idx];
}

export function createHttpTransport(options: HttpTransportOptions = {}): Transport {
  const baseUrl = options.baseUrl ?? '';
  const disabled = options.disabled ?? false;
  const disabledModules = new Set(options.disabledModules ?? []);
  const doFetch = options.fetch ?? globalThis.fetch;
  const maxInFlight = options.maxInFlightPerModule ?? 6;
  const ratePerSecond = options.ratePerSecond ?? 10;
  const burst = options.burst ?? 20;
  const breakerOptions = options.breaker ?? { failures: 5, cooldown_ms: 30000 };
  const streamPath = options.streamPath ?? '/api/v1/events';

  const modules = new Map<string, ModuleState>();
  let eventIds: string[] = [];

  function moduleState(module: string): ModuleState {
    let state = modules.get(module);
    if (!state) {
      state = {
        tokens: burst,
        lastRefill: Date.now(),
        inFlight: 0,
        queue: [],
        breaker: { state: 'closed', consecutiveFailures: 0, openedAt: 0, halfOpenInFlight: false },
        stats: { requests: 0, ok: 0, errors: {}, rate_limited_responses: 0, retries: 0, in_flight: 0, queued: 0, latencies: [] }
      };
      modules.set(module, state);
    }
    return state;
  }

  function refill(state: ModuleState): void {
    const now = Date.now();
    const elapsed = (now - state.lastRefill) / 1000;
    state.tokens = Math.min(burst, state.tokens + elapsed * ratePerSecond);
    state.lastRefill = now;
  }

  async function acquireToken(state: ModuleState, deadline: number): Promise<boolean> {
    while (true) {
      refill(state);
      if (state.tokens >= 1) {
        state.tokens -= 1;
        return true;
      }
      const waitMs = ((1 - state.tokens) / ratePerSecond) * 1000;
      const remaining = deadline - Date.now();
      if (waitMs > remaining) return false;
      await new Promise((resolve) => setTimeout(resolve, Math.min(waitMs, remaining)));
      if (Date.now() >= deadline) return false;
    }
  }

  async function acquireSlot(state: ModuleState, deadline: number): Promise<boolean> {
    if (state.inFlight < maxInFlight) {
      state.inFlight += 1;
      return true;
    }
    state.stats.queued += 1;
    return new Promise<boolean>((resolve) => {
      let settled = false;
      const timer = setTimeout(() => {
        if (settled) return;
        settled = true;
        const idx = state.queue.indexOf(onTurn);
        if (idx >= 0) state.queue.splice(idx, 1);
        state.stats.queued -= 1;
        resolve(false);
      }, Math.max(0, deadline - Date.now()));
      function onTurn() {
        if (settled) return;
        settled = true;
        clearTimeout(timer);
        state.stats.queued -= 1;
        state.inFlight += 1;
        resolve(true);
      }
      state.queue.push(onTurn);
    });
  }

  function releaseSlot(state: ModuleState): void {
    state.inFlight -= 1;
    const next = state.queue.shift();
    if (next) next();
  }

  function recordFailure(state: ModuleState, code: string): void {
    if (errorForStatus(code)) {
      if (state.breaker.state === 'half-open') {
        state.breaker.state = 'open';
        state.breaker.openedAt = Date.now();
        state.breaker.halfOpenInFlight = false;
        return;
      }
      state.breaker.consecutiveFailures += 1;
      if (state.breaker.consecutiveFailures >= breakerOptions.failures && state.breaker.state !== 'open') {
        state.breaker.state = 'open';
        state.breaker.openedAt = Date.now();
      }
    } else {
      state.breaker.consecutiveFailures = 0;
      if (state.breaker.state !== 'open') state.breaker.state = 'closed';
      state.breaker.halfOpenInFlight = false;
    }
  }

  function recordSuccess(state: ModuleState): void {
    state.breaker.consecutiveFailures = 0;
    state.breaker.state = 'closed';
    state.breaker.halfOpenInFlight = false;
  }

  function parseRetryAfter(value: string | null): number | undefined {
    if (!value) return undefined;
    const trimmed = value.trim();
    if (/^\d+$/.test(trimmed)) return Number(trimmed);
    const dateMs = Date.parse(trimmed);
    if (!Number.isNaN(dateMs)) return Math.max(0, Math.floor((dateMs - Date.now()) / 1000));
    return undefined;
  }

  async function performOnce(
    module: string,
    operation: string,
    input: unknown,
    callOptions: CallOptions,
    remainingMs: number
  ): Promise<{ result: Result<unknown, string>; statusForBreaker: string; retryAfterS?: number; httpStatus?: number }> {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), remainingMs);
    try {
      const response = await doFetch(`${baseUrl}/api/v1/modules/${module}/${operation}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Dovetail-Contract': `${module}@${callOptions.contract_version}`,
          'X-Request-Id': crypto.randomUUID(),
          'Accept-Language': runtime.locale
        },
        body: JSON.stringify(input),
        signal: controller.signal
      });
      clearTimeout(timer);
      const status = response.status;
      if (status === 429 || status === 503) {
        const retryAfterS = parseRetryAfter(response.headers.get('Retry-After'));
        return {
          result: {
            ok: false,
            error: { code: status === 429 ? 'rate_limited' : 'unavailable', message: `HTTP ${status}`, retry_after_s: retryAfterS }
          },
          statusForBreaker: status === 429 ? 'rate_limited' : 'unavailable',
          retryAfterS,
          httpStatus: status
        };
      }
      const body = (await response.json()) as {
        status: 'ok' | 'error';
        data?: unknown;
        errors?: Array<{ code: string; message: string; path?: string }>;
        contract_version: number;
        negotiated?: { requested?: number; served?: number };
        supported_versions?: unknown;
      };
      if (body.contract_version !== callOptions.contract_version) {
        let firstPath: string | undefined;
        if (
          body.status === 'ok' &&
          (body.negotiated?.requested === callOptions.contract_version || runtime.versionPolicy === 'tolerant')
        ) {
          const schema = runtime.registry?.panels
            .find((p) => p.module === module)
            ?.operations.find((o) => o.name === operation)?.output_schema;
          if (schema) {
            const errors = validate(schema, body.data);
            if (errors.length === 0) {
              return {
                result: {
                  ok: true,
                  data: body.data,
                  contract_version: body.contract_version,
                  negotiated: { requested: callOptions.contract_version, served: body.contract_version }
                },
                statusForBreaker: 'ok',
                httpStatus: status
              };
            }
            firstPath = errors[0].path;
          }
        }
        const supported =
          Array.isArray(body.supported_versions) && body.supported_versions.every((v) => typeof v === 'number')
            ? (body.supported_versions as number[])
            : undefined;
        return {
          result: {
            ok: false,
            error: {
              code: 'contract_version_mismatch',
              message: 'contract version mismatch',
              versions: { expected: callOptions.contract_version, actual: body.contract_version },
              ...(firstPath !== undefined ? { path: firstPath } : {}),
              ...(supported ? { supported_versions: supported } : {})
            }
          },
          statusForBreaker: 'contract_version_mismatch',
          httpStatus: status
        };
      }
      if (body.status === 'ok') {
        return { result: { ok: true, data: body.data, contract_version: body.contract_version }, statusForBreaker: 'ok', httpStatus: status };
      }
      const firstError = body.errors?.[0] ?? { code: 'internal', message: 'unknown error' };
      return {
        result: { ok: false, error: { code: firstError.code as CommonErrorCode, message: firstError.message, path: firstError.path }, contract_version: body.contract_version },
        statusForBreaker: firstError.code,
        httpStatus: status
      };
    } catch (error) {
      clearTimeout(timer);
      const aborted = error instanceof DOMException && error.name === 'AbortError';
      return {
        result: { ok: false, error: { code: aborted ? 'unavailable' : 'internal', message: aborted ? 'timed out' : String(error) } },
        statusForBreaker: aborted ? 'timeout' : 'internal'
      };
    }
  }

  const transport: Transport = {
    async call(module: string, operation: string, input: unknown, callOptions: CallOptions): Promise<Result<unknown, string>> {
      const start = Date.now();
      const deadline = start + callOptions.timeout_ms;
      const state = moduleState(module);
      state.stats.requests += 1;

      if (disabled || disabledModules.has(module)) {
        return { ok: false, error: { code: 'unavailable', message: 'transport disabled' } };
      }

      if (state.breaker.state === 'open') {
        if (Date.now() - state.breaker.openedAt < breakerOptions.cooldown_ms) {
          const retryAfterS = Math.ceil((breakerOptions.cooldown_ms - (Date.now() - state.breaker.openedAt)) / 1000);
          state.stats.errors['unavailable'] = (state.stats.errors['unavailable'] ?? 0) + 1;
          return { ok: false, error: { code: 'unavailable', message: 'circuit open', retry_after_s: retryAfterS } };
        }
        state.breaker.state = 'half-open';
        state.breaker.halfOpenInFlight = true;
      } else if (state.breaker.state === 'half-open') {
        state.stats.errors['unavailable'] = (state.stats.errors['unavailable'] ?? 0) + 1;
        return { ok: false, error: { code: 'unavailable', message: 'circuit open', retry_after_s: 1 } };
      }

      const gotToken = await acquireToken(state, deadline);
      if (!gotToken) {
        state.stats.errors['rate_limited'] = (state.stats.errors['rate_limited'] ?? 0) + 1;
        return { ok: false, error: { code: 'rate_limited', message: 'rate limit exceeded' } };
      }

      const gotSlot = await acquireSlot(state, deadline);
      if (!gotSlot) {
        state.stats.errors['rate_limited'] = (state.stats.errors['rate_limited'] ?? 0) + 1;
        return { ok: false, error: { code: 'rate_limited', message: 'too many in flight' } };
      }

      try {
        let attempt = 0;
        const maxRetries = callOptions.idempotent ? 2 : 0;
        while (true) {
          const remaining = deadline - Date.now();
          if (remaining <= 0) {
            recordFailure(state, 'timeout');
            return { ok: false, error: { code: 'unavailable', message: 'timed out' } };
          }
          const outcome = await performOnce(module, operation, input, callOptions, remaining);
          if (outcome.httpStatus === 429 || outcome.httpStatus === 503) state.stats.rate_limited_responses += 1;
          const retryable =
            attempt < maxRetries &&
            (outcome.statusForBreaker === 'unavailable' ||
              outcome.statusForBreaker === 'internal' ||
              outcome.statusForBreaker === 'timeout' ||
              outcome.statusForBreaker === 'rate_limited');
          if (retryable) {
            attempt += 1;
            state.stats.retries += 1;
            let delay: number;
            if (outcome.retryAfterS != null) {
              delay = outcome.retryAfterS * 1000;
            } else {
              delay = Math.random() * Math.min(2000, 250 * 2 ** attempt);
            }
            if (Date.now() + delay >= deadline) {
              recordFailure(state, outcome.statusForBreaker);
              return outcome.result;
            }
            await new Promise((resolve) => setTimeout(resolve, delay));
            continue;
          }
          if (outcome.statusForBreaker === 'ok') recordSuccess(state);
          else recordFailure(state, outcome.statusForBreaker);
          if (outcome.result.ok) state.stats.ok += 1;
          else state.stats.errors[outcome.statusForBreaker] = (state.stats.errors[outcome.statusForBreaker] ?? 0) + 1;
          state.stats.latencies.push(Date.now() - start);
          if (state.stats.latencies.length > 200) state.stats.latencies.shift();
          return outcome.result;
        }
      } finally {
        releaseSlot(state);
      }
    },
    subscribe(_stream: 'events', handler: (message: ServerEventMessage) => void): () => void {
      return connectEventStream(`${baseUrl}${streamPath}`, eventIds, handler);
    }
  };

  (transport as unknown as { setEventIds(ids: readonly string[]): void }).setEventIds = (ids: readonly string[]) => {
    eventIds = [...ids];
  };

  (transport as unknown as { stats(): Record<string, unknown> }).stats = () => {
    const out: Record<string, unknown> = {};
    for (const [module, state] of modules) {
      const sorted = [...state.stats.latencies].sort((a, b) => a - b);
      out[module] = {
        requests: state.stats.requests,
        ok: state.stats.ok,
        errors: state.stats.errors,
        rate_limited_responses: state.stats.rate_limited_responses,
        retries: state.stats.retries,
        in_flight: state.inFlight,
        queued: state.stats.queued,
        breaker: state.breaker.state,
        p50: percentile(sorted, 50),
        p95: percentile(sorted, 95),
        p99: percentile(sorted, 99)
      };
    }
    return out;
  };

  return transport;
}
