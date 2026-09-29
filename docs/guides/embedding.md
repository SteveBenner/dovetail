# Embedding in another web app

A fused application can live inside another web page as a single custom element. The host page can be built with
React, Vue, Angular, a server-rendered template or plain HTML; it needs no Svelte, no build step for Dovetail and no
iframe. The embedded application is the same application: the same shell, panels, contracts and themes.

## Turning it on

```yaml
embed: true
embed_tag: dovetail-app
```

`embed` defaults to false. `embed_tag` defaults to `dovetail-app` and must be a valid custom element name: lowercase
letters, digits and single hyphens, starting with a letter and containing at least one hyphen. `dovetail fuse --embed`
turns embedding on for one run.

```console
$ dovetail fuse --app ui --embed
fused 3 panels
```

The fuse writes `<out>/dist/embed/dovetail-app.js` beside the application's own bundle. A build with live components
skips it, because live components rely on the import map in the application's own `index.html`, and the fuse report
says so.

## Hosting it

Serve `<out>/dist/embed/` as static files, then add the module and the element to the host page:

```html
<script type="module" src="/assets/dovetail/dovetail-app.js"></script>

<dovetail-app theme="apple-noir" api-base="https://api.example.com"></dovetail-app>
```

In React, Vue or any other framework, render `<dovetail-app>` like any element and load the module once. The element
is `display: block`; size and place it from the host.

## Attributes

| Attribute | Meaning |
| --- | --- |
| `theme` | The id of one of the application's themes. Changing it re-themes without a reload. |
| `locale` | The active locale code, default `en-US`. |
| `routing` | `memory` (default): the application keeps its own route and never touches the host's URL. `history`: it owns the page's path, as a standalone Dovetail application does. |
| `path` | In `memory` routing, the route to show. Changing it navigates. |
| `api-base` | The base URL the transport calls, default the host page's own origin. |
| `version-policy` | `strict` (default) or `tolerant`; see [Versioning contracts](versioning-contracts.md). |
| `prefetch` | `false` turns off route prefetching. |

A backend on another origin must send the CORS headers the host page needs; Dovetail adds none.

## Events

The element dispatches these events. They bubble and cross the shadow boundary, so the host can listen on the element or
on `document`:

| Event | `detail` |
| --- | --- |
| `dovetail-ready` | `{}`, once the application has mounted |
| `dovetail-route` | `{ path, module }`, after every route change |
| `dovetail-panel-error` | `{ module, message }`, when a panel crashes into its fallback |

```js
document.querySelector('dovetail-app').addEventListener('dovetail-route', (event) => {
  analytics.page(event.detail.path);
});
```

## What stays on each side

The application renders inside an open shadow root. The host's stylesheets do not reach inside it, so a host rule
like `button { ... }` cannot restyle a panel. Dovetail's stylesheet, including its reset, does not reach out, so the
host page looks exactly as it did.

Overlays, toasts and tooltips render in the browser's top layer. A host wrapper with `overflow: hidden`, a transform
or a low `z-index`, and a host header with the highest `z-index`, cannot clip or cover them. A blocking overlay makes
the whole page inert while it is open, the host's page included, and locks the host page's scrolling.

Keyboard shortcuts and Escape apply while focus is inside the application. Removing the element unmounts the
application and releases everything it held; adding it back mounts it again.

## Limits

- One element of a given tag can be mounted at a time. A second one renders nothing and logs `D-RUN-007`. Two
  different applications, built with different `embed_tag` values, can share a page.
- The embed bundle is a production build. Its development hooks, toolbar and fixture transport are not in it.
- `dovetail fuse --verify` builds a development copy of the element and checks it in a deliberately hostile host page;
  see [Fusing and verifying](fusing-and-verifying.md).
