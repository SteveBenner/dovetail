import fs from 'node:fs';
import path from 'node:path';
import { createServer } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';
import tailwindcss from '@tailwindcss/vite';
import { dovetailBindingPlugin, dovetailAliases } from './dovetail-plugin.mjs';

async function main() {
  const configPath = process.argv[2];
  if (!configPath) {
    process.stderr.write('dev-server: missing config path argument\n');
    process.exit(1);
  }
  const config = JSON.parse(fs.readFileSync(configPath, 'utf8'));
  const { root, panels, out, backend, port } = config;

  const proxy = backend
    ? { '/api': { target: backend, changeOrigin: true } }
    : undefined;

  const server = await createServer({
    root,
    logLevel: 'info',
    cacheDir: path.join(out, 'vite-cache'),
    define: {
      'import.meta.env.VITE_DOVETAIL_BACKEND': backend ? JSON.stringify('proxy') : 'undefined'
    },
    resolve: {
      alias: dovetailAliases(out, true)
    },
    optimizeDeps: {
      exclude: ['@dovetail/runtime']
    },
    plugins: [svelte(), tailwindcss(), dovetailBindingPlugin(panels, out)],
    server: {
      host: '127.0.0.1',
      port: port || 5173,
      strictPort: true,
      proxy
    }
  });

  await server.listen();
  server.printUrls();

  const findingsPath = `${out}/dev-findings.json`;
  let lastSeen = null;
  const poll = setInterval(() => {
    if (!fs.existsSync(findingsPath)) return;
    const content = fs.readFileSync(findingsPath, 'utf8');
    if (content === lastSeen) return;
    lastSeen = content;
    let data;
    try {
      data = JSON.parse(content);
    } catch (error) {
      return;
    }
    server.ws.send({ type: 'custom', event: 'dovetail:findings', data });
  }, 1000);

  const shutdown = async () => {
    clearInterval(poll);
    await server.close();
    process.exit(0);
  };
  process.on('SIGINT', shutdown);
  process.on('SIGTERM', shutdown);
}

main().catch((error) => {
  process.stderr.write(String(error && error.stack ? error.stack : error) + '\n');
  process.exit(1);
});
