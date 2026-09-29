# Contract DSL

A contract declares one module's interface: its types, the operations its panel may call, the events it sends and
hears, and the shape of its panel. It is a Ruby file, conventionally `modules/<module>/contract.rb`.

```ruby
Dovetail.contract(:finance, version: 2, description: "The business's margins and financial findings") do
  type :margin do
    field :gross_margin_pct, Decimal, nullable: true
    field :status, String, enum: %w[ok undefined]
  end
  operation :margin, input: { revenue: Money, cogs: Money }, output: :margin, errors: [:insufficient_input]
  emits :finding_selected, payload: { finding_id: Id }
  consumes :context, :settings_changed
  panel do
    slot :main, size: :main, min_width: 480
    slot :summary, size: :tile
    view :dashboard, data: :margin
    overlay :finding_detail, kind: :drawer
    capability :navigation
    capability :overlay
    route '/finance'
    route '/finance/findings/:id'
    tokens :default
  end
end
```

## How a contract file is loaded

A contract file is data written as Ruby, not a program. Before anything runs, Dovetail parses the file with Ripper and
accepts it only if every construct is one the DSL uses: the statements below, the `Dovetail` constant, the scalar type
names, literals, arrays, hashes, blocks, and an optional `require 'dovetail'`. Anything else (a method definition,
another constant, string interpolation, file or network access) fails with `D-CON-001` before it can run. Only then
is the file evaluated, in an empty context.

A misspelled option or a value outside a statement's allowed set also fails with `D-CON-001`, naming the statement,
the value and the allowed values.

Every name is a lower snake case symbol. Operation and event ids are qualified by the module id automatically, so
`emits :finding_selected` in the `finance` contract is the event `finance.finding_selected`.

## Contract

```ruby
Dovetail.contract(:module_id, version: Integer, description: String) { ... }
```

A file declares exactly one contract. `version` starts at 1 and increases whenever a breaking change is made (see
[Versioning contracts](../guides/versioning-contracts.md)). `description` is optional; the brief uses it for "What
your panel is for".

## Types

```ruby
type :name do
  field :field_name, Type, **options
end
```

A named structure used by operations, events, storage keys and props.

### Scalars

| Scalar | On the wire | TypeScript |
| --- | --- | --- |
| `String` | string | `string` |
| `Integer` | number | `number` |
| `Decimal` | string, so no precision is lost | `Decimal` (a branded string) |
| `Boolean` | boolean | `boolean` |
| `Date` | ISO 8601 date string | `IsoDate` |
| `DateTime` | ISO 8601 date-time string | `IsoDateTime` |
| `Id` | string | `Id` |
| `Money` | `{ "amount": Decimal, "currency": currency code }` | `{ amount: Decimal; currency: CurrencyCode }` |
| `Percent` | Decimal string | `Decimal` |
| `Url` | string | `string` |
| `Email` | string | `string` |

### Composites

| Form | Meaning | TypeScript |
| --- | --- | --- |
| `list(Type)` | An ordered list | `readonly T[]` |
| `map(String, Type)` | String keys to values | `Readonly<Record<string, T>>` |
| `one_of(:a, :b)` | Exactly one of several named types | a discriminated union on a `kind` field |
| `ref(:other_module, :type)` | A type from another module's contract | that module's type |
| `:type_name` | A type declared in this contract | the named type |
| `{ field: Type, ... }` | An inline structure (operation inputs and event payloads) | an object type |

### Field options

| Option | Default | Meaning |
| --- | --- | --- |
| `required:` | `true` | The field must be present. |
| `nullable:` | `false` | The field may be `null`. |
| `default:` | none | Used when the field is absent; implies `required: false`. |
| `description:` | none | Copied into the JSON Schema, the TypeScript doc strings and the brief. |
| `enum:` | none | The allowed values. |
| `min:` | none | Minimum for numbers, minimum length for strings and lists. |
| `max:` | none | Maximum for numbers, maximum length for strings and lists. |
| `pattern:` | none | A regular expression strings must match. |
| `format:` | none | One of `:iso_date`, `:iso_datetime`, `:currency_code`, `:locale`, `:country_code`, `:sha256`. |
| `sensitive:` | `false` | Personal or confidential data. The brief tells the author to show only what the view needs and never to copy it into messages or storage. |
| `deprecated:` | none | A string saying what replaces the field; the field stays for compatibility. |

