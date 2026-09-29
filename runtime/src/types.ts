import type { Component } from 'svelte';

export type Decimal = string & { readonly __brand: 'Decimal' };
export type IsoDate = string & { readonly __brand: 'IsoDate' };
export type IsoDateTime = string & { readonly __brand: 'IsoDateTime' };
export type Id = string & { readonly __brand: 'Id' };
export type CurrencyCode = string & { readonly __brand: 'CurrencyCode' };
export interface Money { readonly amount: Decimal; readonly currency: CurrencyCode }

export type CommonErrorCode =
  | 'invalid_input'
  | 'contract_violation'
  | 'not_found'
  | 'unavailable'
  | 'not_built'
  | 'contract_version_mismatch'
  | 'rate_limited'
  | 'internal';

export interface DovetailErrorValue<E extends string = never> {
  readonly code: E | CommonErrorCode;
  readonly message: string;
  readonly path?: string;
  readonly retry_after_s?: number;
  readonly versions?: { readonly expected: number; readonly actual: number };
}

export type Result<T, E extends string = never> =
  | { readonly ok: true; readonly data: T; readonly contract_version: number }
  | { readonly ok: false; readonly error: DovetailErrorValue<E>; readonly contract_version?: number };

export interface CallOptions {
  readonly timeout_ms: number;
  readonly idempotent: boolean;
  readonly contract_version: number;
}

export interface ServerEventMessage {
  readonly id: string;
  readonly event: string;
  readonly data: unknown;
  readonly contract_version: number;
}

export interface Transport {
  call(module: string, operation: string, input: unknown, options: CallOptions): Promise<Result<unknown, string>>;
  subscribe(stream: 'events', handler: (message: ServerEventMessage) => void): () => void;
}

export type SlotSize = 'full' | 'main' | 'aside' | 'tile' | 'strip';
export type Region = 'header' | 'nav' | 'main' | 'aside' | 'footer' | 'dock';
export type OverlayKind = 'modal' | 'drawer' | 'popover' | 'menu' | 'toast';
export type ViewStatus = 'loading' | 'empty' | 'error' | 'unavailable' | 'ready' | 'not_built';
export type JsonSchema = Record<string, unknown>;

export interface Theme {
  readonly id: string;
  readonly name: string;
  readonly color_scheme: 'light' | 'dark';
  readonly tokens: Readonly<Record<string, string>>;
}

export interface ModuleTypes {
  overlays: string;
  routes: string;
  storage: Record<string, unknown>;
  emits: Record<string, unknown>;
  consumes: Record<string, unknown>;
  shortcuts: string;
  props: Record<string, unknown>;
}

export interface OverlayHandle<R = unknown, P = Record<string, unknown>> {
  readonly id: string;
  close(result?: R): void;
  readonly closed: Promise<R | undefined>;
  update(props: Partial<P>): void;
}

export interface RegistryPanel {
  readonly module: string;
  readonly title: string;
  readonly contract_version: number;
  readonly component: Component<any>;
  readonly slots: ReadonlyArray<{ name: string; size: SlotSize; min_width: number | null; max_width: number | null }>;
  readonly routes: readonly string[];
  readonly overlays: ReadonlyArray<{ name: string; kind: OverlayKind; dismissible: boolean; blocking: boolean }>;
  readonly shortcuts: ReadonlyArray<{ keys: string; action: string; scope: 'panel' | 'view' }>;
  readonly storage_keys: ReadonlyArray<{ name: string; ttl_days: number | null; schema: JsonSchema }>;
  readonly emits: ReadonlyArray<{ id: string; payload_schema: JsonSchema }>;
  readonly consumes: readonly string[];
  readonly operations: ReadonlyArray<{
    id: string;
    name: string;
    timeout_ms: number;
    idempotent: boolean;
    errors: readonly string[];
    input_schema: JsonSchema;
    output_schema: JsonSchema;
  }>;
  readonly views: ReadonlyArray<{ name: string; data_operation: string; states: readonly string[] }>;
  readonly props: ReadonlyArray<{ name: string; required: boolean; schema: JsonSchema }>;
  readonly messages: Readonly<Record<string, Readonly<Record<string, string>>>>;
}

export interface Registry {
  readonly schema: 'dovetail.registry/v1';
  readonly development: boolean;
  readonly layout: {
    readonly slots: ReadonlyArray<{ name: string; size: SlotSize; region: Region; heading_level: number }>;
    readonly navigation: ReadonlyArray<{ label_key: string; module: string; route: string }>;
    readonly breakpoints: Readonly<Record<'sm' | 'md' | 'lg' | 'xl', number>>;
    readonly home: string | null;
  };
  readonly themes: readonly Theme[];
  readonly panels: readonly RegistryPanel[];
  readonly schemas: Readonly<Record<string, JsonSchema>>;
  readonly messages: Readonly<Record<string, Readonly<Record<string, string>>>>;
}
