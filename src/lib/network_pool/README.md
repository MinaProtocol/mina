# Transaction Pool (Txn_pool)

A pool of transactions (user commands) that can be included in future blocks.
Combined with the network pool module, this handles storing and gossiping
transactions and providing them to the block producer code.

The transaction pool exists to bridge two activities:

1. **Accepting transactions**: Users submit transactions via the client RPC,
   and peers gossip transactions they receive. The pool validates and stores
   these commands until they are included in a block.
2. **Supplying transactions to block producers**: When a block producer creates
   a new block, it draws the highest-fee transactions from the pool (via
   `transactions`, which returns commands in descending fee-per-weight-unit
   order).

## Glossary

| Name | Description |
|------|-------------|
| User command | A transaction submitted by a user; either a `Signed_command` (payment or stake delegation) or a `Zkapp_command` (zkApp transaction) |
| Fee per weight unit (fee/wu) | A normalized fee rate used to compare and rank transactions of different sizes |
| Nonce | A per-account sequence number that orders transactions from the same sender and prevents replay attacks |
| Diff | A list of user commands sent between nodes over the gossip network. Applying a diff adds the commands to the local pool |
| Best tip | The highest-scoring block known to this node, as tracked by the transition frontier |
| Best tip ledger | The account ledger state at the best tip block, used to validate pool contents |
| Transition frontier | The in-memory data structure that tracks all known recent blocks; the transaction pool subscribes to its diffs to stay in sync |
| Breadcrumb | A fully expanded block state stored in the transition frontier |
| Backtracking | Removing commands from the pool that were included in a now-abandoned fork (chain reorganization), so they can be re-added |
| Locally generated | Transactions that originated on this node (submitted via the local RPC), tracked separately so they can be preferentially re-added after reorganizations |
| Replace-by-fee | A mechanism that lets a sender replace a pending transaction with a higher-fee one that has the same nonce |
| Verification key (VK) | A zkApp-specific piece of data required to verify a zkApp proof; the pool maintains a reference-counted table of VKs used by pending commands |

## Architecture

The transaction pool is implemented as two layered components:

```
┌─────────────────────────────────────────────────────────────────┐
│  Transaction_pool  (transaction_pool.ml)                        │
│  ─ accepts/rejects gossip diffs (verify → apply)                │
│  ─ responds to transition frontier diffs                        │
│  ─ tracks locally generated commands                            │
│  ─ punishes misbehaving peers via the trust system              │
│                                                                 │
│   ┌─────────────────────────────────────────────────────────┐   │
│   │  Indexed_pool  (indexed_pool.ml)                        │   │
│   │  ─ purely functional data structure                     │   │
│   │  ─ multiple indices for efficient lookup                │   │
│   │  ─ enforces per-sender nonce ordering                   │   │
│   │  ─ tracks currency reserved per sender                  │   │
│   └─────────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────────┘
```

### Indexed Pool

Defined in `indexed_pool.ml` / `indexed_pool.mli`. This is a **purely
functional** data structure that stores all pending commands and exposes
efficient operations. It maintains the following indices simultaneously:

| Index | Key | Purpose |
|-------|-----|---------|
| `applicable_by_fee` | fee/wu → command set | Commands that can immediately be applied (head of each sender queue); used to iterate in descending fee order |
| `all_by_fee` | fee/wu → command set | All commands; used to find and evict the lowest-fee command when the pool is full |
| `all_by_sender` | account id → (command sequence × reserved amount) | All commands per sender, in strict nonce order; used to check validity and to cascade removals |
| `all_by_hash` | transaction hash → command | Lookup by hash; used for membership checks and deduplication |
| `transactions_with_expiration` | expiry slot → command set | Only commands with a finite `valid_until` field; used to sweep expired commands efficiently |

**Invariants** (checked by `For_tests.assert_pool_consistency`):
- A command is in `all_by_fee` if and only if it is in `all_by_sender` and
  in `all_by_hash`.
- A command is in `applicable_by_fee` if and only if it is the head (lowest
  nonce) of its sender's queue in `all_by_sender`.
- Each sender's queue is strictly ordered by nonce with no gaps.
- The `reserved_currency` stored alongside each sender queue equals the sum
  of fees and payment amounts of all queued commands.
- There are no empty sets or sequences stored in any index.

### Resource Pool (Transaction_pool.Make0)

Defined in `transaction_pool.ml`. This is a **mutable** wrapper around the
`Indexed_pool`. It manages:

- The underlying `Indexed_pool.t`
- Asynchronous batch verification of incoming commands via the `Batcher`
- A reference-counted table of verification keys used by zkApp commands
  (`Vk_refcount_table`)
- Separate hash tables for locally generated uncommitted and committed
  commands (`locally_generated_uncommitted`, `locally_generated_committed`)
