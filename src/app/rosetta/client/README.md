# rosetta-client

Generic CLI wrapper for the [Rosetta API](https://www.rosetta-api.org/) as
implemented by Mina Rosetta.  Think of it as "curl on steroids": every
subcommand maps to a single endpoint, auto-injects
`{"blockchain": "mina", "network": "testnet"}` into the request's
`network_identifier`, and prints the response as JSON (pretty by default,
`--compact` for one-line output).

For readiness probes, see the sibling
[`rosetta-healthcheck`](../rosetta_healthcheck/README.md) binary.

## Subcommand tree

```
rosetta-client
├── network
│   ├── list
│   ├── status
│   └── options
├── block
│   ├── get            --index N | --hash H
│   └── transaction    --index N --block-hash H --tx-hash H
├── account
│   ├── balance        --address B62q... [--token-id T] [--index N]
│   └── coins          --address B62q... [--include-mempool]
├── mempool
│   ├── list
│   └── transaction    --tx-hash H
├── search
│   └── transactions   [--address B62q...] [--tx-hash H] [--limit N]
├── construction
│   ├── derive         --public-key-json JSON [--metadata-json JSON]
│   ├── preprocess     --operations-json JSON [--metadata-json JSON]
│   ├── metadata       --options-json JSON [--public-keys-json JSON]
│   ├── payloads       --operations-json JSON [--metadata-json JSON] [--public-keys-json JSON]
│   ├── parse          --signed|--unsigned --transaction STR
│   ├── combine        --unsigned-transaction STR --signatures-json JSON
│   ├── hash           --signed-transaction STR
│   └── submit         --signed-transaction STR
└── config
    ├── show           [--file NAME]
    └── export         --out-dir DIR
```

## Global flags

Every leaf command accepts:

| Flag | Default | Notes |
|------|---------|-------|
| `--rosetta-uri` | `http://localhost:3087` | Base URL of the Rosetta server. Can be overridden by `MINA_ROSETTA_URI`. |
| `--blockchain` | `mina` | Injected into `network_identifier.blockchain`. |
| `--network` | `testnet` | Injected into `network_identifier.network`. |
| `--timeout` | `30` | HTTP request timeout in seconds. |
| `--compact` | off | Emit compact JSON instead of indented. |

## Examples

```bash
# Readable JSON on a local Rosetta:
rosetta-client network status
rosetta-client block get --index 100
rosetta-client account balance --address B62q...

# Point at a non-default host and override network:
rosetta-client network options \
  --rosetta-uri http://rosetta.example.com:3087 \
  --network mainnet

# Construction flow:
rosetta-client construction derive \
  --public-key-json '{"hex_bytes":"abcd","curve_type":"pallas"}'

# Extract embedded rosetta-cli config files for a manual sweep:
rosetta-client config show > /tmp/config.json
rosetta-client config export --out-dir /tmp/cfg
```

## Output contract

On success, the response body is printed as pretty JSON on stdout (or
compact JSON with `--compact`), followed by a single newline.  Exit 0.

On failure — HTTP non-2xx, transport error, invalid JSON input — the tool
prints a short diagnostic on stderr and exits 1.  The diagnostic is
produced by the `Rosetta_client.Errors` module and is guaranteed to:

- Never leak raw OCaml exception syntax (no `Unix_error`, no `(Unix. ...)`).
- Never dump multi-kilobyte HTTP bodies verbatim; Rosetta error envelopes
  are parsed and rendered as `HTTP <code>: <message>`.

## Relationship to `rosetta-healthcheck`

- **This tool** — Arbitrary Rosetta API calls for debugging, scripting, and
  day-to-day operations.
- **`rosetta-healthcheck`** — Composite readiness (`ready` / `wait`),
  tip-recency / connectivity probes.

Both binaries share the same underlying HTTP library
(`src/lib/rosetta_client/`).
