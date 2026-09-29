# {{Module}} panel

This panel is described by a brief, a plain language summary of what it may and
may not do. Generate it any time with `dovetail brief .dovetail/generated/shape/{{module}}.shape.json`
from the app root, or read `.dovetail/generated/shape/{{module}}.brief.md` after a fuse.

Dovetail gives every panel nine seams, the only ways it can reach past its own
markup.

- Data: call your own module's generated operations, nothing else.
- Events: emit and receive only the events your contract declares.
- Lifecycle: schedule timers, intervals and frames through the runtime, never raw browser timers.
- Identity: get stable element ids from the runtime, never invent your own.
- Layout: render into your declared slots, nothing wider and nothing outside them.
- Navigation: move only to routes your contract declares.
- Overlay: open only the overlays your contract declares.
- Storage: read and write only the storage keys your contract declares.
- Keyboard: register only the shortcuts your contract declares.

Everything else, styling with tokens, composing markup, choosing components,
is completely free.
