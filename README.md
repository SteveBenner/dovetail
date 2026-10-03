# Dovetail

Dovetail is a typed UI framework for fusing independently built frontend modules into one application that works the
first time.

Many people build panels apart, at the same time or not, against one shared backend. Each panel is cut to a contract,
the way each side of a dovetail joint is cut separately, and the pieces only go together when both sides match the
joint. A panel that passes its checks fuses with every other panel that passes theirs, with no coordination between
their authors.

Inside its slot a panel's author is free: layout, wording, charts, components and motion are theirs. Dovetail governs
only the effects that cross the slot's edge, the nine seams: overlays, navigation, storage, events, data, keyboard,
lifecycle, identity and layout.

## How it fits together

```
contract.rb --compile--> shape.json + brief.md --> the panel's author (and their AI agent)
                    \--> types, client, schema          |
                                                        v
                                     dovetail check  (every change, pure Ruby)
                                                        |
all panels + the shell ----------> dovetail fuse --verify --> one application
```

1. **Contract.** Each module declares its interface in a small Ruby DSL: its types, the operations its panel may call,
   the events it sends and hears, and the shape of its panel.
2. **Compile.** Dovetail turns each contract into JSON Schema, TypeScript types, a typed data client, the panel's
   shape and a plain-language brief.
3. **Check.** The shape checker reads the panel's Svelte, TypeScript and CSS and refuses anything that crosses the slot
   edge without its primitive. It runs on Ruby 2.6.10 with the standard library only, so it runs anywhere.
4. **Fuse.** The fuser checks every panel together, catches collisions between them, generates the shell's registry
   and builds the application.
5. **Verify.** The composition verifier drives the fused application in headless Chrome and exercises every seam
   across panels: overlays, routes, events, view states, unmounting, slot bounds and crashes.

## Requirements

| For | Needs |
| --- | --- |
| Contracts, compile, check, fuse without a build | Ruby 2.6.10 to 4.0.x, standard library only |
| Building the application, type checks, `dovetail dev` | Node 22 or newer |
| `dovetail verify` | Ruby 3.0 or newer, the `ferrum` gem, and Chrome or Chromium |

## Setting up a checkout

```console
$ git clone git@github.com:SteveBenner/dovetail.git
$ cd dovetail
$ (cd runtime && npm install && npm run build)
$ bundle config set --local path vendor/bundle
$ bundle install --with verify
$ ruby exe/dovetail --version
dovetail 0.3.2
```

Put `exe/` on your `PATH` or call `ruby path/to/dovetail/exe/dovetail`.

## A first application

```console
$ dovetail new shell myapp
$ cd myapp
$ dovetail new panel finance
$ dovetail fuse --app ui --verify
```

[Getting started](docs/guides/getting-started.md) walks through it.

## Documentation

Guides:

- [Getting started](docs/guides/getting-started.md)
- [Writing a contract](docs/guides/writing-a-contract.md)
- [The nine seams](docs/guides/the-nine-seams.md)
- [Working with an AI agent and a brief](docs/guides/working-with-an-ai-agent.md)
- [Fusing and verifying](docs/guides/fusing-and-verifying.md)
- [Live components](docs/guides/live-components.md)
- [Embedding in another web app](docs/guides/embedding.md)
- [Versioning contracts](docs/guides/versioning-contracts.md)

Reference:

- [Contract DSL](docs/reference/contract-dsl.md)
- [Shape JSON](docs/reference/shape-json.md)
- [Rule catalogue](docs/reference/rules.md)
- [Runtime API](docs/reference/runtime-api.md)
- [CLI](docs/reference/cli.md)

The full specification is [specs/dovetail.spec.yml](specs/dovetail.spec.yml).

## Repository layout

| Path | Holds |
| --- | --- |
| `exe/dovetail` | The command line |
| `lib/dovetail/contract/` | The DSL, the contract model and its validation |
| `lib/dovetail/compiler/` | The JSON Schema, TypeScript, client, shape, brief and registry emitters |
| `lib/dovetail/shape/` | The shape checker and its rule catalogue |
| `bin/components-table` | Regenerates `lib/dovetail/shape/components.yml`, the table of runtime component props the shape checker reads; `--check` exits 1 when it is stale |
| `lib/dovetail/tokens/` | The token vocabulary and the class grammar |
| `lib/dovetail/fuse/`, `lib/dovetail/verify/` | The fuser and the composition verifier |
| `runtime/` | `@dovetail/runtime`, the Svelte 5 and TypeScript browser library |
| `templates/` | The starter shell and panel |
| `docs/` | Guides and reference |
| `specs/` | The specification and the implementation blueprint |

## Status

0.1.0 is the first release. Grokit is its first consumer: ten teams each build one module's panel, and Reach runs
`dovetail check` on every change a student makes. Dovetail knows nothing about Grokit's domain.

## Licence

The intended licence is AGPL-3.0-only, matching Grokit, and `dovetail.gemspec` and `runtime/package.json` declare it.
It is not final: whether the library should take a permissive licence so other projects can adopt it is an open
question in the specification, and no licence file ships until that is settled.
