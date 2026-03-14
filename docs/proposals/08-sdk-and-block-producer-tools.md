# Proposal: SDK & Block Producer Tooling Improvements

## Current SDK Landscape

### In-repo
- **OCaml GraphQL client** (`src/lib/mina_graphql_client/`): Typed client with narrow query coverage (peer info, account data, best chain, payments). Internal-focused.
- **CLI GraphQL client** (`src/app/mina_graphql_client/`): Wraps OCaml client as a binary. Returns JSON.
- **GraphQL schema dump** (`graphql_schema.json`, 495KB): Machine-readable introspection output.
- **GraphQL subscriptions**: `newSyncUpdate`, `newBlock`, `chainReorganization` --- WebSocket transport supported.

### External (not in repo)
- **o1js** (TypeScript): Primary zkApp SDK. Lives at `o1-labs/o1js`.
- **mina-signer** (JS): Transaction signing library.
- **Ledger Nano support**: Via `codaledgercli` external script.
- **No Python, Rust, or Go SDK** exists.

## Block Producer Pain Points

### 1. No Slot Schedule Export
Only `nextBlockProduction` exists (single next slot). No way to get all upcoming production slots for an epoch. Block producers can't:
- Set up calendar alerts
- Pre-scale infrastructure
- Compare expected vs actual production rates

**Proposed**: Add `slotsWon` GraphQL query that returns all won slots for a given epoch with timestamps.

### 2. No Expected Rewards Calculator
No query or tool to estimate: "Given my stake of X MINA and the current staking ledger, what are my expected block rewards per epoch?"

**Proposed**: Add `mina client expected-rewards --public-key B62q...` that calculates expected slots/epoch based on stake fraction.

### 3. No Delegation Visibility
No query for "list all accounts delegating to public key X with their balances." Operators must export the full ledger and filter.

**Proposed**: Add `delegators(publicKey: PublicKey!)` GraphQL query returning `[{publicKey, balance, delegatedBalance}]`.

### 4. No Multi-Node Failover Support
No mechanism for running primary + backup block producers safely. No double-signing protection at protocol or tooling level.

**Proposed**: Document best practices. Consider a `--failover-mode` that only produces blocks if primary is unreachable (requires consensus coordination).

### 5. Hardware Wallet Limitations
VRF evaluation from hardware wallets is explicitly unsupported (`mina_graphql.ml:2681`). Block producers cannot use Ledger Nano in production for the full signing flow.

**Proposed**: Long-term goal to support VRF evaluation on hardware wallets. Short-term: document this limitation clearly.

### 6. No Key Rotation Procedure
No tooled or documented procedure for rotating block producer keys without missing blocks.

**Proposed**:
1. Document the manual procedure (create new key, delegate to new key, wait 2 epochs, switch)
2. Add `mina accounts rotate-bp-key` command that automates the process

### 7. Fee Estimation Missing
No built-in fee estimation. Operators set fees manually with no guidance on appropriate values.

**Proposed**: Add `mina client estimate-fee` that checks recent transactions in the mempool and suggests a competitive fee.

## SDK Gaps

| Gap | Impact | Effort |
|-----|--------|--------|
| No Python SDK | Medium (many operators use Python for tooling) | High |
| No Rust SDK | Low-Medium (specialized use cases) | High |
| No offline transaction builder (OCaml) | Medium (scripting, automation) | Medium |
| No standalone proof verifier binary | Low | Medium |
| No batch account query | Medium (delegation tracking) | Small |
| No streaming account state changes | Medium (real-time monitoring) | Medium |
| GraphQL schema undocumented | High (all API consumers) | Medium |

## Priority Recommendations

1. **Slot schedule export** --- highest impact for block producers, small-medium effort
2. **Delegation visibility query** --- high demand from staking pool operators
3. **GraphQL schema documentation** --- benefits all API consumers
4. **Expected rewards calculator** --- frequently requested by community
5. **Key rotation documentation** --- operational safety improvement

## Effort Estimate

Individual items: 1-5 days each. Full suite: 2-4 weeks.
