# The nine seams

Inside its slot a panel is free: its markup, layout, wording, charts, components and motion are its author's. What
Dovetail governs are the effects that cross the slot's edge, because those are the ones that make one panel break
another. It names nine of them, the seams. Each seam has one primitive in `@dovetail/runtime`, and each has checker
rules that refuse the direct route around it.

| Seam | Covers | Use | Instead of | Rules |
| --- | --- | --- | --- | --- |
| Overlay | modals, drawers, popovers, menus, toasts | `openOverlay`, `<Overlay>`, `toast` | fixed layers, `showModal`, locking body scroll | S-OVL-001 to 003 |
| Navigation | routes and URL state | `navigate`, `link`, `useRoute` | `window.location`, `history` | S-NAV-001, 002 |
| Storage | remembering things in the browser | `store(key)` | `localStorage`, `sessionStorage`, `indexedDB`, cookies | S-STO-001 |
| Events | talking to other panels | `emit`, `on` | imports from other panels, `postMessage`, window events | S-EVT-001 to 003 |
| Data | reaching the backend | the generated client | `fetch`, `XMLHttpRequest`, `EventSource`, `WebSocket`, `sendBeacon` | S-DAT-001, 002 |
| Keyboard | shortcuts | `shortcut` | `keydown` listeners on window or document | S-KEY-001 |
| Lifecycle | timers, frames, subscriptions | `every`, `after`, `frame`, `subscribe` | `setInterval`, `setTimeout`, `requestAnimationFrame`, `requestIdleCallback` | S-LIF-001 |
| Identity | element ids and ARIA references | `useId` | literal `id` attributes | S-ID-001 |
| Layout | position and size | the slot and container queries | `position: fixed`, viewport units, `z-index`, reaching the page through `document` | S-LAY-001 to 004 |

A panel may use a seam only when its contract declares it. Navigation, overlay, storage, keyboard and lifecycle are
granted with `capability`; data comes with the operations the contract lists, and events with `emits` and `consumes`.

## Overlay

```svelte
<script lang="ts">
  import { openOverlay } from '@dovetail/runtime';
  import FindingDetail from './FindingDetail.svelte';
</script>

<button onclick={() => openOverlay('finding_detail', FindingDetail, { id })}>Details</button>
```

The shell owns one overlay host for the whole page. It keeps a single stacking order, traps focus in a blocking
overlay and returns it to the opener, locks scroll only while at least one blocking overlay is open (from any panel),
closes the top dismissible overlay on Escape, and closes a panel's overlays when the panel unmounts. `toast(message,
{ tone })` queues a toast in a queue all panels share, three visible at a time.

`openOverlay` returns a handle with `close(result)`, `update(props)` and a `closed` promise. `<Overlay name bind:open>`
is the declarative form.

## Navigation

```ts
navigate('/finance/findings/:id', { id: finding.id });
const href = link('/finance');
const route = useRoute();
```

A panel navigates only among its own declared routes. Query parameters are namespaced by module, so two panels can
both use `?page=` without clashing, and back and forward work across panels. To send the user to another panel, emit
an event that panel consumes.

## Storage

```ts
const period = store('period');
period.set('this_month');
period.get();
period.clear();
```

Keys are namespaced by module and contract version, values are checked against their declared type, and a key's
`ttl_days` expires it. Each panel may keep 256 KB; a `set` beyond that fails with `StorageQuotaExceeded` and keeps the
old value. When the browser blocks storage, values are kept in memory for the page's lifetime instead.

## Events

```ts
emit('finance.finding_selected', { finding_id: id });
on('context.settings_changed', (settings) => reload(settings));
```

Delivery is synchronous, in subscription order, and only to panels whose contracts consume the event. A handler that
throws sends its own panel to its fallback card; the other handlers still run. Subscriptions end when the panel
unmounts. There is no replay: a panel that mounts later reads current state through an operation.

## Data

```ts
import { finance } from '$generated/client/finance';

const result = await finance.findings({ period });
if (result.ok) show(result.data);
else if (result.error.code === 'unavailable') showUnavailable();
```

Every call returns a result, `ok` with data or an error with a code, and never throws for an expected failure. The
transport applies the contract's timeout, retries idempotent operations at most twice with jittered backoff, honours
`Retry-After`, caps each module at six requests in flight and ten a second, and stops calling a module for 30 seconds
after five failures in a row.

## Keyboard

```ts
shortcut('mod+k', () => openSearch());
```

`mod` is Cmd on macOS and Ctrl elsewhere. The fuse refuses two panels binding the same keys in overlapping scopes. A
shortcut without `mod` is ignored while the user is typing in a field, and every shortcut is inactive while another
panel's blocking overlay is open.

## Lifecycle

```ts
every(30_000, refresh);
after(500, hideHint);
frame((t) => draw(t));
subscribe(source, (value) => update(value));
```

Everything started through these stops when the panel unmounts, so no work outlives its panel. `every` pauses while the
tab is hidden.

## Identity

```svelte
<script lang="ts">
  import { useId } from '@dovetail/runtime';
  const hint = useId('period-hint');
</script>

<select aria-describedby={hint}>...</select>
<p id={hint}>Choose a reporting period.</p>
```

`useId(name)` returns an id unique to this panel instance, so two panels (or two copies of one) never share an id.

## Layout

A panel renders into its slot and nowhere else. Every slot is an inline-size container, so a panel adapts to the width
it is given with the container variants `@sm`, `@md`, `@lg` and `@xl` (320, 480, 640 and 800 px of slot width) rather
than to the window. Heading levels start where the slot says: h2 in a main or full slot, h3 elsewhere. Landmarks such as
`main` and `navigation` belong to the shell.

## Styling with tokens

Colour, space, radius, type, weight, shadow and motion come from the theme's tokens, as utility classes (`bg-surface-2`,
`text-text-dim`, `p-4`, `rounded-lg`) or as `var(--token)` in a component's style block. Because a panel never names a
colour, it looks right in every theme the application ships. A class the component's own style block defines is local
to the component and free to name.
