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
  current one. The client returns it as an ordinary error result, never an exception.
- **Responses and events.** Every response and every server event carries `contract_version`. The runtime accepts a
  response only at the version the panel was built against and returns `contract_version_mismatch` otherwise; a
  server event at any other version than the producer's is not delivered.
- **Stored values.** Browser storage keys are namespaced as `dovetail:<module>:v<version>:<key>`. Raising a version
  starts every storage key empty, so a panel never reads a value written under an older shape.

## A working rhythm

1. Change the contract.
2. Run `dovetail contract diff` against the last released copy.
3. If anything is breaking, raise the version, and tell the teams whose panels consume your events or depend on your
   types.
4. Compile, and hand out the new shape and brief.
