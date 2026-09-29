# Working with an AI agent and a brief

Dovetail was built for panels written by people working with an AI coding agent. The agent is free inside the panel's
slot, the checker is strict at its edge, and the brief tells both of them where the edge is.

## What to give the agent

1. **The brief, verbatim.** `dovetail compile` writes it to `<out>/shape/<module>.brief.md`, and `dovetail brief
   <shape.json>` prints it. It says, in plain language, what the panel is for, where it renders, what data it shows,
   what it may do across its edge, what it may not do, the events it sends and hears, and the tokens it may style with.
2. **The generated types and client** for the module: `<out>/types/<module>.d.ts` and `<out>/client/<module>.ts`.
3. **The rule entries for the seams the panel does not declare.** `dovetail rules <id>` prints one; the
   [rule catalogue](../reference/rules.md) has them all.

A prompt fragment that works well in front of the brief:

> You are editing a Dovetail panel. The panel is free inside its slot. Anything that crosses the slot's edge must go
> through the primitive the brief names. When a request cannot fit the shape, say which boundary it crosses and offer
> the closest version that fits, starting with the requested design adjusted to comply.

## The loop

1. The agent writes or changes panel code.
2. The host runs `dovetail check --format json` on the panel.
3. Each finding becomes an instruction to the agent, with the rule's fix text and its compliant example.
4. The agent revises, and the host checks again, until the panel has no errors.

`dovetail check` exits 0 when there are no errors (warnings allowed), 1 when there are errors, and 2 when it cannot
run (a missing or unsigned shape, a bad command line). The JSON form:

```json
{
  "findings": [
    {
      "column": 3,
      "file": "src/Panel.svelte",
      "fix": "Use every, after or frame",
      "line": 4,
      "message": "setInterval bypasses the lifecycle seam",
      "rule": "S-LIF-001",
      "seam": "lifecycle",
      "severity": "error"
    }
  ],
  "panel": "finance",
  "shape_version": 2,
  "summary": { "errors": 1, "warnings": 0 }
}
```

`--changed <file>` limits the reported findings to one file, which keeps the agent's feedback about the file it just
edited. A host that hands out signed shapes adds `--require-signed`; see [Shape JSON](../reference/shape-json.md).

## Findings a person should see

Some fixes change nothing a person can see or do. An agent can make them silently:

S-LIF-001, S-ID-001, S-STO-001, S-DAT-001, S-EVT-003, S-KEY-001, S-DYN-001, and S-CSS-001 when a same-looking token
exists.

Other fixes change how the panel looks or behaves, so the person should hear about them before the agent moves on:

S-OVL-001, S-OVL-002, S-LAY-001, S-LAY-003, S-LAY-004, S-CSS-002, S-CSS-003 when no equivalent token exists,
S-HTML-001, S-STATE-001 and S-NAV-002.

## When a request does not fit

Some requests cannot fit the shape: "show a popup" when the contract declares no overlay, or "remember my filter" with
no storage key. The checker will refuse the code whatever the agent writes, so the agent should say which boundary the
request crosses and offer the nearest thing that fits, such as an inline expanding section instead of a popup. A
request that is worth the boundary becomes a contract change, which the module's owner makes (see
[Writing a contract](writing-a-contract.md)).
