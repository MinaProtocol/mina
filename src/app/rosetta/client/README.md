# rosetta-client

Generic CLI wrapper for the [Rosetta API](https://www.rosetta-api.org/) as
implemented by Mina Rosetta.  Think of it as "curl on steroids": every
subcommand maps to a single endpoint, auto-injects
`{"blockchain": "mina", "network": "testnet"}` into the request's
`network_identifier`, and prints the response as JSON (pretty by default,
`--compact` for one-line output).

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
│   └── balance        --address B62q... [--token-id T] [--index N]
├── mempool
│   ├── list
│   └── transaction    --tx-hash H
└── search
    └── transactions   [--address B62q...] [--tx-hash H] [--limit N]
```

`block transaction` is deliberately absent: Mina's Rosetta server returns
every transaction inline in `/block`, does not implement
`/block/transaction`, and would answer 404.  Use `block get` and filter
the returned transactions by hash.

`account coins` is absent for the same reason.  The server routes
`/account/balance` and answers 404 to everything else under `/account/`,
and the coins model is a UTXO notion that an account-based chain has
nothing to say about — `/network/options` advertises
`"mempool_coins": false`.

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
to talk to the same server repeatedly without repeating the flags.  The
flags themselves live in `Rosetta_client.Flags` and their fallbacks in
`Rosetta_client.Defaults`, so every binary built on the library offers
the same flags and falls back to the same place.

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
```

## Output contract

On success, the response body is printed as pretty JSON on stdout (or
compact JSON with `--compact`), followed by a single newline.  Exit 0.

On failure — HTTP non-2xx or a transport error — the tool logs a short
diagnostic to stderr through Mina's `Logger` and exits 1.  Stdout stays
the data channel: it carries the response and nothing else, so a caller
can pipe it into `jq` without filtering log lines out first.  The
diagnostic is guaranteed to:

- Never leak raw OCaml exception syntax (no `Unix_error`, no `(Unix. ...)`).
- Never dump multi-kilobyte HTTP bodies verbatim; Rosetta error envelopes
  are parsed and rendered as `HTTP <code>: <message>`.

The HTTP client, the endpoint wrappers and the error formatting live in
`src/lib/rosetta_client/`; `rosetta_client_cli.ml` holds only the flags,
the subcommand tree and the output.
