# Network Pool

This directory contains the *network pool* infrastructure used by the Mina
daemon.  A network pool is a replicated, gossip-backed in-memory data structure
that holds resources — pending transactions or completed SNARK proofs — that
nodes share with one another.

Two concrete pools are implemented here:

| Pool | Module | Purpose |
|------|--------|---------|
| Transaction pool | `transaction_pool.ml` | Pending signed-commands and ZK-app commands waiting to be included in a block |
| SNARK pool | `snark_pool.ml` | Completed transaction proofs submitted by SNARK workers |

---

## SNARK Pool

### Purpose

The SNARK pool stores completed zero-knowledge proofs (transaction snarks)
produced by SNARK workers.  The block producer reads from this pool when
constructing a new block: it needs one or two proofs per scan-state slot it
wants to fill.

### High-Level Design

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

### Internal State

`Resource_pool.t` holds two maps keyed by `Transaction_snark_work.Statement.t`:

| Field | Type | Description |
|-------|------|-------------|
| `snark_tables.all` | `Priced_proof.t Statement.Map.t` | Every proof currently in the pool |
| `snark_tables.rebroadcastable` | `(Priced_proof.t * Time.t) Statement.Map.t` | Locally-generated proofs eligible for re-broadcast |

### Lifecycle of a Proof

1. **Submission** – A SNARK worker submits a completed proof via
   `Submit_work` RPC.  The work partitioner combines partial sub-zkapp results
   and calls `Mina_lib.add_work`, which eventually calls
   `Resource_pool.Diff.unsafe_apply`.

2. **Verification** – `verify_and_act` checks:
   - The fee is high enough to cover account-creation cost (if the prover has no
     account yet).
   - The prover account has permission to receive fees.
   - The proof statement matches the claimed statement.
   - The proof itself is cryptographically valid (via `Batcher.Snark_pool`).

3. **Acceptance** – If all checks pass and the statement is still *referenced*
   by the transition frontier (i.e. referenced by at least one block in the
   frontier), the proof is inserted into `snark_tables`.

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

### Transition Frontier Integration

The snark pool subscribes to two broadcast pipes from the transition frontier:

- **`snark_pool_refcount_pipe`** – carries `Snark_pool_refcount.view` diffs that
  list work statements that are no longer referenced.  Handled by
  `handle_refcount_update`.
- **`best_tip_diff_pipe`** – fires on every best-tip change; the pool re-checks
  prover fees/permissions against the new best-tip ledger.

### Fee Competition

When a new proof arrives for a statement that already has a proof in the pool,
`Diff.unsafe_apply` accepts the new proof only if its fee is **strictly lower**
than the existing one.  This lets SNARK workers compete on fees, driving the
market price of proofs down.

### Re-broadcast

Locally-generated proofs (i.e. proofs submitted by the node's own SNARK worker)
are tracked separately in `snark_tables.rebroadcastable`.  The network pool base
layer periodically calls `get_rebroadcastable` to re-gossip these proofs until
they appear in a block.

---

## Shared Infrastructure

### `network_pool_base.ml`

`Network_pool_base.Make` wraps a `Resource_pool_base_intf` and adds:

- A gossip-network sink that receives diffs from peers, verifies them, and
  applies them to the resource pool.
- Periodic re-broadcast of locally-generated resources.
- Rate limiting and trust-system integration.

### `batcher.ml`

`Batcher.Snark_pool` batches proof-verification requests to the verifier process
for efficiency.

### `intf.ml`

Defines the key interfaces:

- `Resource_pool_base_intf` – mutable pool that can be updated via diffs.
- `Resource_pool_diff_intf` – a mutation to apply to a resource pool.
- `Snark_resource_pool_intf` – snark-pool-specific extension of the base pool
  interface.
- `Network_pool_base_intf` – the full network-pool interface including gossip.

---

For a high-level description of how the SNARK pool interacts with SNARK workers
and the rest of the daemon, see
[docs/snark-worker-and-pool.md](../../../docs/snark-worker-and-pool.md).
