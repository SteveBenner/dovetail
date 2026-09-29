# CLI

```
dovetail <command> [options]
```

| Command | Does |
| --- | --- |
| [`compile`](#compile) | Emits schemas, types, clients, shapes, briefs and registry entries from contracts |
| [`check`](#check) | Checks a panel's code against its shape |
| [`fuse`](#fuse) | Checks every panel and assembles the application |
| [`verify`](#verify) | Runs the composition journeys against a fused development build |
| [`contract`](#contract) | Lints a contract, classifies changes between two versions, or prints its model |
| [`brief`](#brief) | Prints a panel's brief |
| [`sign`](#sign) | Signs a shape |
| [`new`](#new) | Scaffolds a shell or a panel |
| [`rules`](#rules) | Prints the rule catalogue |
| [`dev`](#dev) | Runs the development server |
| [`messages`](#messages) | Lists translation keys missing per locale |
| [`checker`](#checker) | Exports a self-contained copy of the shape checker |

Global flags: `--quiet` (only findings and errors), `--no-color` (also honoured through `NO_COLOR`), `--version`.
`dovetail <command> --help` prints that command's usage line.

## Exit codes and errors

Every command exits 0 on success and 2 when it cannot run. Commands that judge something (compile, check, fuse,
verify, contract diff) exit 1 when the thing judged fails. When a command cannot run it prints one line, a code and a
reason:

| Code | Meaning |
| --- | --- |
| `D-USE-001` | The command line is wrong (an unknown option, a missing argument) or a file named on it cannot be read |
| `D-CFG-001` | No `dovetail.yml` was found above the application directory, it or `ui/layout.yml` is not valid, or `embed_tag` is not a valid custom element name |
| `D-CON-001` | A contract file failed to load: a syntax error, a construct the DSL does not allow, or a value outside a statement's allowed set |
| `D-CON-002` | A contract failed validation; the C001 to C007 findings follow |
| `D-CON-003` | A breaking change kept the same contract version |
| `D-SHP-001` | The shape file is missing, is not JSON, or is not `dovetail.shape/v1` |
| `D-SHP-002` | No configured public key verifies the shape's signature, or the signature file is missing |
| `D-SHP-003` | A signature is required and no public key is configured, or a key file cannot be read |
| `D-CHK-001` | A panel file could not be read |
| `D-FUS-001` | A panel failed its checks |
| `D-FUS-002` | A route, shortcut or overlay name collides between panels |
| `D-FUS-003` | A consumed event's payload version is not emitted by its producer |
| `D-FUS-004` | The build failed |
| `D-TOK-001` | A theme is missing a token |
| `D-VER-001` | A composition journey failed |
| `D-VER-002` | The verifier cannot run: Ruby older than 3.0, no ferrum gem or Chrome, or the build never became ready |

## compile

```
dovetail compile <contract.rb>... --out <dir>
```

Loads and validates the contracts together (so cross-module references and events are checked), then writes, per
module: `schema/<module>.schema.json`, `schema-open/<module>.schema.json`, `types/<module>.d.ts`, `client/<module>.ts`, `model/<module>.model.json`, and,
for a contract with a panel, `shape/<module>.shape.json`, `shape/<module>.brief.md` and `registry/<module>.json`. It
prints each file written. Output is byte-identical for the same input on every supported Ruby.

`schema/` holds closed schemas: every object rejects properties it does not declare. `schema-open/` holds the same
schemas without `additionalProperties: false`, for a backend or another client that validates with a standard JSON
Schema validator. A compatible change adds an optional field and keeps the contract version, and only the open
schema accepts that field; see [Versioning contracts](../guides/versioning-contracts.md).

## check

```
dovetail check [<panel_dir>] --shape <file> [--require-signed] [--public-key <pem>]... [--profile strict|relaxed] [--changed <file>] [--format text|json]
dovetail check --require-signed <shape.json> [--changed <file>]
```

Checks every `.svelte`, `.ts` and `.js` file under the panel directory (the current directory when none is given)
against the shape. A positional argument ending in `.json` is the shape. Runs on Ruby 2.6.10 with the standard library
only.

| Option | Meaning |
| --- | --- |
| `--shape <file>` | The panel's shape |
| `--require-signed` | Refuse the shape unless a configured public key verifies its signature |
| `--public-key <pem>` | A public key to accept; repeatable. Otherwise `DOVETAIL_PUBLIC_KEYS`, then `public_keys` in `dovetail.yml` |
| `--profile strict\|relaxed` | Otherwise the shape's `rules_profile`, then `dovetail.yml`, then `strict` |
| `--changed <file>` | Report findings for this file only |
| `--format text\|json` | Text lines (default) or one JSON report |

Text output is one line per finding, `<file>:<line>:<column> <rule> <message> -> <fix>`, then a summary line. Exit 0
when there are no errors, 1 when there are errors.

## fuse

```
dovetail fuse --app <shell> [--panels <dir>...] [--out <dir>] [--verify] [--development] [--live <glob>...] [--embed]
```

`--app` is the shell directory (or any directory under the application); the nearest `dovetail.yml` above it
supplies the settings, and `--panels` defaults to its `panels` glob. Loads every contract and validates them together, checks every panel, type-checks each panel against its generated
types when Node is available, detects collisions between panels, generates the shell's registry, builds the
application with Vite. With `--verify` it also builds a development bundle and runs the composition journeys against
it. `--development` builds the main bundle as a development build. `--live <glob>` (repeatable) adds to the
configured `live` list; see [Live components](../guides/live-components.md). `--embed` also builds the application
as a custom element for other pages to host, as `embed: true` in `dovetail.yml` does; see
[Embedding](../guides/embedding.md). Settings come from the nearest
`dovetail.yml`; `node: false` there skips the type check and the build.

`--out` names the output directory, by default `out` in `dovetail.yml` (`.dovetail`):

| Path | Holds |
| --- | --- |
| `<out>/dist` | The production bundle, and nothing else: this is what you deploy |
| `<out>/fuse-report.json` | Every step: panels, contract versions, checks, collisions, type check, build, verify, duration |
| `<out>/verify-build` | The development bundle the verifier drives |
| `<out>/screenshots` | A screenshot per failed journey |
| `<out>/generated` | The compiled contracts (`$generated` in panel code) |
| `<out>/dist/vendor` | With `live`, the shared Svelte and `@dovetail/runtime` modules named in the import map |
| `<out>/dist/embed` | With `embed`, `<embed_tag>.js`, the application as one custom element |
| `<out>/prefetch.json` | For every route, the operations the shell prefetches when it is entered |

Exit 0 when fused, 1 when a check failed, 2 when the fuser could not run.

## verify

```
dovetail verify [<out>]
```

Serves `<out>/verify-build` (by default the nearest `dovetail.yml`'s `out`) on 127.0.0.1, drives it with headless Chrome through Ferrum, and runs every composition
journey: overlays, stacked overlays from two panels, routes, events, forced view states, unmount and remount leak
checks, slot bounds at narrow and wide widths, and deliberate crashes. Every overlay it opens must be in the
browser's top layer. When the fuse built the embed bundle, it also mounts the element in a deliberately hostile host
page and checks the application renders, its blocking overlays escape the host's clipping, and neither side's styles
reach the other. Every journey also fails on an uncaught
exception, a `console.error` or an unintended failed request. Failures are printed with their journey and panel, and
screenshots go to `<out>/screenshots`.

Needs Ruby 3.0 or newer, the `ferrum` gem (`bundle install --with verify`) and Chrome or Chromium (`BROWSER_PATH`
overrides the path). Exit 0 when every journey passes, 1 when one fails, 2 when it cannot run.

## contract

```
dovetail contract lint <contract.rb>...
dovetail contract diff <old.rb> <new.rb> [--format text|json]
dovetail contract compat <old.rb> <new.rb> [--format text|json]
dovetail contract show <contract.rb>
```

`lint` loads and validates each contract and prints `<file>: ok (<module> v<version>)`. `diff` classifies every
change as compatible or breaking and exits 1 with `D-CON-003` when a breaking change kept the version.
`compat` reports, for every operation and event of the old contract, whether the changes between the two versions
leave it compatible, and which breaking changes affect it when they do:

```console
$ dovetail contract compat v1/contract.rb contract.rb
operation findings: compatible
operation summary: breaking (removed field 'summary.margin')
event period_closed: compatible
```

A backend can use it to answer an older panel's call to an operation the change did not touch; see
[Versioning contracts](../guides/versioning-contracts.md). It exits 0 when it reports and 2 when it cannot run.
`show` prints the contract's model as JSON.

## brief

```
dovetail brief <shape.json>
```

Prints the brief. When the compiled `.brief.md` sits beside the shape it prints that; otherwise it renders a shorter
brief from the shape alone.

## sign

```
dovetail sign <shape.json> --private-key <pem>
```

Writes the signature beside the shape (`.json` becomes `.sig`) and prints its path. See
[Shape JSON](shape-json.md#signatures).

## new

```
dovetail new shell <name>
dovetail new panel <module>
```

`new shell` creates an application: `dovetail.yml`, and a `ui/` shell with its layout, the three themes, messages and
an `App.svelte`. `new panel`, run inside an application, creates `modules/<module>/contract.rb` and
`modules/<module>/panel/` with a working view, and adds the module to the layout's navigation, making it the home module
when there is none yet.

## rules

```
dovetail rules [<id>]
```

Lists every rule, or prints one in full. See the [rule catalogue](rules.md).

## dev

```
dovetail dev --app <shell> [--panels <dir>...] [--backend <url>] [--static] [--port <n>]
```

Serves the application with Vite on 127.0.0.1, recompiling contracts and re-checking each changed file as you work.
Findings appear in the terminal and in an in-page toolbar, which also switches each view between its states and can
crash a panel to try its fallback. Calls go to the development transport's fixtures, or to a real backend with
`--backend <url>`. Without Node, `--static` serves a page of checker findings only.

## messages

```
dovetail messages check [--app <shell>] [--panels <dir>...]
```

Lists, for each panel and locale, the message keys that are missing compared with `en-US`, one line per key.

## checker

```
dovetail checker export <dir>
```

Writes a self-contained copy of the shape checker to `<dir>`: `exe/dovetail`, the `lib/dovetail/**` files that
`dovetail check`, `dovetail brief`, `dovetail rules` and `dovetail --version` load, and `VERSION`. Nothing in the
export needs a gem or Node, and it runs on Ruby 2.6.10 and later with the standard library only. `<dir>` must not
exist, or must be empty; otherwise `D-USE-001` and exit 2. Prints `exported dovetail <version> checker to <dir>`.
Exit 0.
