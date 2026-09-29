import { runtime } from '../shell/state.svelte.js';
import type { JsonSchema } from '../types.js';

export interface ValidationError {
  path: string;
  message: string;
}

export function resolveRef(ref: string, currentDoc: JsonSchema): { schema: JsonSchema; doc: JsonSchema; name: string } {
  const hashIndex = ref.indexOf('#');
  const docPart = hashIndex >= 0 ? ref.slice(0, hashIndex) : '';
  const pointer = hashIndex >= 0 ? ref.slice(hashIndex + 1) : '';
  let doc = currentDoc;
  if (docPart) {
    const module = docPart.replace(/\.schema\.json$/, '');
    const found = runtime.registry?.schemas[module];
    if (found) doc = found;
  }
  const parts = pointer.split('/').filter((p) => p.length > 0);
  let cursor: unknown = doc;
  let name = '';
  for (const part of parts) {
    if (cursor && typeof cursor === 'object') {
      cursor = (cursor as Record<string, unknown>)[part];
      name = part;
    }
  }
  return { schema: (cursor as JsonSchema) ?? {}, doc, name };
}

function formatOk(format: string, value: string): boolean {
  if (format === 'date') return /^\d{4}-\d{2}-\d{2}$/.test(value);
  if (format === 'date-time') return !Number.isNaN(Date.parse(value));
  if (format === 'uri') {
    try {
      new URL(value);
      return true;
    } catch {
      return false;
    }
  }
  if (format === 'email') return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value);
  return true;
}

function validateNode(schema: JsonSchema, value: unknown, path: string, doc: JsonSchema, out: ValidationError[]): void {
  if (schema.$ref) {
    const resolved = resolveRef(schema.$ref as string, doc);
    validateNode(resolved.schema, value, path, resolved.doc, out);
    return;
  }
  if (schema.anyOf) {
    const variants = schema.anyOf as JsonSchema[];
    const matched = variants.some((variant) => {
      const localErrors: ValidationError[] = [];
      validateNode(variant, value, path, doc, localErrors);
      return localErrors.length === 0;
    });
    if (!matched) out.push({ path, message: 'value matches none of anyOf' });
    return;
  }
  if (schema.oneOf) {
    const variants = schema.oneOf as JsonSchema[];
    const matches = variants.filter((variant) => {
      const localErrors: ValidationError[] = [];
      validateNode(variant, value, path, doc, localErrors);
      return localErrors.length === 0;
    });
    if (matches.length !== 1) out.push({ path, message: 'value matches none or more than one of oneOf' });
    return;
  }
  if (schema.const !== undefined) {
    if (value !== schema.const) out.push({ path, message: `expected constant ${String(schema.const)}` });
    return;
  }
  if (schema.enum) {
    if (!(schema.enum as unknown[]).includes(value)) out.push({ path, message: 'value not in enum' });
    return;
  }
  const type = schema.type as string | undefined;
  if (type === 'null') {
    if (value !== null) out.push({ path, message: 'expected null' });
    return;
  }
  if (type === 'string') {
    if (typeof value !== 'string') {
      out.push({ path, message: 'expected string' });
      return;
    }
    if (typeof schema.minLength === 'number' && value.length < schema.minLength) out.push({ path, message: 'too short' });
    if (typeof schema.maxLength === 'number' && value.length > schema.maxLength) out.push({ path, message: 'too long' });
    if (typeof schema.pattern === 'string' && !new RegExp(schema.pattern).test(value)) out.push({ path, message: 'pattern mismatch' });
    if (typeof schema.format === 'string' && !formatOk(schema.format, value)) out.push({ path, message: `bad format ${schema.format}` });
    return;
  }
  if (type === 'integer' || type === 'number') {
    if (typeof value !== 'number') {
      out.push({ path, message: 'expected number' });
      return;
    }
    if (type === 'integer' && !Number.isInteger(value)) out.push({ path, message: 'expected integer' });
    if (typeof schema.minimum === 'number' && value < schema.minimum) out.push({ path, message: 'below minimum' });
    if (typeof schema.maximum === 'number' && value > schema.maximum) out.push({ path, message: 'above maximum' });
    return;
  }
  if (type === 'boolean') {
    if (typeof value !== 'boolean') out.push({ path, message: 'expected boolean' });
    return;
  }
  if (type === 'array') {
    if (!Array.isArray(value)) {
      out.push({ path, message: 'expected array' });
      return;
    }
    if (typeof schema.minItems === 'number' && value.length < schema.minItems) out.push({ path, message: 'too few items' });
    if (typeof schema.maxItems === 'number' && value.length > schema.maxItems) out.push({ path, message: 'too many items' });
    if (schema.items) {
      value.forEach((item, i) => validateNode(schema.items as JsonSchema, item, `${path}[${i}]`, doc, out));
    }
    return;
  }
  if (type === 'object') {
    if (typeof value !== 'object' || value === null || Array.isArray(value)) {
      out.push({ path, message: 'expected object' });
      return;
    }
    const obj = value as Record<string, unknown>;
    const required = (schema.required as string[]) ?? [];
    for (const key of required) {
      if (!(key in obj)) out.push({ path: `${path}.${key}`, message: 'missing required property' });
    }
    const properties = (schema.properties as Record<string, JsonSchema>) ?? {};
    if (schema.additionalProperties === false) {
      for (const key of Object.keys(properties)) {
        if (key in obj) validateNode(properties[key], obj[key], `${path}.${key}`, doc, out);
      }
    } else {
      for (const key of Object.keys(obj)) {
        const propSchema = properties[key] ?? (typeof schema.additionalProperties === 'object' ? (schema.additionalProperties as JsonSchema) : null);
        if (propSchema) validateNode(propSchema, obj[key], `${path}.${key}`, doc, out);
      }
    }
    return;
  }
}

export function validate(schema: JsonSchema | undefined, value: unknown, doc: JsonSchema = schema ?? {}): ValidationError[] {
  if (!schema) return [];
  const out: ValidationError[] = [];
  validateNode(schema, value, '$', doc, out);
  return out;
}

export function resolveSchemaRef(schema: JsonSchema | undefined): { schema: JsonSchema; doc: JsonSchema } | undefined {
  if (!schema) return undefined;
  const ref = (schema as { $ref?: unknown }).$ref;
  if (typeof ref !== 'string') return { schema, doc: schema };
  const hashIndex = ref.indexOf('#');
  const docPart = hashIndex >= 0 ? ref.slice(0, hashIndex) : '';
  if (docPart) {
    const module = docPart.replace(/\.schema\.json$/, '');
    const moduleDoc = runtime.registry?.schemas[module];
    if (!moduleDoc) return undefined;
  }
  const resolved = resolveRef(ref, schema);
  if (!resolved.schema || Object.keys(resolved.schema).length === 0) return undefined;
  return { schema: resolved.schema, doc: resolved.doc };
}