## Operations

```ruby
operation :name, input: :type_or_inline, output: :type, errors: [:code], timeout_ms: 10000, idempotent: false,
                 description: String
```

A backend function the panel reaches through the generated client. `input` is a named type or an inline hash; an
operation that takes nothing uses `input: {}` and its client function takes no argument. `errors` lists the
operation's own error codes, added to the common ones every call can return (`invalid_input`, `contract_violation`,
`not_found`, `unavailable`, `not_built`, `contract_version_mismatch`, `rate_limited`, `internal`). `timeout_ms`
defaults to 10000. Only an `idempotent: true` operation is ever retried.

## Events

```ruby
emits :event_name, payload: { field: Type }, description: String
consumes :other_module, :event_name
```

`emits` declares an event this module publishes on the bus. `consumes` subscribes this panel to another module's
event; the fuse checks that the producer really emits it (C003).

## Dependencies

```ruby
depends_on :other_module, version: '>= 2'
```

A contract this one relies on, with a version requirement.

## Panel

```ruby
panel do
  ...
end
```

Opens the shape declaration: everything that governs the panel's UI code.

| Statement | Form | Meaning |
| --- | --- | --- |
| `slot` | `slot :name, size: :full \| :main \| :aside \| :tile \| :strip, min_width: Integer, max_width: Integer, description: String` | A region of the shell the panel renders into. |
| `view` | `view :name, data: :operation, states: %i[loading empty error unavailable ready], description: String` | A data view. The five states are required; `states` may add more. |
| `capability` | `capability :overlay \| :navigation \| :storage \| :keyboard \| :lifecycle` | A seam the panel uses. An undeclared seam may not be used. |
| `route` | `route '/path/:param'` | A route in the panel's namespace. |
| `prop` | `prop :name, Type, required: true` | A value the shell passes to the panel. |
| `tokens` | `tokens :default` or `tokens %i[color space radius type weight shadow motion layout]` | The token families the panel may style with. `:default` grants all of them. |
| `storage_key` | `storage_key :name, type: Type, ttl_days: Integer` | A namespaced key the panel may keep in the browser. |
| `shortcut` | `shortcut 'mod+k', action: :name, scope: :panel \| :view` | A keyboard shortcut. `mod` is Cmd on macOS and Ctrl elsewhere. |
| `overlay` | `overlay :name, kind: :modal \| :drawer \| :popover \| :menu \| :toast, dismissible: true, blocking: Boolean, description: String` | An overlay the panel may open. |

`blocking` defaults to `true` for modals and drawers and to `false` for popovers, menus and toasts. `dismissible`
defaults to `true`.

### Routes and the module namespace

Every route is the module's namespace or starts with it followed by `/`. The namespace is `/` plus the module id with
`_` written as `-`, so `people_operations` owns `/people-operations` and `/people-operations/...`. No two of a
contract's routes may match the same path. The shell owns `/`, which shows the first route of the layout's home module.

## Validation

`dovetail compile` and `dovetail contract lint` check every contract, and `dovetail fuse` checks them all together.

| Rule | Checks |
| --- | --- |
| C001 | Every referenced type exists. |
| C002 | Operation, event and type names are unique within the contract. |
| C003 | A consumed event exists in the named module's contract at a compatible version. |
| C004 | Every view's data operation exists and every view lists all five required states. |
| C005 | Every route is in the module's namespace, and no two routes can match the same path. |
| C006 | A storage key, shortcut or overlay requires the matching capability. |
| C007 | The contract version increases when a breaking change is made. |

A contract that fails validation stops the compile with `D-CON-002` and the findings listed.
