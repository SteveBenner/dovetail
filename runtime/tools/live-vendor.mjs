import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { build } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import tailwindcss from '@tailwindcss/vite';

const runtimeRoot = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const srcDir = path.join(runtimeRoot, 'src');

export async function buildRuntimeVendor({ outDir, out, moduleIds, liveEntries }) {
  const entries = {
    index: path.join(srcDir, 'index.ts'),
    internal: path.join(srcDir, 'internal.ts'),
    components: path.join(srcDir, 'components.ts'),
    icons: path.join(srcDir, 'icons.ts')
  };
  for (const mod of moduleIds) {
    entries[`live-bind/${mod}`] = path.join(out, 'live-bind-src', `${mod}.ts`);
    entries[`generated-client/${mod}`] = path.join(out, 'generated', 'client', `${mod}.ts`);
  }
  for (const entry of liveEntries) {
    entries[`live-shim/${entry.id}`] = entry.shimSrcPath;
  }

  const result = await build({
    root: runtimeRoot,
    logLevel: 'warn',
    cacheDir: path.join(out, 'vite-cache-vendor'),
    resolve: {
      alias: [
        { find: '@dovetail/runtime/internal', replacement: path.join(srcDir, 'internal.ts') },
        { find: '@dovetail/runtime/components', replacement: path.join(srcDir, 'components.ts') },
        { find: '@dovetail/runtime/icons', replacement: path.join(srcDir, 'icons.ts') },
        { find: '@dovetail/runtime', replacement: path.join(srcDir, 'index.ts') }
      ]
    },
    plugins: [svelte({ compilerOptions: { css: 'injected' } }), tailwindcss()],
    build: {
      outDir: path.resolve(outDir),
      emptyOutDir: true,
      cssCodeSplit: false,
      lib: {
        entry: entries,
        formats: ['es']
      },
      rollupOptions: {
        external: [/^svelte(\/.*)?$/],
        output: {
          entryFileNames: '[name].js',
          chunkFileNames: 'chunks/[name]-[hash].js',
          assetFileNames: 'assets/[name][extname]'
        }
      }
    }
  });

  const bundle = Array.isArray(result) ? result.flatMap((r) => r.output) : result.output;
  const cssFiles = bundle.filter((o) => o.fileName && o.fileName.endsWith('.css')).map((o) => o.fileName);
  return { cssFiles };
}

export async function buildSvelteVendor({ outDir, out }) {
  const entries = {
    index: path.join(runtimeRoot, 'node_modules', 'svelte', 'src', 'index-client.js'),
    'internal-client': path.join(runtimeRoot, 'node_modules', 'svelte', 'src', 'internal', 'client', 'index.js'),
    'internal-disclose-version': path.join(runtimeRoot, 'node_modules', 'svelte', 'src', 'internal', 'disclose-version.js'),
    'internal-flags-legacy': path.join(runtimeRoot, 'node_modules', 'svelte', 'src', 'internal', 'flags', 'legacy.js'),
    'internal-flags-async': path.join(runtimeRoot, 'node_modules', 'svelte', 'src', 'internal', 'flags', 'async.js'),
    'internal-flags-tracing': path.join(runtimeRoot, 'node_modules', 'svelte', 'src', 'internal', 'flags', 'tracing.js'),
    store: path.join(runtimeRoot, 'node_modules', 'svelte', 'src', 'store', 'index-client.js'),
    motion: path.join(runtimeRoot, 'node_modules', 'svelte', 'src', 'motion', 'index.js'),
    transition: path.join(runtimeRoot, 'node_modules', 'svelte', 'src', 'transition', 'index.js'),
    easing: path.join(runtimeRoot, 'node_modules', 'svelte', 'src', 'easing', 'index.js'),
    animate: path.join(runtimeRoot, 'node_modules', 'svelte', 'src', 'animate', 'index.js'),
    legacy: path.join(runtimeRoot, 'node_modules', 'svelte', 'src', 'legacy', 'legacy-client.js'),
    compiler: path.join(runtimeRoot, 'node_modules', 'svelte', 'src', 'compiler', 'index.js')
  };

  await build({
    root: runtimeRoot,
    logLevel: 'warn',
    cacheDir: path.join(out, 'vite-cache-svelte-vendor'),
    build: {
      outDir: path.resolve(outDir),
      emptyOutDir: true,
      cssCodeSplit: false,
      lib: {
        entry: entries,
        formats: ['es']
      },
      rollupOptions: {
        output: {
          entryFileNames: '[name].js',
          chunkFileNames: 'chunks/[name]-[hash].js',
          assetFileNames: 'assets/[name][extname]'
        }
      }
    }
  });
}
