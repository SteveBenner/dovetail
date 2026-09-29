import fs from 'node:fs';
import path from 'node:path';
import { build } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import tailwindcss from '@tailwindcss/vite';
import { dovetailBindingPlugin, dovetailAliases, dovetailImportMapPlugin } from './dovetail-plugin.mjs';
import { buildRuntimeVendor, buildSvelteVendor } from './live-vendor.mjs';

const SVELTE_VENDOR_SPECIFIERS = {
  index: 'svelte',
  'internal-client': 'svelte/internal/client',
  'internal-disclose-version': 'svelte/internal/disclose-version',
  'internal-flags-legacy': 'svelte/internal/flags/legacy',
  'internal-flags-async': 'svelte/internal/flags/async',
  'internal-flags-tracing': 'svelte/internal/flags/tracing',
  store: 'svelte/store',
  motion: 'svelte/motion',
  transition: 'svelte/transition',
  easing: 'svelte/easing',
  animate: 'svelte/animate',
  legacy: 'svelte/legacy',
  compiler: 'svelte/compiler'
};

function buildImportMap(live) {
  const imports = {};
  imports['@dovetail/runtime'] = './vendor/dovetail-runtime/index.js';
  imports['@dovetail/runtime/internal'] = './vendor/dovetail-runtime/internal.js';
  imports['@dovetail/runtime/components'] = './vendor/dovetail-runtime/components.js';
  imports['@dovetail/runtime/icons'] = './vendor/dovetail-runtime/icons.js';
  for (const mod of live.moduleIds) {
    imports[`@dovetail/live-runtime/${mod}`] = `./vendor/dovetail-runtime/live-bind/${mod}.js`;
    imports[`$generated/client/${mod}`] = `./vendor/dovetail-runtime/generated-client/${mod}.js`;
  }
  for (const entry of live.entries) {
    imports[`dovetail-live:${entry.rel}`] = `./vendor/dovetail-runtime/live-shim/${entry.id}.js`;
  }
  for (const key of Object.keys(SVELTE_VENDOR_SPECIFIERS)) {
    imports[SVELTE_VENDOR_SPECIFIERS[key]] = `./vendor/svelte/${key}.js`;
  }
  return { imports };
}

async function buildLiveVendorAssets(out, outDir, live) {
  await buildSvelteVendor({ outDir: path.join(outDir, 'vendor', 'svelte'), out });
  await buildRuntimeVendor({
    outDir: path.join(outDir, 'vendor', 'dovetail-runtime'),
    out,
    moduleIds: live.moduleIds,
    liveEntries: live.entries.map((entry) => ({ id: entry.id, shimSrcPath: entry.shimSrcPath }))
  });
  const generatedSrc = path.join(out, 'generated');
  if (fs.existsSync(generatedSrc)) {
    fs.cpSync(generatedSrc, path.join(outDir, 'generated'), { recursive: true });
  }
}

async function main() {
  const configPath = process.argv[2];
  if (!configPath) {
    process.stderr.write('fuse-build: missing config path argument\n');
    process.exit(1);
  }
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const { root, outDir, panels, out, development } = config;
  const live = config.live && config.live.enabled ? config.live : { enabled: false, moduleIds: [], entries: [], base: '/live/' };

  const plugins = [svelte(), tailwindcss(), dovetailBindingPlugin(panels, out, live)];
  if (live.enabled) {
    plugins.push(dovetailImportMapPlugin(buildImportMap(live)));
  }

  await build({
    root,
    logLevel: 'warn',
    cacheDir: path.join(out, 'vite-cache'),
    define: {
      'import.meta.env.VITE_DOVETAIL_BACKEND': development && config.backend ? JSON.stringify('proxy') : 'undefined'
    },
    resolve: {
      alias: dovetailAliases(out, development, live.enabled)
    },
    plugins,
    build: {
      outDir: path.resolve(outDir),
      emptyOutDir: true,
      rollupOptions: live.enabled
        ? {
            external: [/^svelte(\/.*)?$/]
          }
        : undefined
    }
  });

  if (live.enabled) {
    await buildLiveVendorAssets(out, path.resolve(outDir), live);
  }
}

main().catch((error) => {
  process.stderr.write(String(error && error.stack ? error.stack : error) + '\n');
  process.exit(1);
});
