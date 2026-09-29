# Writing a contract

A contract is the joint between a panel and everything around it. It says what data the panel can ask for, what it
can tell other panels, and which of the page's shared facilities it may use. Everything the contract does not grant,
the panel cannot do; everything inside the panel's slot is left to its author.

`dovetail new panel <module>` starts one at `modules/<module>/contract.rb`. This guide builds the finance contract from
the [worked example](../reference/contract-dsl.md) one decision at a time.

## 1. Name the module and its version

```ruby
Dovetail.contract(:finance, version: 1, description: "The business's margins and financial findings") do
end
```

The module id is permanent: it names the panel's routes, events, storage and messages. The description is the first
thing the brief says to the panel's author.

## 2. Describe the data

Declare the structures the panel will see, then the operations that return them.

```ruby
type :finding do
  field :id, Id
  field :title, String
  field :measure, Decimal
  field :unit, String
end

operation :findings, input: { period: String }, output: list(:finding), errors: [:unavailable]
```

Money and decimals travel as strings, so no amount is ever rounded by a float. Mark personal or confidential fields
`sensitive: true`; the brief then tells the author to show only what the view needs.

Mark an operation `idempotent: true` only when calling it twice is harmless. Only idempotent operations are retried
after a failure.

## 3. Declare where the panel renders

```ruby
panel do
  slot :main, size: :main, min_width: 480
  slot :summary, size: :tile
end
```

A slot is a region of the shell. `main` is the primary column, `aside` a side column, `tile` a card on the home page,
`strip` a narrow band, `full` the whole content area. The shell places each panel slot into the layout slot of the same
name, or the first layout slot of the same size.

## 4. Declare the views and their states

```ruby
view :dashboard, data: :findings
```

A view is a piece of the panel that shows one operation's data. Every view must render five states: loading, empty,
error, unavailable (the backend is down or not built yet) and ready. The runtime's `<States>` component supplies a
sensible rendering for any state the author leaves out, so the requirement costs nothing until the author wants
something better.

## 5. Grant the seams the panel needs

```ruby
capability :navigation
capability :overlay
capability :storage
route '/finance'
route '/finance/findings/:id'
overlay :finding_detail, kind: :drawer
storage_key :period, type: String, ttl_days: 30
```

Each capability opens one seam. Routes live in the module's namespace (`/finance`, or `/people-operations` for
`people_operations`). Overlays, storage keys and shortcuts are declared by name, so the fuse can check that two panels
never collide and the verifier can exercise each one. [The nine seams](the-nine-seams.md) describes them all.

## 6. Connect to other modules

```ruby
emits :finding_selected, payload: { finding_id: Id }
consumes :context, :settings_changed
```

Panels never import each other. They talk through events on a shared bus, and only the events their contracts declare.
The fuse checks that every consumed event is really emitted by its producer.

## 7. Check and compile

```console
$ dovetail contract lint modules/finance/contract.rb
modules/finance/contract.rb: ok (finance v1)
$ dovetail compile modules/*/contract.rb --out .dovetail/generated
```

Compiling writes, for each module:

| File | For |
| --- | --- |
| `schema/<module>.schema.json` | JSON Schema of every type, operation input and output, and event payload |
| `types/<module>.d.ts` | TypeScript types for the panel |
| `client/<module>.ts` | The typed data client the panel calls |
| `shape/<module>.shape.json` | The panel's shape, for the checker |
| `shape/<module>.brief.md` | The brief, for the author and their agent |
| `registry/<module>.json` | What the fuser needs to mount the panel |
| `model/<module>.model.json` | The contract model, for version checks |

A contract with no `panel` block (a module that only emits events, say) gets its schema, types, client and model, and
no shape, brief or registry entry.

## 8. Hand it out

Give the panel's author the shape and the brief. If authors work somewhere you do not control, sign the shape so their
checker can tell it was not edited ([Shape JSON](../reference/shape-json.md)). When the contract changes later, follow
[Versioning contracts](versioning-contracts.md).
