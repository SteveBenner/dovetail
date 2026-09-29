# Fusing and verifying

Each panel's author checks their own panel against its shape. Fusing is the step where every panel meets every other
one: the contracts are validated together, every panel is checked, collisions between panels are caught, and the
application is built. Verifying then drives the built application in a browser and exercises every seam across panels.

```console
$ dovetail fuse --app ui --verify
fused 3 panels
```

## What fuse does, in order

1. **Contracts.** Loads every contract the `contracts` glob in `dovetail.yml` names, including modules with no panel,
   and validates them together, so a consumed event must exist in its producer (C001 to C007). A breaking change
   that kept its version is caught against the model the previous fuse left behind.
2. **Checks.** Runs the shape checker on every panel. Any error stops the fuse with `D-FUS-001` and names the panel.
3. **Type check.** Runs svelte-check on each panel against its generated types, when Node is available.
4. **Collisions.** Two panels binding the same shortcut in overlapping scopes, or declaring an overlay with the same
   name, stop the fuse with `D-FUS-002`. Routes cannot collide, because each module's routes live in its own
   namespace (C005), and storage keys are namespaced by module.
5. **Themes.** Every theme must supply every token, or the fuse stops with `D-TOK-001` naming the theme and the key.
6. **Generate.** Writes the shell's registry, each panel's bound runtime module, the application's stylesheet and
   `prefetch.json`, which lists for every route the data operations the shell starts when that route is entered.
7. **Build.** Builds the application with Vite into `<out>/dist`, and with `embed` also into `<out>/dist/embed` as a
   custom element (see [Embedding](embedding.md)). A build failure is `D-FUS-004`.
8. **Verify.** With `--verify`, builds a development bundle into `<out>/verify-build` and runs the composition journeys
   against it.
9. **Report.** Writes `<out>/fuse-report.json`.

Exit 0 means fused, 1 means a check failed, 2 means the fuser could not run. The report records each step, so a
failure can be read afterwards:

```json
{
  "contract_versions": { "activity": 1, "context": 1, "finance": 2, "settings": 1 },
  "duration_ms": 7768,
  "panels": ["activity", "finance", "settings"],
  "steps": {
    "contracts": { "modules": ["activity", "context", "finance", "settings"], "ok": true },
    "checks": { "finance": { "findings": [], "panel": "finance", "summary": { "errors": 0, "warnings": 0 } } },
    "type_check": { "finance": { "ok": true } },
    "collisions": { "overlays": [], "routes": [], "shortcuts": [], "storage": [] },
    "themes": { "checked": ["apple-austere.json", "apple-noir.json", "tronwave.json"] },
    "generate": { "generated": ["registry.generated.ts", "app.css", "bind/finance.ts"] },
    "build": { "ok": true },
    "verify": { "journeys": [], "ok": true }
  }
}
```

## Fusing without Node

Every decision about whether a panel is acceptable is made in Ruby, so a fuse without Node still tells you whether the
panels fit. Set `node: false` in `dovetail.yml`: the contracts, checks, collisions and themes run, and the type check
and build are recorded as skipped. Ten panels fuse this way in well under a second on Ruby 2.6.

## Placement

The shell's `ui/layout.yml` declares its slots, and each panel slot goes to the layout slot of the same name, or else
to the first layout slot of the same size. The layout slots `main` and `full` show the panel that owns the current
route; `aside` shows that panel's aside slot; `tile` slots show while the home route is active; `strip` slots in the
dock are always there. `/` shows the first route of the layout's `home` module.

## Isolation

Every panel mounts inside an error boundary. When a panel throws, while rendering, in an effect or in an event
handler, the boundary unmounts it, releases its overlays, handlers, shortcuts and timers, and shows a fallback card
with the module's name and a Reload panel action. The other panels carry on. A panel that fails three times in five
minutes stays in its fallback until the page reloads.

Panels are styled through Svelte's component scoping, and the shell never styles inside a panel except through tokens.

## The composition journeys

`dovetail verify`, or `fuse --verify`, serves the development build on 127.0.0.1 and drives it with headless Chrome.

| Journey | What it proves |
| --- | --- |
| overlay | Each declared overlay opens in the browser's top layer, takes focus, closes on Escape when dismissible, returns focus and releases scroll lock |
| stacked overlays | Two blocking overlays from different panels stack in order, and closing the top one keeps the lower one's focus trap |
| route | Every declared route renders its own panel, and no other panel's route handling fires |
| event | Every declared event reaches each consumer and no panel that did not declare it |
| state | Every view renders each of its states without a console error |
| leak | Unmounting and remounting each panel leaves no timers, listeners or subscriptions behind |
| slot | At each slot's narrow and wide widths, no panel paints outside its slot |
| crash | A deliberately crashed panel shows its fallback while every other panel still responds |
| accessibility | axe-core finds no serious or critical issue on any route |
| embed | With `embed`, the element renders in a hostile host page, its blocking overlays escape the host's clipping, and neither side's styles reach the other |

Every journey also fails on an uncaught exception, a `console.error`, or a failed network request the flow did not
intend. A failure prints its journey and panel, exits 1 with `D-VER-001`, and leaves a screenshot in
`<out>/screenshots`. Ten panels verify in well under the three-minute budget.

## Live components

`dovetail fuse --live <glob>` leaves the matching component files out of the bundle and loads them in the browser
instead, so a machine with only Ruby and a Chromium can render an edited component without a build. See
[Live components](live-components.md).

## Before you ship

`<out>/dist` holds the production bundle and nothing else, so it is what you deploy. The development hooks the
verifier uses are not in it.