- Subscription to transition frontier best-tip diffs

## Key Operations

### Adding a Transaction from Gossip

When a peer gossips a diff (a list of user commands), the pool processes it
in two asynchronous phases:

1. **`verify` (asynchronous)**: The diff is checked for well-formedness, the
   best tip ledger is consulted for existence, and commands are converted to a
   verifiable form. Signatures and zkApp proofs are then verified in batches by
   the `Batcher`. This phase must not mutate pool state.

2. **`apply` (synchronous)**: After verification succeeds, each command is
   checked against the current pool state and ledger (fee payer existence and
   send permission), then handed to `Indexed_pool.add_from_gossip_exn`. If
   adding the command would push the pool over its maximum size, the lowest-fee
   commands are evicted (`drop_until_below_max_size`). Commands from local
   senders are registered in `locally_generated_uncommitted`.

If verification fails (bad signature or invalid proof), the sending peer is
penalised via the trust system.

### Replacing a Transaction

A sender can replace a pending command that has the same nonce if the new
command's fee is strictly higher than the existing one by at least
`replace_fee` (1 nanomina). `Indexed_pool.add_from_gossip_exn` handles this
automatically: it returns the replaced command(s) in the "dropped" sequence.

### Handling Transition Frontier Diffs

The transaction pool subscribes to best-tip changes from the transition
frontier. Each diff carries a list of newly committed commands (`new_commands`)
and a list of commands removed from the best tip due to a reorganization
(`removed_commands`).

The handler (`handle_transition_frontier_diff_inner`) performs these steps:

1. **Backtrack** (chain reorg): Re-add `removed_commands` to the pool via
   `Indexed_pool.add_from_backtrack`. These must be supplied in
   newest-to-oldest order. Commands that conflict with the new best tip ledger
   are discarded.

2. **Revalidate**: Call `Indexed_pool.revalidate` on the subset of accounts
   referenced by the diff. Commands that are no longer valid (wrong nonce,
   insufficient balance, etc.) against the new best tip ledger are removed.

3. **Commit**: Commands that appear in `new_commands` are moved from
   `locally_generated_uncommitted` to `locally_generated_committed`.

4. **Re-add locally generated** commands that were dropped during backtracking
   if they still have sufficient fee and are valid against the new ledger.

5. **Sweep expired** commands via `Indexed_pool.remove_expired`.

When the transition frontier is recreated from scratch (e.g., after a restart),
the entire pool is revalidated against the new best tip ledger.

### Pool Size Management

The pool has a configurable maximum size (`pool_max_size`). When a new command
is added and the pool exceeds this limit, the command with the globally lowest
fee-per-weight-unit (and all commands from the same sender with higher nonces)
are evicted via `Indexed_pool.remove_lowest_fee`. This continues until the pool
is within its size limit.

Separately, the verified diff pipeline between verification and application has
bounded capacity. If the pipe overflows (i.e., verified diffs arrive faster than
they can be applied), the entire diff is dropped and every command in it is
rejected with the `Overloaded` error. This is handled by the `on_overflow`
callback in `pool_sink.ml`, which calls `reject_overloaded_diff` (defined in
`transaction_pool.ml`).

> **Note**: `pool_max_size` should be kept consistent across gossiping nodes.
> Nodes with a larger pool limit may forward many low-fee transactions that
> smaller-pool nodes consider useless, leading to those nodes banning the
> sender.

### Expiration

Each user command may carry a `valid_until` slot (a `Global_slot_since_genesis`
value). Commands are rejected at add time if their `valid_until` has already
passed. The pool also proactively removes all expired commands whenever a
best-tip diff is processed, using `Indexed_pool.remove_expired`.

## Transaction Validation Errors

When a command cannot be added to the pool, one of the following `Diff_error`
values is returned:

| Error | Meaning |
|-------|---------|
| `Insufficient_replace_fee` | The command has the same nonce as a pooled command but its fee is not high enough to replace it |
| `Duplicate` | The exact same command is already in the pool |
| `Invalid_nonce` | The command's nonce is not in the valid range given the sender's current ledger nonce and queued commands |
| `Insufficient_funds` | The sender's liquid balance is insufficient to cover fees and amounts of all queued commands including this one |
| `Overflow` | Summing fees or amounts would overflow |
| `Bad_token` | The command uses a non-default token in a context that requires the default token |
| `Unwanted_fee_token` | The command pays fees in a non-default token that this pool does not accept |
| `Expired` | The command's `valid_until` slot has already passed |
| `Overloaded` | The verified diff pipeline overflowed; the entire diff was dropped before it could be applied to the pool |
| `Fee_payer_account_not_found` | The fee payer account does not exist in the best tip ledger |
| `Fee_payer_not_permitted_to_send` | The fee payer account's permissions do not allow sending or nonce increments |
| `After_slot_tx_end` | The current slot is past the network-configured `slot_tx_end` (used for controlled network shutdown) |

