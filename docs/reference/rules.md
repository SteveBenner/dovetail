# Rule catalogue

`dovetail check` reports each finding with one of these rule ids. Rule ids are stable across Dovetail versions.
`dovetail rules` lists them and `dovetail rules <id>` prints one.

Severity is the strict profile's. Under the relaxed profile S-LAY-003, S-HTML-002, S-CSS-005 are warnings instead of errors;
every other rule keeps its severity. A rule that fires on a name the checker cannot read, because it is not a
string literal, reports the same id as a warning saying the name cannot be checked.

Two rules have a scope worth knowing. S-CSS-001 does not apply to a class that the component's own style block
defines: that class is local to the component, and the style block itself is still held to S-CSS-003. S-STATE-001
is satisfied by a View that contains States, because States renders a default for every state the panel leaves out.

| Rule | Seam | Severity | Finds |
| --- | --- | --- | --- |
| [S-OVL-001](#s-ovl-001) | Overlay | error | position: fixed on an element, or a class or style producing it |
| [S-OVL-002](#s-ovl-002) | Overlay | error | dialog.showModal(), document.body.style.overflow, or body class toggles |
| [S-OVL-003](#s-ovl-003) | Overlay | error | An overlay opened by a name the shape does not declare |
| [S-NAV-001](#s-nav-001) | Navigation | error | window.location, history.pushState, history.replaceState |
| [S-NAV-002](#s-nav-002) | Navigation | error | A route outside the panel's declared patterns |
| [S-STO-001](#s-sto-001) | Storage | error | localStorage, sessionStorage, indexedDB, document.cookie |
| [S-EVT-001](#s-evt-001) | Events | error | An import from another module's panel or stores |
| [S-EVT-002](#s-evt-002) | Events | error | emit or on with an event the shape does not declare |
| [S-EVT-003](#s-evt-003) | Events | error | window.postMessage, dispatchEvent on window or document |
| [S-DAT-001](#s-dat-001) | Data | error | fetch, XMLHttpRequest, EventSource, WebSocket, navigator.sendBeacon |
| [S-DAT-002](#s-dat-002) | Data | error | A client call to an operation the shape does not list |
| [S-KEY-001](#s-key-001) | Keyboard | error | keydown, keyup or keypress listeners on window or document (including svelte:window and svelte:document) |
| [S-LIF-001](#s-lif-001) | Lifecycle | error | setInterval, setTimeout, requestAnimationFrame, requestIdleCallback |
| [S-ID-001](#s-id-001) | Identity | error | A literal id attribute or literal ARIA id reference |
| [S-LAY-001](#s-lay-001) | Layout | error | vw, vh, dvh, svh, lvh units used for size |
| [S-LAY-002](#s-lay-002) | Layout | error | z-index outside the overlay host |
| [S-LAY-003](#s-lay-003) | Layout | error | Negative margins on the panel's root element |
| [S-LAY-004](#s-lay-004) | Layout | error | Reaching the page outside the slot through document - querySelector, querySelectorAll, getElementById, getElementsByClassName, getElementsByTagName, getElementsByName, elementFromPoint, elementsFromPoint, and inserting into or removing from document.body or document.documentElement |
| [S-CSS-001](#s-css-001) | Tokens | error | A class outside the token vocabulary |
| [S-CSS-002](#s-css-002) | Tokens | error | An arbitrary value class such as bg-[#123456] or p-[13px] |
| [S-CSS-003](#s-css-003) | Tokens | error | A literal colour, length or shadow in a style block or style attribute (hex, rgb, hsl, px other than 0 and 1px borders) |
| [S-CSS-004](#s-css-004) | Tokens | error | :global selectors and element selectors that reach outside the component |
| [S-CSS-005](#s-css-005) | Tokens | error | A class attribute built from a non-literal expression the checker cannot resolve |
| [S-HTML-001](#s-html-001) | Layout | error | Landmark roles banner, navigation, contentinfo or main in a panel |
| [S-HTML-002](#s-html-002) | Layout | error | A heading above the slot's starting level |
| [S-HTML-003](#s-html-003) | Layout | error | A form control without a label |
| [S-HTML-004](#s-html-004) | Security | warning | Any {@html} block |
| [S-I18N-001](#s-i18n-001) | Messages | warning | A message key without the module prefix |
| [S-STATE-001](#s-state-001) | View states | error | A declared view that does not render one of its required states |
| [S-DYN-001](#s-dyn-001) | Any seam | error | Computed access to globals (globalThis[...], window[...]) and eval, Function, new Function |
| [S-DEP-001](#s-dep-001) | Any seam | error | An import of a package outside the allowed list (@dovetail/runtime, svelte, the generated types and client, the panel's own files) |
| [S-PARSE-001](#s-parse-001) | Any seam | warning | A construct the parser does not recognise |

## S-OVL-001

Seam: Overlay. Severity: error.

**Finds.** position: fixed on an element, or a class or style producing it

**Fix.** Open the content with openOverlay or <Overlay>

**Why it breaks fusion.** A fixed layer from one panel covers the others and escapes the shared stacking order, so another panel's modal can open underneath it.

Violation:

```
<div class="fixed inset-0 bg-surface">...</div>
```

Compliant:

```
<button onclick={() => openOverlay('finding_detail', FindingDetail, { id })}>Details</button>
```

## S-OVL-002

Seam: Overlay. Severity: error.

**Finds.** dialog.showModal(), document.body.style.overflow, or body class toggles

**Fix.** Use the overlay host, which owns focus and scroll lock

**Why it breaks fusion.** Two panels each locking body scroll leave the page frozen when one of them forgets to unlock.

Violation:

```
dialog.showModal(); document.body.style.overflow = 'hidden';
```

Compliant:

```
const h = openOverlay('confirm', Confirm, { message }); await h.closed;
```

## S-OVL-003

Seam: Overlay. Severity: error.

**Finds.** An overlay opened by a name the shape does not declare

**Fix.** Declare the overlay in the contract or use a declared one

**Why it breaks fusion.** The fuser registers overlays by name so the verifier can exercise them; an undeclared overlay is never tested.

Violation:

```
openOverlay('quick_edit', QuickEdit, {})  (quick_edit not in the shape)
```

Compliant:

```
overlay :quick_edit, kind: :modal, dismissible: true  (declared in the contract) then openOverlay('quick_edit', ...)
```

## S-NAV-001

Seam: Navigation. Severity: error.

**Finds.** window.location, history.pushState, history.replaceState

**Fix.** Use navigate or link

**Why it breaks fusion.** Writing the location directly bypasses route ownership and breaks back-button history for other panels.

Violation:

```
window.location.href = '/finance/findings/' + id;
```

Compliant:

```
navigate('/finance/findings/:id', { id });
```

## S-NAV-002

Seam: Navigation. Severity: error.

**Finds.** A route outside the panel's declared patterns

**Fix.** Declare the route or use a shell link

**Why it breaks fusion.** A panel linking into another panel's internal route breaks when that panel renames a route.

Violation:

```
navigate('/records/browse');  (from the Finance panel)
```

Compliant:

```
emit('finance.record_requested', { record_id });  (Records decides where to go)
```

## S-STO-001

Seam: Storage. Severity: error.

**Finds.** localStorage, sessionStorage, indexedDB, document.cookie

**Fix.** Use store(key) with a declared storage key

**Why it breaks fusion.** Unnamespaced keys from two panels overwrite each other.

Violation:

```
localStorage.setItem('filters', JSON.stringify(filters));
```

Compliant:

```
store('filters').set(filters);  (storage_key :filters declared)
```

## S-EVT-001

Seam: Events. Severity: error.

**Finds.** An import from another module's panel or stores

**Fix.** Communicate through a declared event

**Why it breaks fusion.** Importing another panel's internals couples the builds; the other team's refactor breaks this panel.

Violation:

```
import { selected } from '../../records/panel/src/stores';
```

Compliant:

```
on('records.record_selected', ({ record_id }) => ...);
```

## S-EVT-002

Seam: Events. Severity: error.

**Finds.** emit or on with an event the shape does not declare

**Fix.** Declare it in the contract (emits or consumes)

**Why it breaks fusion.** Consumers cannot rely on an event nobody declared, and its payload is never validated.

Violation:

```
emit('finance.margin_changed', { value });  (not declared)
```

Compliant:

```
emits :margin_changed, payload: :margin  (declared) then emit('finance.margin_changed', margin);
```

## S-EVT-003

Seam: Events. Severity: error.

**Finds.** window.postMessage, dispatchEvent on window or document

**Fix.** Use emit

**Why it breaks fusion.** Global DOM events reach every panel, including ones that never agreed to listen.

Violation:

```
window.dispatchEvent(new CustomEvent('refresh'));
```

Compliant:

```
emit('finance.refresh_requested', {});
```

## S-DAT-001

Seam: Data. Severity: error.

**Finds.** fetch, XMLHttpRequest, EventSource, WebSocket, navigator.sendBeacon

**Fix.** Use the generated client

**Why it breaks fusion.** Direct fetch skips validation, timeouts, retries and the unavailable and not_built states.

Violation:

```
const r = await fetch('/api/v1/modules/finance/margin', { method: 'POST', body });
```

Compliant:

```
const r = await finance.margin({ revenue, cogs }); if (r.ok) ... else ...
```

## S-DAT-002

Seam: Data. Severity: error.

**Finds.** A client call to an operation the shape does not list

**Fix.** Use a declared operation

**Why it breaks fusion.** An operation outside the contract is outside what the backend promised to support.

Violation:

```
await records.purgeAll();  (not in the shape's operations)
```

Compliant:

```
Use only the operations the contract lists; ask for a new operation through the contract.
```

## S-KEY-001

Seam: Keyboard. Severity: error.

**Finds.** keydown, keyup or keypress listeners on window or document (including svelte:window and svelte:document)

**Fix.** Use shortcut with a declared shortcut

**Why it breaks fusion.** Two panels handling the same key on the window both fire, or one swallows the other's keys.

Violation:

```
<svelte:window onkeydown={handleKey} />
```

Compliant:

```
shortcut('mod+k', openSearch);  (shortcut declared)
```

## S-LIF-001

Seam: Lifecycle. Severity: error.

**Finds.** setInterval, setTimeout, requestAnimationFrame, requestIdleCallback

**Fix.** Use every, after or frame

**Why it breaks fusion.** A raw interval keeps running after the panel unmounts and calls into a destroyed component.

Violation:

```
setInterval(refresh, 5000);
```

Compliant:

```
every(5000, refresh);
```

## S-ID-001

Seam: Identity. Severity: error.

**Finds.** A literal id attribute or literal ARIA id reference

**Fix.** Use useId

**Why it breaks fusion.** Two panels both using id=amount make labels point at the wrong input.

Violation:

```
<label for="amount">Amount</label><input id="amount" />
```

Compliant:

```
const id = useId('amount'); <label for={id}>Amount</label><input {id} />
```

## S-LAY-001

Seam: Layout. Severity: error.

**Finds.** vw, vh, dvh, svh, lvh units used for size

**Fix.** Use container-query units or percentages

**Why it breaks fusion.** Viewport sizing assumes the panel owns the page; in a slot it overflows its neighbours.

Violation:

```
<section class="h-screen">
```

Compliant:

```
<section class="h-full min-h-0">  (the slot sets the height)
```

## S-LAY-002

Seam: Layout. Severity: error.

**Finds.** z-index outside the overlay host

**Fix.** Remove it; stacking belongs to the overlay host

**Why it breaks fusion.** Competing z-index values across panels make overlays appear under ordinary content.

Violation:

```
.card { z-index: 50; }
```

Compliant:

```
Remove the z-index; open floating content through the overlay host.
```

## S-LAY-003

Seam: Layout. Severity: error (warning under relaxed).

**Finds.** Negative margins on the panel's root element

**Fix.** Use padding inside the slot

**Why it breaks fusion.** Negative margins on the root paint over the neighbouring slot.

Violation:

```
<div class="-mx-6">
```

Compliant:

```
<div class="px-0">  (pad inside the slot instead)
```

## S-LAY-004

Seam: Layout. Severity: error.

**Finds.** Reaching the page outside the slot through document - querySelector, querySelectorAll, getElementById, getElementsByClassName, getElementsByTagName, getElementsByName, elementFromPoint, elementsFromPoint, and inserting into or removing from document.body or document.documentElement

**Fix.** Use bind:this for elements inside your panel, openOverlay for anything that must render above it, and events to affect another panel

**Why it breaks fusion.** A panel that queries or edits the whole document can find and change another panel's elements, or render outside every slot, and no other panel's author agreed to that.

Violation:

```
document.querySelector('nav').remove(); document.body.appendChild(tooltip);
```

Compliant:

```
let chart; <div bind:this={chart}></div>
```

## S-CSS-001

Seam: Tokens. Severity: error.

**Finds.** A class outside the token vocabulary

**Fix.** Use the nearest token class; the message names it

**Why it breaks fusion.** Classes outside the token vocabulary do not change with the theme.

Violation:

```
<p class="text-gray-500">
```

Compliant:

```
<p class="text-text-dim">
```

## S-CSS-002

Seam: Tokens. Severity: error.

**Finds.** An arbitrary value class such as bg-[#123456] or p-[13px]

**Fix.** Use a token

**Why it breaks fusion.** Arbitrary values bypass the theme and the spacing scale.

Violation:

```
<div class="bg-[#1d1d1f] p-[13px]">
```

Compliant:

```
<div class="bg-surface-2 p-3">
```

## S-CSS-003

Seam: Tokens. Severity: error.

**Finds.** A literal colour, length or shadow in a style block or style attribute (hex, rgb, hsl, px other than 0 and 1px borders)

**Fix.** Use var(--token)

**Why it breaks fusion.** A literal colour renders correctly in one theme only.

Violation:

```
<style> .tile { color: #c9a961; margin: 13px; } </style>
```

Compliant:

```
<style> .tile { color: var(--accent); margin: var(--space-3); } </style>
```

## S-CSS-004

Seam: Tokens. Severity: error.

**Finds.** :global selectors and element selectors that reach outside the component

**Fix.** Style within the component

**Why it breaks fusion.** A global selector restyles every panel's buttons.

Violation:

```
:global(.btn) { border-radius: 0; }
```

Compliant:

```
Style the component's own elements, or use a Dovetail Button variant.
```

## S-CSS-005

Seam: Tokens. Severity: error (warning under relaxed).

**Finds.** A class attribute built from a non-literal expression the checker cannot resolve

**Fix.** Use class: directives or literal alternatives so every class is visible to the checker

**Why it breaks fusion.** A computed class name can produce any class, including ones outside the token vocabulary.

Violation:

```
<div class={tone + '-box'}>
```

Compliant:

```
<div class:bg-surface-2={tone === 'calm'} class:bg-warning={tone === 'alert'}>
```

## S-HTML-001

Seam: Layout. Severity: error.

**Finds.** Landmark roles banner, navigation, contentinfo or main in a panel

**Fix.** Use region

**Why it breaks fusion.** Two navigation landmarks confuse screen-reader users about which is the application's.

Violation:

```
<nav role="navigation">...</nav>
```

Compliant:

```
<div role="region" aria-label={t('finance.sections')}>...</div>
```

## S-HTML-002

Seam: Layout. Severity: error (warning under relaxed).

**Finds.** A heading above the slot's starting level

**Fix.** Start at the slot's heading level

**Why it breaks fusion.** A second h1 breaks the page outline the shell owns.

Violation:

```
<h1>Margins</h1>  (in a main slot)
```

Compliant:

```
<h2>Margins</h2>
```

## S-HTML-003

Seam: Layout. Severity: error.

**Finds.** A form control without a label

**Fix.** Add a label or aria-label

**Why it breaks fusion.** An unlabelled control cannot be used with a screen reader.

Violation:

```
<input bind:value={amount} />
```

Compliant:

```
<Field label={t('finance.amount')}><NumberInput bind:value={amount} /></Field>
```

## S-HTML-004

Seam: Security. Severity: warning.

**Finds.** Any {@html} block

**Fix.** Render structured content with components; if raw HTML is unavoidable, sanitise it on the server and keep the warning with a justification

**Why it breaks fusion.** Raw HTML from imported data can carry script into every panel on the page.

Violation:

```
{@html review.body}
```

Compliant:

```
<p>{review.body}</p>  (text is escaped by default)
```

## S-I18N-001

Seam: Messages. Severity: warning.

**Finds.** A message key without the module prefix

**Fix.** Prefix the key with the module id

**Why it breaks fusion.** Unprefixed keys from two panels collide in the merged message catalogue.

Violation:

```
t('title')
```

Compliant:

```
t('finance.dashboard.title')
```

## S-STATE-001

Seam: View states. Severity: error.

**Finds.** A declared view that does not render one of its required states

**Fix.** Render loading, empty, error, unavailable and ready

**Why it breaks fusion.** Without an unavailable state the panel shows a blank area when the backend is down, which the A3 cutouts are graded on.

Violation:

```
<View name="dashboard">{#if data}<Dashboard {data} />{/if}</View>
```

Compliant:

```
<View name="dashboard"><States loading={Skeleton} empty={Empty} error={Err} unavailable={Unavail} ready={Dashboard} /></View>
```

## S-DYN-001

Seam: Any seam. Severity: error.

**Finds.** Computed access to globals (globalThis[...], window[...]) and eval, Function, new Function

**Fix.** Use the primitives directly

**Why it breaks fusion.** Computed global access hides a seam effect from the checker.

Violation:

```
globalThis['local' + 'Storage'].setItem(k, v);
```

Compliant:

```
store(k).set(v);
```

## S-DEP-001

Seam: Any seam. Severity: error.

**Finds.** An import of a package outside the allowed list (@dovetail/runtime, svelte, the generated types and client, the panel's own files)

**Fix.** Build it from the allowed packages

**Why it breaks fusion.** An extra package adds weight and behaviour the other panels never agreed to.

Violation:

```
import dayjs from 'dayjs';
```

Compliant:

```
Use the locale formatters from @dovetail/runtime.
```

## S-PARSE-001

Seam: Any seam. Severity: warning.

**Finds.** A construct the parser does not recognise

**Fix.** Report it; the file was still checked by text scanning

**Why it breaks fusion.** Unknown constructs are never assumed safe.

Violation:

```
A syntax the checker does not know yet
```

Compliant:

```
The file is still checked by text scanning; report the construct so the parser can learn it.
```
