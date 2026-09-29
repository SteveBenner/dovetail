import { resolveRef } from '../validate/jsonschema.js';
import type { JsonSchema } from '../types.js';

function refName(schema: JsonSchema, doc: JsonSchema): { schema: JsonSchema; doc: JsonSchema; name: string } | null {
  if (typeof schema.$ref === 'string') {
    return resolveRef(schema.$ref, doc);
  }
  return null;
}

function nullableInner(schema: JsonSchema): JsonSchema | null {
  const anyOf = schema.anyOf as JsonSchema[] | undefined;
  if (!anyOf) return null;
  return anyOf.find((s) => s.type !== 'null') ?? null;
}

export function fixture(schema: JsonSchema | undefined, doc: JsonSchema = schema ?? {}, propertyName = 'value'): unknown {
  if (!schema) return null;
  const nullable = nullableInner(schema);
  if (nullable) return fixture(nullable, doc, propertyName);
  if (schema.oneOf) {
    const first = (schema.oneOf as JsonSchema[])[0];
    return fixture(first, doc, propertyName);
  }
  if (schema.const !== undefined) return schema.const;
  if (schema.enum) return (schema.enum as unknown[])[0];
  const ref = refName(schema, doc);
  if (ref) {
    if (ref.name === '_Decimal' || ref.name === '_Percent') return '12.50';
    if (ref.name === '_Id') return 'id-1';
    if (ref.name === '_CurrencyCode') return 'USD';
    if (ref.name === '_Money') return { amount: '1250.00', currency: 'USD' };
    return fixture(ref.schema, ref.doc, propertyName);
  }
  const type = schema.type as string | undefined;
  if (type === 'string') {
    if (schema.format === 'date') return '2026-10-03';
    if (schema.format === 'date-time') return '2026-10-03T09:30:00Z';
    if (schema.format === 'uri') return 'https://example.com';
    if (schema.format === 'email') return 'sample@example.com';
    if (typeof schema.pattern === 'string' && /\^\[A-Z\]\{3\}\$/.test(schema.pattern)) return 'USD';
    return `Sample ${propertyName}`;
  }
  if (type === 'integer' || type === 'number') return 3;
  if (type === 'boolean') return true;
  if (type === 'array') {
    const items = (schema.items as JsonSchema) ?? {};
    return [0, 1, 2].map((i) => fixture(items, doc, propertyName));
  }
  if (type === 'object') {
    const properties = (schema.properties as Record<string, JsonSchema>) ?? {};
    if (Object.keys(properties).length > 0) {
      const out: Record<string, unknown> = {};
      for (const key of Object.keys(properties)) {
        out[key] = fixture(properties[key], doc, key);
      }
      return out;
    }
    const additional = schema.additionalProperties;
    if (additional && typeof additional === 'object') {
      const out: Record<string, unknown> = {};
      for (const key of ['a', 'b', 'c']) {
        out[key] = fixture(additional as JsonSchema, doc, key);
      }
      return out;
    }
    return {};
  }
  return null;
}

export function emptyFixture(schema: JsonSchema | undefined, doc: JsonSchema = schema ?? {}): unknown {
  if (!schema) return null;
  const nullable = nullableInner(schema);
  if (nullable) return null;
  const ref = refName(schema, doc);
  if (ref) return emptyFixture(ref.schema, ref.doc);
  const type = schema.type as string | undefined;
  if (type === 'array') return [];
  if (type === 'object') {
    const properties = (schema.properties as Record<string, JsonSchema>) ?? {};
    const out: Record<string, unknown> = {};
    for (const key of Object.keys(properties)) {
      out[key] = emptyFixture(properties[key], doc);
    }
    return out;
  }
  return fixture(schema, doc);
}
