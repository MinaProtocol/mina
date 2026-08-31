# rosetta-client

Generic CLI wrapper for the [Rosetta API](https://www.rosetta-api.org/) as
implemented by Mina Rosetta.  Think of it as "curl on steroids": every
subcommand maps to a single endpoint, auto-injects
`{"blockchain": "mina", "network": "testnet"}` into the request's
`network_identifier`, and prints the response as JSON (pretty by default,
`--compact` for one-line output).

For readiness probes, see the sibling
[`rosetta-healthcheck`](../healthcheck/README.md) binary.

## Subcommand tree

```
rosetta-client
├── network
│   ├── list
│   ├── status
│   └── options
├── block
│   └── get            --index N | --hash H
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
```

`block transaction` is deliberately absent: Mina's Rosetta server returns
every transaction inline in `/block`, does not implement
`/block/transaction`, and would answer 404.  Use `block get` and filter
the returned transactions by hash.

## Global flags

Every leaf command accepts:

| Flag | Default | Environment override | Notes |
|------|---------|----------------------|-------|
| `--rosetta-uri` | `http://localhost:3087` | `MINA_ROSETTA_URI` | Base URL of the Rosetta server. |
| `--blockchain` | `mina` | `MINA_ROSETTA_BLOCKCHAIN` | Injected into `network_identifier.blockchain`. |
| `--network` | `testnet` | `MINA_ROSETTA_NETWORK` | Injected into `network_identifier.network`. |
| `--timeout` | `30` | | Seconds allowed for one request/response exchange, from sending the request to reading the last byte of the response body. |
| `--compact` | off | | Emit compact JSON instead of indented. |

A flag always wins over its environment variable.  Export the variables
to talk to the same server repeatedly without repeating the flags; the
same three variables are read by `rosetta-healthcheck`.  Their fallback
values live in `Rosetta_client.Defaults`, so the two binaries cannot
drift apart.

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

# The same, for a whole session, without repeating the flags:
export MINA_ROSETTA_URI=http://rosetta.example.com:3087
export MINA_ROSETTA_NETWORK=mainnet
rosetta-client network options

# Construction flow:
rosetta-client construction derive \
  --public-key-json '{"hex_bytes":"abcd","curve_type":"pallas"}'
```

## Output contract

On success, the response body is printed as pretty JSON on stdout (or
compact JSON with `--compact`), followed by a single newline.  Exit 0.

On failure — HTTP non-2xx, transport error, invalid JSON input, or a
`--*-json` payload that does not match the Rosetta model the endpoint
expects — the tool prints a short diagnostic on stderr and exits 1.  The diagnostic is
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

Inside this binary, `rosetta_client_cli.ml` holds the flags, the
subcommand tree and the output; `payload.ml` holds the decoding of the
JSON-valued flags into Rosetta models, and neither prints nor exits.
