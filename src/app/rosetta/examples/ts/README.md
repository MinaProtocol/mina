# TypeScript Rosetta examples

Runnable scripts integrating with Mina's [Rosetta (Mesh) API](https://docs.cdp.coinbase.com/mesh/docs/welcome).

The examples use [`axios`](https://axios-http.com/) for HTTP and [`mina-signer`](https://www.npmjs.com/package/mina-signer) for Pallas-curve transaction signing. There is no Rosetta TypeScript SDK — the spec is small enough that hand-rolled wrappers in `commons.ts` are clearer than a generated client. This is the same pattern Cardano's official Rosetta examples use.

## Setup

```bash
cd src/app/rosetta/examples/ts
npm install
cp env.example .env
# edit .env with your Rosetta URL, network, addresses
```

Make sure a Rosetta endpoint is running. From this repo:

```bash
cd ../../docker-compose
make rosetta-up   # devnet by default
```

## Run an example

```bash
npm run account-balance      # query a balance (smoke test)
npm run scan-blocks          # poll for new blocks
npm run track-deposits       # watch an address for incoming MINA
npm run send-transaction     # full Construction API flow
npm run offline-sign         # cold-signing variant
```

Type-check without running:

```bash
npm run typecheck
```

## Layout

| File | Purpose |
| --- | --- |
| `commons.ts` | `RosettaClient` class wrapping the endpoints, shared types, helper to build a Mina transfer's three-operation payload |
| `account-balance.ts` | One-shot balance query against `/account/balance` |
| `scan-blocks.ts` | Polling loop that fetches blocks sequentially from chain tip |
| `track-deposits.ts` | Same loop, filtering operations for `payment_receiver_inc` to a target address |
| `send-transaction.ts` | preprocess → metadata → payloads → sign → submit (uses mina-signer's Rosetta helper, skips explicit combine) |
| `offline-sign.ts` | Splits the same flow across hot/cold environments via on-disk handoff files |

## Mina-specific knobs

These constants live in `commons.ts`:

- `BLOCKCHAIN = "mina"`
- `CURVE_TYPE = "pallas"`
- `MINA_CURRENCY = { symbol: "MINA", decimals: 9 }` — values are in nanomina
- `DEFAULT_TOKEN_ID` — the canonical MINA token ID; override for custom tokens

The three-operation MINA transfer (`fee_payment` → `payment_source_dec` → `payment_receiver_inc`) is built by `buildTransferOperations()`. See `send-transaction.ts` for usage.

## Adapting these to your codebase

The intent is to copy `commons.ts` and the operation-building helper into your own integration, not to depend on this directory at runtime. Each script is small (~50 lines) — pick the closest fit and adapt.

For a deeper walkthrough of what each step does and the Mina-specific spec deltas, see the [Rosetta integration guide](https://docs.minaprotocol.com/node-operators/rosetta) on the docs portal.
