# Runtime API

`@dovetail/runtime` is the browser library: the shell host, the panel host with its error boundary, one primitive per
seam, and a small set of components. It is written in TypeScript for Svelte 5.

| Entry point | Holds |
| --- | --- |
| `@dovetail/runtime` | The primitives, the shell components, the components, and the types |
| `@dovetail/runtime/components` | The components on their own |
| `@dovetail/runtime/icons` | The Phosphor icon set, for `IconButton` and your own markup |

Inside a panel, the fuse binds `@dovetail/runtime` to the panel's module, so every primitive knows which panel called
it and checks the call against that panel's contract. Primitives that belong to a panel (everything in the seam
sections below except `toast`) throw `Dovetail: <name> was called outside a panel` when shell code calls them.

## Shell

### `<DovetailShell registry theme locale transport onPanelError routing initialPath versionPolicy prefetch>`

The root host. It lays out the shell, mounts each registered panel into its slots inside an error boundary, and owns
the overlay host, the event bus, the router, the shortcut registry and the toast queue. It applies the theme's tokens
as CSS custom properties on its root element.

| Prop | Type |
| --- | --- |
| `registry` | The generated registry (`import registry from '$registry'`) |
| `theme` | A theme: `{ id, name, color_scheme, tokens }` |
| `locale` | A locale code, default `en-US` |
| `transport` | `createHttpTransport(...)` or `createDevelopmentTransport()` |
| `onPanelError` | `(module, error) => void`, called when a panel's boundary catches an error |
| `routing` | `history` (default): the application owns the page's path. `memory`: it keeps its own route and never touches the URL |
| `initialPath` | The first route in `memory` routing, default `/` |
| `versionPolicy` | `strict` (default) or `tolerant`; see [Data](#data) |
| `prefetch` | Default `true`; see [Data](#data) |

When the application runs inside its embed element, the element's attributes override `theme`, `locale`, `routing`,
`initialPath`, `versionPolicy`, `prefetch` and the transport's base URL; see [Embedding](../guides/embedding.md).

### `<Slot name>`

A slot outlet in the shell's layout. It renders the panels placed in that slot, marks each with
`data-dovetail-panel` and `data-slot`, and is an inline-size container, so panels can adapt to its width.

### `useNavigation()`

For shell code: the layout's navigation entries, each with its `label`, `href` and `active` state.

### Transports

```ts
createHttpTransport({ baseUrl, disabled, disabledModules, maxInFlightPerModule, ratePerSecond, burst, breaker })
createDevelopmentTransport()
```

The HTTP transport posts to `/api/v1/modules/<module>/<operation>` and listens for server events on `/api/v1/events`
(see [the wire protocol](#wire-protocol)). Its defaults: six requests in flight per module, ten a second with bursts
of twenty, the circuit opened for 30 seconds after five consecutive failures, idempotent operations retried at most
twice with full-jitter backoff (250 ms base, 2 s cap), and `Retry-After` honoured on 429 and 503. `disabled: true`
turns off every call and `disabledModules` turns off named modules; both answer `unavailable` without a request.

The development transport answers every operation from fixtures built from the contract's schemas, and the
development toolbar and verifier use it to force each view into each state.

## Views

### `<View name status>`

The root of a declared view. `status` is `loading`, `empty`, `error`, `unavailable`, `ready` or `not_built`;
`not_built` shows the shell's standard not-built card.

### `<States>`

Renders the one state the enclosing View's `status` names. Each state is a component or a snippet of the same name;
a state left out gets the runtime's default.

| Prop | Component receives | Snippet receives | Default |
| --- | --- | --- | --- |
| `loading` | nothing | nothing | `Skeleton` |
| `empty` | nothing | nothing | `EmptyState` |
| `error` | `body`, `retry` | `(failure, retry)` | `ErrorState` |
| `unavailable` | `retry`, `retry_after_s` | `(failure, retry)` | `UnavailableState` |
| `ready` | `data` | `(data)` | nothing |
| `data` | the view data, given to `ready` | | |
| `failure` | the error value `{ code, message, retry_after_s? }` | | |
| `retry` | `() => void`, given to `error` and `unavailable` | | |

```svelte
<View name="dashboard" {status}>
  <States loading={Skeleton} error={ErrorState} failure={result?.error} retry={load}>
    {#snippet empty()}
      <EmptyState title="No findings for this period" />
    {/snippet}
    {#snippet ready()}
      <FindingGrid findings={result.data} />
    {/snippet}
  </States>
</View>
```

### `useProps()`, `useContractVersion()`

The panel's props as declared in its contract, and its contract version.

## Overlay

```ts
openOverlay(name, component, props): OverlayHandle
toast(message, { tone?: 'info' | 'success' | 'warning' | 'danger', duration_ms?: number }): void
```

`OverlayHandle` has `close(result?)`, `update(props)` and `closed`, a promise of the result. `<Overlay name bind:open
anchor>` is the declarative form; `anchor` places popovers and menus. Opening a name the contract does not declare
is `D-RUN-001` in development.

Overlays render in the browser's top layer, so nothing in the page, and nothing in a page hosting the application,
can clip or cover them. A blocking overlay is a native modal `dialog`: the browser makes the rest of the page inert
and draws the scrim as its backdrop. Every other overlay, the toast region and the tooltip layer are manual popovers.
Escape closes the topmost dismissible overlay, once per press.

## Navigation

```ts
navigate(route, params?, { replace?: boolean }?): void
link(route, params?): string
useRoute(): { pattern, params, query }
```

`route` is one of the panel's declared patterns, such as `'/finance/findings/:id'`, with its parameters in `params`.
`link` returns an href for an anchor; the router handles the click. `useRoute` is reactive and reads query keys from
the panel's own namespace. An undeclared route is `D-RUN-002` in development.

## Storage

```ts
store(key): { get(): Value | undefined; set(value): void; clear(): void }
```

Keys are stored as `dovetail:<module>:v<version>:<key>`. Expired values read as `undefined`. A `set` beyond the panel's
256 KB throws `StorageQuotaExceeded` (`D-RUN-005`) and keeps the old value; in development a value that does not match
its declared type throws `D-RUN-004`.

## Events

```ts
emit(event, payload): void
on(event, handler): () => void
```

`event` is a qualified id such as `'finance.finding_selected'`. Delivery is synchronous and in subscription order.
`on` unsubscribes automatically when the panel unmounts and also returns an unsubscribe function. An undeclared event
is `D-RUN-003` and, in development, a payload that does not match its schema is `D-RUN-004`.

## Data

The generated client, one per module:

```ts
import { finance } from '$generated/client/finance';
const result = await finance.findings({ period });
```

Each function returns a `Result`: `{ ok: true, data, contract_version }` or `{ ok: false, error: { code, message,
path?, retry_after_s? } }`. It never throws for an expected failure. The codes every call can return are
`invalid_input`, `contract_violation`, `not_found`, `unavailable`, `not_built`, `contract_version_mismatch`,
`rate_limited` and `internal`, plus the operation's own `errors`.

A response at another contract version than the panel's is accepted only when it is ok and its data validates
against the panel's own output schema, and then only when the server declared the negotiation (`negotiated` in the
response) or the shell's `versionPolicy` is `tolerant`. The result then carries `negotiated: { requested, served }`.
Otherwise it is a `contract_version_mismatch` error, with the server's `supported_versions` when it sent them. The
same policy applies to server events at another version. In development, each accepted response or event at another
version logs `D-RUN-008` once. See [Versioning contracts](../guides/versioning-contracts.md).

When a route is entered, the shell starts the data operation of every view of every panel placed on it, when that
operation takes no input and is idempotent, all in parallel. The panel's own first call to it within five seconds
takes that result instead of calling again. Every call still goes through the transport's rate limits and circuit
breaker. `prefetch={false}` on the shell turns this off.

## Keyboard

```ts
shortcut(keys, handler): () => void
```

`keys` is a declared shortcut such as `'mod+k'` or `'shift+?'`; `mod` is Cmd on macOS and Ctrl elsewhere.

## Lifecycle

```ts
every(ms, fn): () => void
after(ms, fn): () => void
frame((t) => void): () => void
subscribe(source, fn): () => void
```

Each returns a cancel function and is cancelled when the panel unmounts. `every` pauses while the tab is hidden.
`subscribe` takes a Svelte store or an async iterable.

## Identity

```ts
useId(name): string
```

Returns `dt-<module>-<instance>-<name>`, stable for the panel instance and unique on the page.

## Translations and formatting

```ts
t(key, params?): string
formatNumber(value, options?)
formatMoney(money)
formatDate(value, 'short' | 'medium' | 'long')
formatPercent(value)
```

Messages live in `messages/<locale>.json` beside each panel and the shell, in ICU MessageFormat (plural and select
supported), with keys prefixed by the module id (`finance.margin.title`). A missing key falls back to `en-US`, then to
the key itself, and is logged once in development. Formatting always uses the shell's locale; panels never build
`Intl` objects themselves. `t` and the formatters also work in shell code.

## Components

| Component | Props |
| --- | --- |
| `Button` | `variant: primary \| secondary \| ghost \| danger`, `size: sm \| md`, `disabled`, `reason` (shown when disabled), `loading`, `onclick` |
| `IconButton` | `label` (required, for screen readers), `icon`, `variant: secondary \| ghost`, `onclick` |
| `Field` | `label`, `hint`, `error`, `required`; wires them to the control inside it |
| `TextInput` | `bind:value`, `placeholder`, `maxlength` |
| `NumberInput` | `bind:value` (a Decimal string), `min`, `max`, `step`; parses with the locale's separators |
| `Select` | `bind:value`, `options: { value, label }[]` |
| `Checkbox` | `bind:checked`, `label` |
| `Switch` | `bind:checked`, `label` |
| `Tabs` | `tabs: { id, label }[]`, `bind:active` |
| `Table` | `columns: { key, label, align, format }[]`, `rows`, `bind:sort`, `empty`; virtualised beyond 200 rows, keyboard navigable |
| `Card` | `title`, `tone: default \| accent \| warning \| danger` |
| `Badge` | `tone: neutral \| success \| warning \| danger \| info` |
| `Stat` | `label`, `value`, `unit`, `trend: up \| down \| flat` |
| `Skeleton` | `lines`, `shape: text \| block \| table` |
| `EmptyState` | `title`, `body`, `action: { label, onclick }` |
| `ErrorState` | `title`, `body`, `retry` |
| `UnavailableState` | `what`, `retry`, `retry_after_s` (counts down, then retries) |
| `Tooltip` | `text` |

Every component styles itself from the theme's tokens, so it looks right in every theme.

## Wire protocol

A request is `POST /api/v1/modules/<module>/<operation>` with the input as JSON and these headers:

| Header | Value |
| --- | --- |
| `Content-Type` | `application/json` |
| `X-Dovetail-Contract` | `<module>@<version>` |
| `X-Request-Id` | a UUID |

A response is `{ "status": "ok", "data": ..., "contract_version": N }` or `{ "status": "error", "errors": [{ "code",
"message", "path" }], "contract_version": N }`. A server answering an older version's call that `dovetail contract
compat` reports compatible adds `"negotiated": { "requested": M, "served": N }` to the ok response. A
`contract_version_mismatch` error may add `"supported_versions": [...]`, the versions the server can answer that
operation for.

Server events arrive as Server-Sent Events from `/api/v1/events`. Each message has an `id`, an `event` field naming
the event id (`<module>.<event>`), and `data` holding `{ "payload": ..., "contract_version": N }`.

## Development hooks

Development builds expose `window.__dovetail`, which the development toolbar and `dovetail verify` drive: the mounted
panels, open overlays, route and event logs, forced view states, mount and unmount, leak counters, deliberate crashes,
slot rectangles and transport statistics, where focus sits inside an overlay (`focusInside(id)`) and which module owns
the home route that tile slots render on (`homeModule()`), and whether an overlay is in the top layer
(`overlays.topLayer(id)`, answering `modal`, `popover` or `none`). Production builds do not include it.
