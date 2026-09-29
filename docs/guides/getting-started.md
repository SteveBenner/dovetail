# Getting started

This guide builds a small application: a shell and one panel, checked, fused and verified. It assumes a checkout of
Dovetail set up as the [README](../../README.md) describes, with `dovetail` on your `PATH`.

## 1. Create the shell

```console
$ dovetail new shell myapp
created /home/you/myapp
$ cd myapp
```

This writes:

| Path | Holds |
| --- | --- |
| `dovetail.yml` | Where the contracts, panels, shell and output live, and which rules profile and keys to use |
| `ui/layout.yml` | The shell's slots, its navigation and its home module |
| `ui/App.svelte` | The shell's page: header, navigation, and the slot outlets |
| `ui/themes/*.json` | Three themes, apple-noir, apple-austere and tronwave; the shell uses the first |
| `ui/messages/en-US.json` | The shell's own strings |
| `.gitignore` | `node_modules` and `.dovetail/`, which the fuse creates |

## 2. Add a panel

```console
$ dovetail new panel finance
created /home/you/myapp/modules/finance
```

A panel is a module: `modules/finance/contract.rb` declares what it may do, and `modules/finance/panel/` holds its
code. `new panel` also adds Finance to the layout's navigation and, because the layout had no home module yet, makes
Finance the home: `/` now shows `/finance`.

The starter contract declares one operation, `items`, and one view that shows it:

```ruby
Dovetail.contract(:finance, version: 1) do
  type :item do
    field :label, String
  end
  operation :items, input: {}, output: list(:item)
  panel do
    slot :main, size: :main
    view :overview, data: :items, states: %i[loading empty error unavailable ready]
    capability :navigation
    route '/finance'
    tokens :default
  end
end
```

## 3. Compile the contract

```console
$ dovetail compile modules/*/contract.rb --out .dovetail/generated
```

Among the files it writes are the typed client the panel calls (`client/finance.ts`), the panel's shape
(`shape/finance.shape.json`) and its brief (`shape/finance.brief.md`). Read the brief: it is the plain-language
version of the contract, and it is what you give an AI agent that works on the panel.

## 4. Check the panel

```console
$ cd modules/finance/panel
$ dovetail check --shape ../../../.dovetail/generated/shape/finance.shape.json
dovetail check: 0 errors, 0 warnings
```

Try breaking a seam. Add a raw timer to `src/Panel.svelte`, on the line before `</script>`:

```ts
  setInterval(() => console.log('tick'), 1000);
```

```console
$ dovetail check --shape ../../../.dovetail/generated/shape/finance.shape.json
src/Panel.svelte:18:3 S-LIF-001 setInterval bypasses the lifecycle seam -> Use every, after or frame
dovetail check: 1 errors, 0 warnings
```

A raw interval would keep running after the panel unmounts. The fix names the primitive: `every(1000, tick)`, imported
from `@dovetail/runtime`, stops when the panel does. `dovetail rules S-LIF-001` explains the rule in full. Take the
timer out again before you go on.

## 5. Fuse and verify

```console
$ cd ../../..
$ dovetail fuse --app ui --verify
fused 1 panels
```

The fuse validates the contracts, checks every panel under `modules/*/panel` (the `panels` glob in `dovetail.yml`),
type-checks it, builds the application into `.dovetail/dist`, and then drives a development build in headless Chrome
through every composition journey. The report is `.dovetail/fuse-report.json`.

`.dovetail/dist` is a static site. Serve it behind your backend; the panel's client calls
`POST /api/v1/modules/finance/items`.

## 6. Work on it

```console
$ dovetail dev --app ui
```

The development server answers every operation from sample data built from the contract, re-checks each file you
save, and shows findings in the terminal and in the toolbar at the bottom left of the page. The toolbar can also force
a view into each of its states, and crash a panel so you can see its fallback card. Point it at a real backend with
`--backend http://127.0.0.1:3000`.

## Next

- [Writing a contract](writing-a-contract.md) covers types, operations, events and the panel's shape.
- [The nine seams](the-nine-seams.md) shows each primitive.
- [Working with an AI agent and a brief](working-with-an-ai-agent.md) sets up the check loop for an agent.
