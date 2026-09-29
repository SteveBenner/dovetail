# Live components

A live build leaves chosen component files out of the bundle. Instead, the browser fetches each one's source when
the page needs it, compiles it with the Svelte compiler, and mounts it, so a machine with only Ruby and a Chromium
can render an edited component with no build step at all. Everything else about the application, and every panel
that is not marked live, works exactly as it does in a normal fuse.

## Turning it on

`dovetail.yml` takes two new fields:

```yaml
live: [modules/*/panel/src/cutouts/*.svelte]
live_base: /live/
```

`live` is a list of globs, resolved against the application root; a file matching one of them is loaded live instead
of bundled. It defaults to an empty list, in which case a fuse is unchanged from a build with no live components at
all. `live_base` is the URL path prefix live sources are fetched from; it defaults to `/live/`.

`dovetail fuse --live <glob>` adds to the configured list for one run, and is repeatable:

```console
$ dovetail fuse --app ui --panels modules/finance/panel --live 'modules/finance/panel/src/cutouts/*.svelte'
```

Only files under a panel directory can be marked live; a live glob that matches something else fails the fuse and
names the file.

## What a live component may import

A live component is still ordinary Svelte, written the same way as a bundled one. What it may import from is fixed:

- `@dovetail/runtime`, bound to its own module exactly as a bundled panel file's import is; its primitives, its
  components, and its types. Its `/components`, `/icons` and `/internal` subpaths work too.
- `svelte`, and any `svelte/*` entry the compiled component needs.
- `$generated/client/<module>`, the module's own compiled client, and `import type` from `$generated/types/*`, which
  the compiler removes. A value import from any other `$generated/*` entry fails when the component loads.
- A relative import of another file under the application root, when that file is itself live.

An import of anything else fails when the component loads, with a message naming the specifier, so nothing reaches
the page that the checker never saw.

## How it is served

The build stays static. Whatever serves `<out>/dist` must also serve live sources at `live_base`, from the
application root, with a `text/plain` or `text/javascript` content type and `Cache-Control: no-store`, so an edit on
disk is never cached. `dovetail fuse --verify`'s own server does this for a live build automatically; a consumer
serving the built application itself only needs to add that one route.

## Sharing one runtime

The Svelte runtime and `@dovetail/runtime`, with its `components`, `icons` and `internal` entries, are each built
once as a shared ES module and named in an import map in `index.html`. Bundled code and live-loaded code both resolve
these through the same import map entries, so there is one instance of each: contexts, the overlay host, the router,
the event bus and the panel API behave in a live component exactly as they do in a bundled one. The Svelte compiler
itself is fetched only the first time the page needs to compile a live component; later ones reuse it.

## When a live component fails

A fetch, compile or import failure renders inside the panel's existing error boundary, the same fallback card a
crash shows, with the compiler's message, and logs one `console.error` naming the file. It never blanks the page and
never stops another panel from working.

## Styling

A live build styles the generated CSS with the full token-class vocabulary, not only the classes a bundled file
happens to use, so a class a live component reaches for renders without a rebuild. A component's own `<style>`
block is compiled in and injected exactly as it would be in a bundled build, and is still held to the same rules the
checker enforces on a bundled file's styles.

## Limits

- Live components add real latency to their own first render: the source is fetched and compiled in the browser,
  not read from a pre-built bundle. Later components on the same page reuse the already-loaded compiler.
- A live component is not type-checked at fuse time the way a bundled one is when Node is present; run
  `dovetail check` on it as you would on any panel file.
- Live loading is meant for development and for hosts without Node, such as a course repository serving its own
  `/live/` route; a production deployment that wants build-time optimisation should leave `live` empty.
