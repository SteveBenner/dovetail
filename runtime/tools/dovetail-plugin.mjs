import path from 'node:path';
import { fileURLToPath } from 'node:url';

const runtimeDist = path.join(path.dirname(path.dirname(fileURLToPath(import.meta.url))), 'dist');

export function dovetailBindingPlugin(panels, outDir, live) {
  const resolved = panels.map((p) => ({ module: p.module, dir: path.resolve(p.dir) }));
  const liveByAbs = new Map();
  if (live && live.enabled) {
    for (const entry of live.entries) liveByAbs.set(path.resolve(entry.abs), entry);
  }
  return {
    name: 'dovetail-binding',
    enforce: 'pre',
    resolveId(source, importer) {
      if (liveByAbs.size && importer && (source.startsWith('./') || source.startsWith('../'))) {
        const importerDir = path.dirname(path.resolve(importer));
        const target = path.resolve(importerDir, source);
        const entry = liveByAbs.get(target);
        if (entry) return entry.stubPath;
      }
      if (source === '@dovetail/runtime') {
        if (importer) {
          const abs = path.resolve(importer);
          for (const p of resolved) {
            if (abs === p.dir || abs.startsWith(p.dir + path.sep)) {
              if (live && live.enabled) return { id: `@dovetail/live-runtime/${p.module}`, external: true };
              return path.join(outDir, 'bind', `${p.module}.ts`);
            }
          }
        }
        if (live && live.enabled) return { id: '@dovetail/runtime', external: true };
        return path.join(runtimeDist, 'index.js');
      }
      if (
        live &&
        live.enabled &&
        (source === '@dovetail/runtime/internal' || source === '@dovetail/runtime/components' || source === '@dovetail/runtime/icons')
      ) {
        return { id: source, external: true };
      }
      return null;
    }
  };
}

export function dovetailAliases(outDir, development = false, live = false) {
  const registryFile = development ? 'registry.development.generated.ts' : 'registry.generated.ts';
  const aliases = [
    { find: '$generated', replacement: path.join(outDir, 'generated') },
    { find: '$registry', replacement: path.join(outDir, registryFile) },
    { find: '$dovetail', replacement: outDir }
  ];
  if (!live) {
    aliases.unshift(
      { find: '@dovetail/runtime/internal', replacement: path.join(runtimeDist, 'internal.js') },
      { find: '@dovetail/runtime/components', replacement: path.join(runtimeDist, 'components.js') },
      { find: '@dovetail/runtime/icons', replacement: path.join(runtimeDist, 'icons.js') },
      { find: '@dovetail/runtime/embed', replacement: path.join(runtimeDist, 'embed.js') }
    );
  }
  return aliases;
}

export function dovetailImportMapPlugin(importMap) {
  return {
    name: 'dovetail-import-map',
    transformIndexHtml: {
      order: 'pre',
      handler(html) {
        const tag = `<script type="importmap">${JSON.stringify(importMap)}</script>`;
        return html.replace('<head>', `<head>\n    ${tag}`);
      }
    }
  };
}

export { runtimeDist };
