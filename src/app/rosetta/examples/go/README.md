# Go Rosetta examples

Read-side Rosetta integration examples in Go using [`coinbase/mesh-sdk-go`](https://github.com/coinbase/mesh-sdk-go) — the canonical Go SDK Coinbase ships and uses internally.

These examples are intentionally minimal. For Go, the upstream `mesh-sdk-go/examples/` directory already covers the generic Rosetta flow well. The point here is to show the **Mina-specific** bits (operation types, transfer layout, default token ID) wired up against `fetcher.New(...)`.

## Setup

```bash
cd src/app/rosetta/examples/go
go mod download
```

## Run

Each example is a separate `main` package. Pass configuration via environment variables (same names as the TypeScript examples):

```bash
export ROSETTA_URL=http://localhost:3087
export NETWORK=devnet
export TEST_ADDRESS=B62q...

go run ./account-balance
go run ./scan-blocks
go run ./track-deposits
```

## Why no send-transaction in Go

Mina uses the Pallas curve for signatures, and there is no pure-Go Pallas signer. To send transactions from Go you would either:

- Shell out to the [`mina-ocaml-signer`](../../../rosetta/ocaml-signer) CLI shipped with the Rosetta image, or
- Run the TypeScript [`offline-sign.ts`](../ts/offline-sign.ts) example for the signing step and submit from Go

For most exchange integrators this is a non-issue — signing usually happens in a separate cold-signing service. The Go examples here cover the read-side patterns (`/account/balance`, `/block`, `/network/status`) that real integrators run from their main service.