Errors that indicate misbehaviour (`Overflow`, `Bad_token`,
`Unwanted_fee_token`) are considered grounds for rejecting the entire diff and
penalising the sender.

## Locally Generated Commands

Transactions submitted via this node's own RPC (as opposed to received from
peers) are tracked in two mutable reference-wrapped maps (functional
`Transaction_hash.Map.t` values inside `ref` cells), keyed by transaction hash:

- **`locally_generated_uncommitted`**: Commands that are in the pool but have
  not yet been included in the best tip. Each entry stores the time of
  submission, a batch number, and the command itself.
- **`locally_generated_committed`**: Commands that have been included in the
  best tip. These are retained so the node can detect if they are later rolled
  back by a chain reorganization.

During a reorganization, the pool attempts to re-add locally generated commands
that were evicted during backtracking, preferring to keep the node's own
transactions in the pool even when other transactions are dropped for space.

## DoS Protection

The transaction pool includes several layers of protection against
denial-of-service attacks:

1. **Rate limiting**: The `Resource_pool_diff_intf` specifies a
   `max_per_15_seconds = 10` capacity parameter. This is combined with a
   15-second window to compute a rate, which is then projected over the
   underlying `rate_limiter.ml` sliding window (5 minutes). The result is a
   score-based budget per peer that refills as older entries age out of the
   5-minute window, rather than a strict 15-second bucket.
2. **Pool size cap**: `pool_max_size` bounds memory usage. Low-fee transactions
   are evicted when the cap is reached, making it expensive to fill the pool
   with junk.
3. **Trust system**: Peers that send invalid proofs or other provably malicious
   diffs are penalised via `Trust_system.record_envelope_sender`. Repeated
   violations lead to the peer being ignored.
4. **Replace-by-fee cost**: Replacing an existing transaction requires a fee
   premium (`replace_fee`), preventing cheap churn attacks.
5. **Currency reservation**: The pool tracks the total currency reserved per
   sender across all queued commands. A command is rejected if the sender does
   not have enough liquid balance to cover all pending commands, preventing
   senders from flooding the pool with commands they cannot execute.

## zkApp Support

zkApp commands (`Zkapp_command`) require verification keys (VKs) to validate
their proofs. The `Vk_refcount_table` inside the resource pool keeps track of
which VKs are referenced by pending pool commands, with reference counts so
that a VK is only evicted from cache when no pending commands reference it
anymore. VKs are loaded from both the best tip ledger and the in-memory table
when verifying incoming zkApp commands.

---

# SNARK Pool

The SNARK pool stores completed zero-knowledge proofs (transaction snarks)
produced by SNARK workers.  The block producer reads from this pool when
constructing a new block: it needs one or two proofs per scan-state slot it
wants to fill.

## High-Level Design

```
SNARK worker ──Submit_work RPC──► Work Partitioner ──add_work──► Work Selector
                                                                        │
                                                                 lookup in snark pool
                                                                        │
                                                                  Snark Pool (this module)
                                                                        │
                                                              ◄── gossip (libp2p)
```

The snark pool is a **functor** (`Make`) parameterised over:

- `Base_ledger` – the ledger type used to check prover-account existence and
  permissions.
- `Staged_ledger` – provides access to the active ledger via `ledger`.
- `Transition_frontier` – supplies the reference-counting extension and
  best-tip diff pipe.

The concrete instantiation at the bottom of `snark_pool.ml` applies the functor
to `Mina_ledger.Ledger`, `Staged_ledger`, and `Transition_frontier`.

## Internal State

`Resource_pool.t` holds two maps keyed by `Transaction_snark_work.Statement.t`:

| Field | Type | Description |
|-------|------|-------------|
| `snark_tables.all` | `Priced_proof.t Statement.Map.t` | Every proof currently in the pool |
| `snark_tables.rebroadcastable` | `(Priced_proof.t * Time.t) Statement.Map.t` | Locally-generated proofs eligible for re-broadcast |

## Lifecycle of a Proof

1. **Submission** – A SNARK worker submits a completed proof via
   `Submit_work` RPC.  The work partitioner combines partial sub-zkapp results
   and calls `Mina_lib.add_work`, which eventually calls
   `Resource_pool.Diff.unsafe_apply`.

2. **Verification** – `verify_and_act` checks:
   - The fee is high enough to cover account-creation cost (if the prover has no
     account yet).
   - The prover account has permission to receive fees.
   - The proof statement is still referenced by at least one block in the
     current transition frontier (i.e. the scan-state slot has not been pruned).
   - The proof statement matches the claimed statement.
   - The proof itself is cryptographically valid (via `Batcher.Snark_pool`).

