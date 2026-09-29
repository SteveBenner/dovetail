export function isSnippet(value: unknown): boolean {
  return typeof value === 'function' && !('prototype' in value);
}
