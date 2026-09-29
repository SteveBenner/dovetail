# Shape JSON

A shape is the part of a contract that governs a panel's UI code: its slots, views, capabilities, overlays, routes,
events, operations, storage keys, shortcuts and tokens. `dovetail compile` writes it to
`<out>/shape/<module>.shape.json` for every contract that declares a panel, and `dovetail check` reads it.

The shape is what a panel's author receives. It carries no field types and no backend detail, only what the checker
needs to judge the panel's code.

## Schema `dovetail.shape/v1`

| Key | Type | Meaning |
| --- | --- | --- |
| `schema` | string | Always `dovetail.shape/v1`. |
| `module` | string | The module id. |
| `contract_version` | integer | The contract's version. |
| `slots` | array | `{ name, size, min_width, max_width }` for each slot. Widths are integers in px, or `null`. |
| `views` | array | `{ name, data_operation, states }` for each view. `data_operation` is a qualified operation id. |
| `capabilities` | array | The declared seams: `overlay`, `navigation`, `storage`, `keyboard`, `lifecycle`. |
| `overlays` | array | `{ name, kind, dismissible, blocking }` for each overlay. |
| `routes` | array | Route patterns, such as `/finance/findings/:id`. |
| `events` | object | `{ emits: [event id], consumes: [event id] }`. Event ids are `<module>.<event>`. |
| `operations` | array | The qualified ids of the operations the panel may call. |
| `storage_keys` | array | `{ name, ttl_days }` for each storage key. |
| `shortcuts` | array | `{ keys, action, scope }` for each shortcut. |
| `tokens` | array | The granted token families, or `["default"]` for all of them. |
| `rules_profile` | string | `strict` or `relaxed`. |

Keys are sorted and the file has no timestamps, so compiling the same contract always gives the same bytes on every
supported Ruby.

## Example

The finance shape from the worked example:

```json
{
  "capabilities": ["navigation", "overlay", "storage"],
  "contract_version": 2,
  "events": {
    "consumes": ["context.settings_changed"],
    "emits": ["finance.finding_selected"]
  },
  "module": "finance",
  "operations": ["finance.findings", "finance.margin"],
  "overlays": [
    { "blocking": true, "dismissible": true, "kind": "drawer", "name": "finding_detail" }
  ],
  "routes": ["/finance", "/finance/findings/:id"],
  "rules_profile": "strict",
  "schema": "dovetail.shape/v1",
  "shortcuts": [],
  "slots": [
    { "max_width": null, "min_width": 480, "name": "main", "size": "main" },
    { "max_width": null, "min_width": null, "name": "summary", "size": "tile" }
  ],
  "storage_keys": [{ "name": "period", "ttl_days": 30 }],
  "tokens": ["default"],
  "views": [
    {
      "data_operation": "finance.findings",
      "name": "dashboard",
      "states": ["loading", "empty", "error", "unavailable", "ready"]
    },
    {
      "data_operation": "finance.margin",
      "name": "margin_tile",
      "states": ["loading", "empty", "error", "unavailable", "ready"]
    }
  ]
}
```

## Signatures

A shape handed to an author can be signed, so a checker can refuse a shape that was edited after it was issued.

- `dovetail sign <shape.json> --private-key <pem>` writes the signature beside the shape, with `.json` replaced by
  `.sig` (`finance.shape.json` gets `finance.shape.sig`).
- The signature is RSA-PSS with SHA-256 (MGF1 with SHA-256, salt as long as the digest), computed over the shape's
  canonical JSON: keys sorted, no whitespace. It is stored base64 encoded. Reformatting the file does not break it;
  changing any value does.
- `dovetail check --require-signed` refuses a shape unless one of the configured public keys verifies it.

Public keys are taken from the first of these that is set:

1. `--public-key <pem>`, which may be given more than once;
2. `DOVETAIL_PUBLIC_KEYS`, a list of PEM file paths joined by the platform's path separator (`:` on macOS and Linux);
3. `public_keys` in the nearest `dovetail.yml`.

A list of keys allows rotation: a new key signs new shapes, and a retired key is removed once every shape it signed
has been signed again.

| Code | Meaning |
| --- | --- |
| `D-SHP-001` | The shape file is missing, is not JSON, or is not `dovetail.shape/v1`. |
| `D-SHP-002` | No configured key verifies the signature, or the signature file is missing. |
| `D-SHP-003` | A signature is required and no public key is configured, or a configured key file cannot be read. |
