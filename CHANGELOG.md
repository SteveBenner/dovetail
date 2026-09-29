# Changelog

All notable changes to Dovetail are recorded here. The project follows [Semantic Versioning](https://semver.org/):
rule ids are stable, the shape schema changes only with a new schema id, and the runtime's exported API follows
semver.

## [0.2.0] - 2026-09-28

### Added

- **Live components.** `dovetail.yml` gains `live` (a list of globs) and `live_base`; `dovetail fuse` gains
  `--live <glob>`, repeatable. A matching component is left out of the bundle; the browser fetches it at `live_base`,
  compiles it with the Svelte compiler and mounts it, so a machine with only Ruby and a Chromium can render an edited
  component with no build. The Svelte runtime and `@dovetail/runtime` (with its `components`, `icons` and `internal`
  entries) are each built once as a shared ES module and named in an import map in `index.html`, so bundled and live
  code use one instance of each. A live component may import `@dovetail/runtime` and its `components`, `icons` and
  `internal` entries, `svelte` and its entries, its own module's generated client, type-only imports of generated
  types, and another live file by a relative path; anything else fails with a message naming the specifier.
  A fetch, compile or import failure renders inside the panel's existing fallback card with the compiler's message
  and logs one `console.error` naming the file. `dovetail fuse --verify`'s own server serves live sources for a live
  build; a build with no live globs is unchanged. See [Live components](docs/guides/live-components.md).
- **`dovetail checker export <dir>`**: writes a self-contained copy of the shape checker, standard library only, that
  runs `dovetail check`, `dovetail brief`, `dovetail rules` and `dovetail --version` from its own directory on Ruby
  2.6.10 and later with no repository, no bundler and no gems. It takes exactly one argument; a flag or a second
  argument fails with D-USE-001 instead of being taken for the directory.
- Development hooks `focusInside(id)` and `homeModule()`, and a `data-dovetail-overlay` attribute naming each open
  overlay.

### Changed

- The overlay host moves focus into every overlay when it opens, to its first focusable element or the overlay itself;
  a blocking overlay still also traps it. A non-blocking popover used to open with focus left behind.
- The composition verifier judges a non-blocking overlay by where focus is instead of by the focus trap it never has,
  and looks for a view the panel places in a tile slot on the home module's route, where tiles render.
- The shell template's `index.html` declares an empty favicon, so a new app does not request `/favicon.ico` and log a
  404 on first load.

### Fixed

- `Tooltip` no longer writes its state while it is being torn down. Closing an overlay with Escape while its close
  button's tooltip was pending could fire the tooltip's timer, or its focusout handler, after the overlay unmounted,
  which Svelte reports as `state_unsafe_mutation`. A bundled build hid the race; a live build exposed it on every
  Escape close. The tooltip now clears its timer on destroy and hides in a microtask, outside Svelte's flush.
- `NumberInput` normalises its value on blur in a microtask. A focused input removed during a render fires blur
  inside Svelte's flush, where the old synchronous write threw `state_unsafe_mutation`.
- Runtime icons beside a text label (field errors, checkboxes, selects, table sort carets, empty, error and unavailable
  states, stats, toasts, fallback and not-built cards, icon buttons) are `aria-hidden`, so axe reports no
  `svg-img-alt` on any panel.
- A live component's own generated client (`$generated/client/<module>`) now resolves: the vendor build compiles each
  module's client and the import map names it. Before, every live component that called its module failed to load.
- A live build's import map names Svelte's `internal/flags/legacy`, `async` and `tracing` entries, which compiled
  components import; before, a live component compiled with those flags failed to load.
- The live loader accepts `@dovetail/runtime/components`, `/icons` and `/internal`, which the checker already allowed
  and the import map already named.

## [0.1.0] - 2026-09-28

The first release: contracts, the compiler, the shape checker, the fuser, the composition verifier and the Svelte 5
runtime, with the starter shell and panel.

### Added

- **Contract DSL.** One module's interface in Ruby: types with field options, operations, events, dependencies and
  the panel's shape (slots, views, capabilities, routes, props, tokens, storage keys, shortcuts, overlays). A contract
  file is parsed with Ripper and accepted only when every construct is one the DSL uses, then evaluated in an empty
  context. Misspelled options and values outside a statement's allowed set fail with the file and line.
- **Validation** C001 to C007 across all contracts together, including a module's routes living in its own
  namespace (`/<module id>` with `_` written as `-`) and breaking changes that keep their version.
- **`dovetail compile`**: JSON Schema, TypeScript types, a typed data client, the shape, the brief, the registry
  entry and the contract model per module, byte-identical on Ruby 2.6.10, 3.3 and 4.0.
- **The brief**: a plain-language account of what a panel may and may not do, for its author and their AI agent.
- **`dovetail check`**: the pure-Ruby shape checker, 32 rules across the nine seams plus tokens, markup, messages,
  view states and dependencies. It tracks aliases of `window`, `globalThis`, `self` and `document`, including
  destructuring, and reports what it cannot read as a warning rather than treating it as safe. Text and JSON output;
  strict and relaxed profiles; `--changed` for one file. Also accepts the form Reach calls,
  `dovetail check --require-signed <shape.json>`.
- **Shape signing**: `dovetail sign` with RSA-PSS and SHA-256 over canonical JSON; keys from `--public-key`,
  `DOVETAIL_PUBLIC_KEYS` or `dovetail.yml`, with several keys accepted for rotation.
- **`dovetail fuse`**: validates every contract, checks every panel, type-checks panels against their generated
  types, detects shortcut and overlay collisions between panels, checks every theme supplies every token, generates
  the shell registry, and builds with Vite. `<out>/dist` holds only the production bundle; the report is
  `<out>/fuse-report.json`. With `node: false` it decides everything without Node.
- **`dovetail verify`**: drives a development build in headless Chrome through Ferrum and runs the composition
  journeys (overlays, stacked overlays, routes, events, forced view states, leaks, slot bounds, crashes and an
  axe-core pass), failing on any uncaught exception, unhandled rejection, `console.error` or failed request.
- **`@dovetail/runtime`**: the shell host with placement and routing, a panel host with an error boundary and a
  failure budget, one primitive per seam, translations in ICU MessageFormat with locale formatting, and 18 components
  styled only from theme tokens. The HTTP transport limits each module to six requests in flight and ten a second,
  retries only idempotent operations with full-jitter backoff, honours `Retry-After`, has a circuit breaker with a
  single half-open probe and kill switches; server events arrive over Server-Sent Events. About 43 KB gzipped.
- **`dovetail new`**: a starter shell with apple-noir, apple-austere and tronwave themes mapped onto Dovetail's
  tokens, and a starter panel with a working view.
- **`dovetail dev`**: a development server that re-checks each changed file and shows findings in the terminal and
  an in-page toolbar that can force view states and crash a panel; `--static` serves findings without Node.
- **`dovetail messages check`**, `dovetail rules`, `dovetail brief`, `dovetail contract lint|diff|show`.
- Guides and reference under `docs/`.

### Known limitations

- The shell passes no props to panels yet: `prop` is declared and typed, and `useProps()` returns an empty object.
- `dovetail verify` needs Ruby 3.0 or newer; everything else runs on Ruby 2.6.10.
- The gem and the npm package are not published; use a checkout.
- The licence is declared as AGPL-3.0-only and is not final.
