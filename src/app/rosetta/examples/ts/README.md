# TypeScript Rosetta examples

Runnable scripts integrating with Mina's [Rosetta (Mesh) API](https://docs.cdp.coinbase.com/mesh/docs/welcome).

The examples use [`@o1-labs/mina-rosetta-sdk`](https://github.com/o1-labs/mina-rosetta-sdk-js) for the typed Rosetta HTTP surface and [`mina-signer`](https://www.npmjs.com/package/mina-signer) for Pallas-curve transaction signing. The SDK is a light wrapper — it doesn't reimplement the full `mesh-sdk` typed-client stack, just the endpoints Mina actually exposes plus a few Mina-specific operation builders.

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
| `account-balance.ts` | One-shot balance query against `/account/balance` |
| `scan-blocks.ts` | Polling loop that fetches blocks sequentially from chain tip |
| `track-deposits.ts` | Same loop, filtering operations for `payment_receiver_inc` to a target address |
| `send-transaction.ts` | preprocess → metadata → payloads → sign → combine → submit |
| `offline-sign.ts` | Splits the same flow across hot/cold environments via on-disk handoff files |

## Mina-specific knobs

The SDK exports these constants:

- `BLOCKCHAIN = "mina"`
- `CURVE_TYPE = "pallas"`
- `MINA_CURRENCY = { symbol: "MINA", decimals: 9 }` — amounts are in nanomina
- `DEFAULT_TOKEN_ID` — the canonical MINA token ID; override for custom tokens
- `OperationType.{FeePayment, PaymentSourceDec, PaymentReceiverInc, ...}` — the operation-type strings the Rosetta server uses

The three-operation MINA transfer (`fee_payment` → `payment_source_dec` → `payment_receiver_inc`) is built by `buildTransferOperations()`; stake delegations by `buildDelegationOperations()`. See `send-transaction.ts` for usage of the transfer helper end-to-end.

## Adapting these to your codebase

Install the SDK directly — no need to copy any files out of this directory:

```bash
npm install @o1-labs/mina-rosetta-sdk mina-signer
```

Then use `account-balance.ts` and `send-transaction.ts` as templates for the read-side and write-side patterns.

For a deeper walkthrough of what each step does and the Mina-specific spec deltas, see the [Rosetta integration guide](https://docs.minaprotocol.com/node-operators/rosetta) on the docs portal.
