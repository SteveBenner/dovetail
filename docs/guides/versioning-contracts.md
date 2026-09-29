# Versioning contracts

A fused application keeps working while panels and the backend are revised one at a time. That works because every
contract carries a version, and every change to a contract is either compatible, which keeps the version, or breaking,
which raises it.

## Compatible and breaking changes

| Compatible (keep the version) | Breaking (raise the version) |
| --- | --- |
| Adding a type, operation, event, slot, view, overlay or route | Removing a type, field, operation, event, slot, view, overlay or route |
| Adding an optional field, or a required field with a default | Adding a required field with no default |
| Making a required field optional | Making an optional field required |
| Widening an enum, a minimum or a maximum | Narrowing an enum, a minimum or a maximum |
| Adding a state to a view beyond the required five | Changing a field's type, or an operation's input or output |
| Adding a panel to a contract that had none | Removing the panel |

## Checking a change before you make it

`dovetail contract diff` compares two versions of a contract file and classifies every change:

```console
$ dovetail contract diff old/contract.rb contract.rb
D-CON-003 breaking change without a version increase (still v1)
breaking: narrowed enum on 'order.status'
$ echo $?
1
```

It exits 0 when every change is compatible, or when there are breaking changes and the version went up. It exits 1
with `D-CON-003` when a breaking change keeps the same version. The fix is to raise `version:` by one:

```console
$ dovetail contract diff old/contract.rb contract.rb
breaking: narrowed enum on 'order.status'
$ echo $?
0
```

## The fuse checks it too

`dovetail compile` writes each contract's model to `<out>/model/<module>.model.json`. The next `dovetail fuse`
compares every contract with the model the previous fuse left in the output directory, and fails with C007 when a
breaking change kept its version. A first fuse, with no previous model, has nothing to compare.

## What a version changes at run time

- **Requests.** Every call carries `X-Dovetail-Contract: <module>@<version>`. A server that follows the wire protocol
  answers `contract_version_mismatch`, with both versions, when a breaking change separates that version from its
  current one, or negotiates the call (below). The client returns a mismatch as an ordinary error result, never an
  exception.
- **Responses and events.** Every response and every server event carries `contract_version`. The runtime accepts a
  response at the version the panel was built against. It accepts one at another version only when the data
  validates against the panel's own output schema and either the server declared the negotiation or the shell's
  version policy is `tolerant`; otherwise it returns `contract_version_mismatch`. A server event at another version
  than the producer's is delivered only under the `tolerant` policy and only when its payload validates.
- **Stored values.** Browser storage keys are namespaced as `dovetail:<module>:v<version>:<key>`. Raising a version
  starts every storage key empty, so a panel never reads a value written under an older shape.

## Negotiating across a breaking change

A breaking change rarely touches every operation. `dovetail contract compat` tells you which ones it leaves alone:

```console
$ dovetail contract compat v1/contract.rb contract.rb --format json
```

It reports, for every operation and event of the old contract, `compatible` and the breaking changes that affect it.
An operation is affected when a breaking change removes or changes it, its input or output, or any type they reach.
A Ruby backend can compute the same table with `Dovetail::Negotiation.compat(old_model, new_model)`.

A server at version 2 that receives a version 1 call to an operation the change left compatible can answer it
instead of refusing:

```json
{ "status": "ok", "data": { "items": [] }, "contract_version": 2, "negotiated": { "requested": 1, "served": 2 } }
```

The runtime accepts that response, after checking the data against the version 1 panel's own schema, and the
result carries `negotiated`. For a call it cannot answer, the server keeps answering `contract_version_mismatch`
and may list the versions it can answer in `supported_versions`, so the panel's error states can say more than
"out of date".

The shell's `versionPolicy` decides what happens when the server does not declare a negotiation. `strict`, the
default, refuses every response at another version. `tolerant` accepts one whose data validates against the panel's
own schema, and delivers a server event at another version whose payload validates. `tolerant` suits a backend and
panels that deploy on separate schedules; `strict` suits an application whose parts always ship together.

## Schemas for other consumers

`dovetail compile` writes two schemas per module. `schema/<module>.schema.json` is closed: every object rejects
properties it does not declare. That is right for checking what a panel sends, and wrong for anything checking what a
newer server returns. A compatible change adds an optional field and keeps the version, so a consumer validating
responses against the closed schema would reject a response the contract says is compatible.

`schema-open/<module>.schema.json` is the same schema without `additionalProperties: false`. Give that one to a
backend, another client or a contract test in another language. Dovetail's own runtime validator already ignores
properties a schema does not declare.

## A working rhythm

1. Change the contract.
2. Run `dovetail contract diff` against the last released copy.
3. If anything is breaking, raise the version, and tell the teams whose panels consume your events or depend on your
   types.
4. Compile, and hand out the new shape and brief.