3. **Acceptance** – If all checks pass and the statement is still *referenced*
   by the transition frontier, the proof is inserted into `snark_tables`.

4. **Gossip** – The diff (`Add_solved_work`) is broadcast to peers so they can
   add the proof to their own pool.

5. **Eviction** – Proofs are removed when:
   - The transition frontier signals that the corresponding scan-state slot is no
     longer referenced (`handle_refcount_update`).
   - A new best-tip ledger is applied and the prover's fee is no longer
     sufficient or the prover account lacks receive permission
     (`handle_new_best_tip_ledger`).
   - The block producer explicitly removes a proof once it has been included in a
     block (`remove_solved_work`).

## Transition Frontier Integration

The snark pool subscribes to two broadcast pipes from the transition frontier:

- **`snark_pool_refcount_pipe`** – carries `Snark_pool_refcount.view` diffs that
  list work statements that are no longer referenced.  Handled by
  `handle_refcount_update`.
- **`best_tip_diff_pipe`** – fires on every best-tip change; the pool re-checks
  prover fees/permissions against the new best-tip ledger.

## Fee Competition

When a new proof arrives for a statement that already has a proof in the pool,
`Diff.unsafe_apply` accepts the new proof only if its fee is **strictly lower**
than the existing one.  This lets SNARK workers compete on fees, driving the
market price of proofs down.

## Re-broadcast

Locally-generated proofs (i.e. proofs submitted by the node's own SNARK worker)
are tracked separately in `snark_tables.rebroadcastable`.  The network pool base
layer periodically calls `get_rebroadcastable` to re-gossip these proofs until
they appear in a block.

For a high-level description of how the SNARK pool interacts with SNARK workers
and the rest of the daemon, see
[docs/snark-worker-and-pool.md](../../../docs/snark-worker-and-pool.md).

---

# Shared Infrastructure

## `network_pool_base.ml`

`Network_pool_base.Make` wraps a `Resource_pool_base_intf` and adds:

- A gossip-network sink that receives diffs from peers, verifies them, and
  applies them to the resource pool.
- Periodic re-broadcast of locally-generated resources.
- Rate limiting and trust-system integration.

## `batcher.ml`

Batches verification requests (signature/proof checks) to the verifier process
for efficiency.  Both `Batcher.Transaction_pool` and `Batcher.Snark_pool`
variants are provided.

## `intf.ml`

Defines the key interfaces:

- `Resource_pool_base_intf` – mutable pool that can be updated via diffs.
- `Resource_pool_diff_intf` – a mutation to apply to a resource pool.
- `Snark_resource_pool_intf` – snark-pool-specific extension of the base pool
  interface.
- `Network_pool_base_intf` – the full network-pool interface including gossip.

## Code Directory

| File | Description |
|------|-------------|
| `transaction_pool.ml` | The main mutable resource pool: gossip verification/application, transition frontier diff handling, locally generated tracking |
| `indexed_pool.ml` / `indexed_pool.mli` | Purely functional multi-indexed data structure underlying the pool |
| `batcher.ml` / `batcher.mli` | Batches signature and proof verification requests for efficiency |
| `locally_generated.ml` / `locally_generated.mli` | Mutable map (ref-wrapped `Transaction_hash.Map.t`) tracking locally submitted commands and their submission metadata |
| `rate_limiter.ml` / `rate_limiter.mli` | Per-sender rate limiting for incoming gossip diffs |
| `command_error.ml` | Error type for `Indexed_pool` operations (distinct from the network-level `Diff_error`) |
| `network_pool_base.ml` | Generic network pool infrastructure shared by the transaction pool and snark pool |
| `intf.ml` | Module type signatures for resource pools and their diffs |
| `snark_pool.ml` / `snark_pool.mli` | Pool for completed SNARK work (shares infrastructure with the transaction pool) |
| `f_sequence.ml` / `f_sequence.mli` | Finger-tree-based functional sequence used for per-sender command queues |
| `writer_result.ml` | General-purpose writer+result monad that threads an accumulated log of written values (`Tree.t`) alongside a `Result.t`; used in the indexed pool context to accumulate `Update.t` values during pool operations |
| `with_nonce.ml` | Helper for commands annotated with a specific nonce |
| `mocks.ml` | Mock implementations of ledger, staged ledger, and transition frontier for use in tests |
| `priced_proof.ml` | Type pairing a SNARK proof with its associated fee and prover (used by the snark pool) |
| `snark_pool_diff.ml` | Diff implementation for the SNARK pool: defines how solved-work entries are gossiped and applied |
| `pool_sink.ml` | Sink infrastructure for receiving and dispatching pool diffs: handles verification throttling, rate limiting, pipe overflow, and provides both active and void (no-op) sink variants |
| `test.ml` | Top-level test registration for the network pool (snark pool tests) |
| `test/` | Unit tests for the indexed pool and transaction pool |
