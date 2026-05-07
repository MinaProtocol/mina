# Mina Rosetta integration examples

Runnable scripts demonstrating common integration patterns against Mina's [Rosetta (Mesh) API](https://docs.cdp.coinbase.com/mesh/docs/welcome) implementation.

These examples are co-located with the Rosetta server source so they stay in sync with the daemon they target. See the docs portal for narrative and architecture context.

## Prerequisites

A running Mina Rosetta endpoint. The fastest way is the Docker Compose stack in `../docker-compose/`:

```bash
cd ../docker-compose
make rosetta-up   # devnet by default
```

This exposes Rosetta at `http://localhost:3087`.

## Available examples

### TypeScript (`ts/`)

Cardano-style: `axios` + thin endpoint wrappers + [`mina-signer`](https://www.npmjs.com/package/mina-signer) for transaction signing. No SDK dependency — the Rosetta spec is small enough that hand-rolled wrappers are clearer than a generated client.

| Script | What it does |
| --- | --- |
| `account-balance.ts` | Query a single account balance (smoke test) |
| `scan-blocks.ts` | Poll `/network/status` and fetch new blocks as they arrive |
| `track-deposits.ts` | Watch an address for incoming MINA deposits |
| `send-transaction.ts` | Full Construction API flow: derive → preprocess → metadata → payloads → sign → combine → submit |
| `offline-sign.ts` | Same flow split for cold-signing setups: metadata online, signing offline |

See `ts/README.md` for setup and run instructions.

### Go (`go/`)

Read-side examples using [`coinbase/mesh-sdk-go`](https://github.com/coinbase/mesh-sdk-go) (the canonical Go SDK). Send-transaction is intentionally not included because Pallas signing has no pure-Go implementation today — see `go/README.md` for options.

| Program | What it does |
| --- | --- |
| `account-balance/` | Query a single account balance |
| `scan-blocks/` | Poll for new blocks via `fetcher` |
| `track-deposits/` | Filter `payment_receiver_inc` operations for an address |

## Adding examples in other languages

Drop a sibling directory (`py/`, `rust/`, etc.). Keep each language self-contained with its own `README.md` and follow the same pattern: thin client wrappers (or generated client over the [Mesh OpenAPI spec](https://github.com/coinbase/mesh-specifications)), one program per integration scenario, runnable against a live Rosetta endpoint.
