import { runtime, findPanel, hostEvent } from '../../shell/state.svelte.js';
import { tInternal } from '../../i18n/t.js';
import type { Registry } from '../../types.js';

export interface MatchResult {
  module: string;
  pattern: string;
  params: Record<string, string>;
}

function segments(path: string): string[] {
  return path.split('?')[0].split('/').filter((s) => s.length > 0);
}

export function matchPattern(pattern: string, path: string): Record<string, string> | null {
  const patternSegments = segments(pattern);
  const pathSegments = segments(path);
  if (patternSegments.length !== pathSegments.length) return null;
  const params: Record<string, string> = {};
  for (let i = 0; i < patternSegments.length; i += 1) {
    const p = patternSegments[i];
    const s = pathSegments[i];
    if (p.startsWith(':')) {
      params[p.slice(1)] = decodeURIComponent(s);
    } else if (p !== s) {
      return null;
    }
  }
  return params;
}

export function resolvePath(path: string, registry: Registry): MatchResult | null {
  for (const panel of registry.panels) {
    for (const pattern of panel.routes) {
      const params = matchPattern(pattern, path);
      if (params) return { module: panel.module, pattern, params };
    }
  }
  return null;
}

export function parseQuery(path: string, module: string | null): Record<string, string> {
  const qIndex = path.indexOf('?');
  if (qIndex < 0) return {};
  const search = new URLSearchParams(path.slice(qIndex + 1));
  const out: Record<string, string> = {};
  const prefix = module ? `${module}.` : null;
  for (const [key, value] of search.entries()) {
    if (!prefix || key.startsWith(prefix)) {
      out[prefix ? key.slice(prefix.length) : key] = value;
    }
  }
  return out;
}

export function buildPath(pattern: string, params: Record<string, string> = {}): string {
  return (
    '/' +
    segments(pattern)
      .map((s) => (s.startsWith(':') ? encodeURIComponent(params[s.slice(1)] ?? '') : s))
      .join('/')
  );
}

function warnUndeclaredRoute(module: string, route: string): void {
  if (runtime.development) {
    runtime.runtimeViolations.push({ module, code: 'D-RUN-002', message: `RouteNotDeclared ${route}` });
    throw new Error(`Dovetail: D-RUN-002 RouteNotDeclared ${route}`);
  }
  console.warn(`Dovetail: route ${route} is not declared for ${module}`);
}

export function navigateFor(
  module: string,
  route: string,
  params?: Record<string, string>,
  options?: { replace?: boolean }
): void {
  const panel = findPanel(module);
  if (!panel?.routes.includes(route)) {
    warnUndeclaredRoute(module, route);
    return;
  }
  const path = buildPath(route, params);
  if (options?.replace) {
    runtime.location.replace(path);
  } else {
    runtime.location.push(path);
  }
  dispatchRouteChange();
}

export function linkFor(module: string, route: string, params?: Record<string, string>): string {
  const panel = findPanel(module);
  if (!panel?.routes.includes(route)) {
    warnUndeclaredRoute(module, route);
    return '#';
  }
  return buildPath(route, params);
}

export function useRouteFor(module: string) {
  return {
    get pattern() {
      return runtime.route.module === module ? runtime.route.pattern : null;
    },
    get params() {
      return runtime.route.module === module ? runtime.route.params : {};
    },
    get query() {
      return parseQuery(runtime.location.path() + runtime.location.search(), module);
    }
  };
}

export function useNavigation(): Array<{ label: string; href: string; active: boolean; module: string }> {
  const registry = runtime.registry;
  if (!registry) return [];
  return registry.layout.navigation.map((entry) => ({
    label: tInternal(entry.label_key),
    href: entry.route,
    active: runtime.route.module === entry.module,
    module: entry.module
  }));
}

export function dispatchRouteChange(): void {
  if (!runtime.registry) return;
  const path = runtime.location.path();
  const match = resolvePath(path, runtime.registry);
  runtime.route = {
    path,
    module: match?.module ?? null,
    pattern: match?.pattern ?? null,
    params: match?.params ?? {},
    query: parseQuery(path + runtime.location.search(), match?.module ?? null)
  };
  if (match) {
    runtime.routeLog.push({ module: match.module, pattern: match.pattern, path });
  }
  hostEvent('dovetail-route', { path, module: match?.module ?? null });
}
