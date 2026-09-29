import type { LocationAdapter } from '../types.js';

export function createHistoryLocation(): LocationAdapter {
  return {
    mode: 'history',
    path: () => location.pathname,
    search: () => location.search,
    push: (path) => history.pushState({}, '', path),
    replace: (path) => history.replaceState({}, '', path),
    listen(onChange) {
      window.addEventListener('popstate', onChange);
      return () => window.removeEventListener('popstate', onChange);
    }
  };
}

export function createMemoryLocation(initial: string): LocationAdapter {
  const split = (value: string): [string, string] => {
    const index = value.indexOf('?');
    return index < 0 ? [value, ''] : [value.slice(0, index), value.slice(index)];
  };
  const [initialPath, initialSearch] = split(initial);
  let currentPath = $state(initialPath);
  let currentSearch = $state(initialSearch);
  const set = (value: string): void => {
    const [nextPath, nextSearch] = split(value);
    currentPath = nextPath;
    currentSearch = nextSearch;
  };
  return {
    mode: 'memory',
    path: () => currentPath,
    search: () => currentSearch,
    push: set,
    replace: set,
    listen: () => () => {}
  };
}
