let compilerPromise: Promise<typeof import('svelte/compiler')> | null = null;

function getCompiler(): Promise<typeof import('svelte/compiler')> {
  if (!compilerPromise) compilerPromise = import('svelte/compiler');
  return compilerPromise;
}

function joinRelative(rel: string, specifier: string): string {
  const dir = rel.split('/').slice(0, -1);
  for (const part of specifier.split('/')) {
    if (part === '' || part === '.') continue;
    if (part === '..') dir.pop();
    else dir.push(part);
  }
  return dir.join('/');
}

const RUNTIME_SUBPATHS = new Set(['@dovetail/runtime/components', '@dovetail/runtime/icons', '@dovetail/runtime/internal']);

function resolveSpecifier(specifier: string, rel: string, mod: string): string {
  if (specifier === 'svelte' || specifier.startsWith('svelte/')) return specifier;
  if (specifier === '@dovetail/runtime') return `@dovetail/live-runtime/${mod}`;
  if (RUNTIME_SUBPATHS.has(specifier)) return specifier;
  if (specifier === `$generated/client/${mod}`) return specifier;
  if (specifier.startsWith('$generated/')) {
    throw new Error(`disallowed import '${specifier}' (a live component may import only its own module's generated client, $generated/client/${mod})`);
  }
  if (specifier.startsWith('./') || specifier.startsWith('../')) {
    return `dovetail-live:${joinRelative(rel, specifier)}`;
  }
  throw new Error(`disallowed import '${specifier}'`);
}

const IMPORT_SPECIFIER_RE = /^(\s*(?:import|export)\b[^'";]*?\bfrom\s*)(['"])([^'"]+)\2|(\bimport\s*\(\s*)(['"])([^'"]+)\5(\s*\))/gm;

export function rewriteImports(code: string, rel: string, mod: string): string {
  return code.replace(
    IMPORT_SPECIFIER_RE,
    (_match, fromKw, fromQuote, fromSpec, importKw, importQuote, importSpec, closeParen) => {
      const specifier = fromSpec !== undefined ? fromSpec : importSpec;
      const replacement = resolveSpecifier(specifier, rel, mod);
      if (fromKw !== undefined) return `${fromKw}${fromQuote}${replacement}${fromQuote}`;
      return `${importKw}${importQuote}${replacement}${importQuote}${closeParen}`;
    }
  );
}

const componentCache = new Map<string, Promise<unknown>>();

export function loadLive(specifier: string, rel: string, mod: string): Promise<any> {
  const cached = componentCache.get(rel);
  if (cached) return cached;
  const promise = (async () => {
    const response = await fetch(specifier, { cache: 'no-store' });
    if (!response.ok) {
      throw new Error(`could not fetch ${specifier} (${response.status} ${response.statusText})`);
    }
    const source = await response.text();
    const { compile } = await getCompiler();
    let compiled: { js: { code: string } };
    try {
      compiled = compile(source, { filename: rel, generate: 'client', css: 'injected' }) as { js: { code: string } };
    } catch (error) {
      throw new Error(`could not compile ${rel}: ${error instanceof Error ? error.message : String(error)}`);
    }
    const rewritten = rewriteImports(compiled.js.code, rel, mod);
    const blob = new Blob([rewritten], { type: 'text/javascript' });
    const url = URL.createObjectURL(blob);
    try {
      const evaluated = await import(/* @vite-ignore */ url);
      return evaluated.default;
    } finally {
      URL.revokeObjectURL(url);
    }
  })();
  componentCache.set(rel, promise);
  promise.catch(() => componentCache.delete(rel));
  return promise;
}
