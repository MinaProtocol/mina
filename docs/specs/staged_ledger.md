# Staged Ledger and Snarked Ledger Specification

This document specifies the staged ledger and snarked ledger in Mina, how each
is structured, and how the two interact. It is intended to give external teams
and protocol implementors enough detail to work with Mina proofs independently.

## Table of Contents

1. [Glossary](#glossary)
2. [Snarked Ledger](#snarked-ledger)
3. [Staged Ledger](#staged-ledger)
   - [Ledger](#ledger)
   - [Scan State](#scan-state)
   - [Pending Coinbase Collection](#pending-coinbase-collection)
4. [Staged Ledger Hash](#staged-ledger-hash)
5. [Staged Ledger Diff](#staged-ledger-diff)
6. [Block Application](#block-application)
   - [Generating a Diff](#generating-a-diff-create_diff)
   - [Applying a Diff](#applying-a-diff-apply)
7. [Fee Structure](#fee-structure)
   - [Fee Excess](#fee-excess)
   - [Coinbase Splitting](#coinbase-splitting)
8. [Invariants](#invariants)

---

## Glossary

| Term | Description |
|------|-------------|
| **Snarked ledger** | A Merkle ledger state whose correctness has been certified by a ledger proof (i.e., a transaction SNARK). |
| **Staged ledger** | The current blockchain state combining a Merkle ledger (containing all applied transactions, both proven and unproven) with the scan state and pending coinbase collection. |
| **Ledger** | A Merkle-tree-backed mapping from account addresses to account states; the Merkle root is the *ledger hash*. See [Merkle Tree spec](merkle_tree.md). |
| **Scan state** | A forest of binary trees that tracks SNARK work required to certify every transaction in the chain. See [Scan State](#scan-state). |
| **Pending coinbase collection** | A collection that tracks coinbase recipients and protocol state for each block in the chain. |
| **Transaction SNARK / proof** | A zero-knowledge proof that certifies applying a set of transactions to a ledger is valid. |
| **Ledger proof** | A transaction SNARK emitted by the scan state that certifies a ledger state resulting from applying all transactions in a completed scan state tree. |
| **Snark work** | A bundle of at most two proofs submitted by a snark worker; defined in `src/lib/transaction_snark_work/transaction_snark_work.ml`. |
| **Work statement / statement** | A fact about the ledger state that is proven by a transaction SNARK. |
| **Snark worker** | A Mina node that generates transaction SNARKs for a fee. |
| **User command** | A user-submitted transaction: a payment, stake delegation, or zkApp transaction. |
| **Fee transfer** | A synthetic transaction created by block producers to pay transaction fees or snark fees. |
| **Coinbase** | A synthetic transaction created by block producers to reward themselves for producing a block. |
| **Protocol state** | Representation of the state of a block; defined in `src/lib/mina_state/protocol_state.ml`. |
| **Protocol state view** | Selected fields from the protocol state needed to update the staged ledger. |
| **Frozen ledger hash** | The Merkle root of a snarked ledger; used as the `snarked_ledger_hash` field in protocol state. |
| **Staged ledger hash** | A hash that commits to the complete staged ledger state: its ledger hash, scan state auxiliary hash, and pending coinbase. |

---

## Snarked Ledger

A **snarked ledger** is a Merkle ledger state whose correctness has been fully
certified by a ledger proof. It represents the most recent ledger state for
which every applied transaction has been verified by a SNARK.

### Representation

A snarked ledger is identified by its **frozen ledger hash** — the Merkle root
of the underlying Merkle ledger (see [Merkle Tree spec](merkle_tree.md)).
The frozen ledger hash is carried in the blockchain state as
`snarked_ledger_hash` and is updated only when the scan state emits a new
ledger proof.

The full snarked ledger state (as captured in `Snarked_ledger_state`) records
the following top-level fields:

| Field | Description |
|-------|-------------|
| `source` | A `Registers.t` representing the ledger state before the proven transactions. |
| `target` | A `Registers.t` representing the ledger state after the proven transactions. |
| `connecting_ledger_left` | Ledger hash connecting the left boundary of the proof. |
| `connecting_ledger_right` | Ledger hash connecting the right boundary of the proof. |
| `supply_increase` | The increase in total currency supply from coinbase rewards. |
| `fee_excess` | The net fee excess that must balance to zero across a completed tree. |
| `sok_digest` | A "statement of knowledge" digest binding the proof to the prover. |

Each `Registers.t` contains `first_pass_ledger`, `second_pass_ledger`,
`pending_coinbase_stack`, and `local_state`. Note that `local_state` is not a
top-level field of the snarked ledger state; it is nested inside each register.

This structure makes it possible to chain ledger proofs across blocks without
replaying all transactions.

### When the Snarked Ledger Hash Advances

The snarked ledger hash advances when the scan state emits a **ledger proof**
for a completed scan state tree:

1. The scan state emits a `ledger_proof` covering a set of transactions.
2. The snarked ledger is updated by applying those transactions (using a
   two-pass application process) to the current snarked ledger.
3. The new Merkle root of the updated snarked ledger becomes the new
   `snarked_ledger_hash` recorded in the protocol state of that block.

If no ledger proof is emitted for a block, the `snarked_ledger_hash` in the
protocol state remains unchanged.

---

## Staged Ledger

A **staged ledger** is the intermediate ledger state that tracks all
transactions included in blocks — whether or not those transactions have been
fully proven yet. It is the primary data structure that block producers update
when creating a new block.

A staged ledger comprises three components:

1. **Ledger** — The Merkle ledger with all transactions applied (proven and unproven).
2. **Scan state** — Tracks outstanding SNARK work needed to prove those transactions.
3. **Pending coinbase collection** — Records coinbase recipients and protocol states per block.

### Ledger

The staged ledger's underlying Merkle ledger (`src/lib/mina_ledger/ledger.ml`)
contains all transactions from the chain ending at a given block, including
those not yet covered by a ledger proof. This ledger is always ahead of the
snarked ledger.

Key properties:
- Its Merkle root is the **ledger hash** component of the staged ledger hash.
- It is updated atomically when a staged-ledger-diff is applied.
- It is implemented as a maskable Merkle tree, supporting layered views for
  fork management without copying full ledger state. (See [Merkle Tree
  spec](merkle_tree.md) for mask semantics.)

### Scan State

The **scan state** (`src/lib/transaction_snark_scan_state/`) is a forest of
binary trees. Its purpose is to schedule and track SNARK work so that every
transaction in the staged ledger eventually gets certified by a ledger proof.

#### Structure

The scan state is a queue of full binary trees. Each tree has:
- **Base nodes** (leaves): hold `Transaction_with_witness.t`, representing
  transactions that need initial SNARK proofs.
- **Merge nodes** (internal): hold `Ledger_proof_with_sok_message.t`,
  representing the recursive composition of two child proofs.
- A **root merge node** whose proof, once complete, is the **ledger proof** for
  the set of transactions in that tree.

Two compile-time constants govern the scan state's size:

| Constant | Meaning |
|----------|---------|
| `scan_state_transaction_capacity_log_2` | Determines the maximum number of transactions per block: `2^scan_state_transaction_capacity_log_2`. Each tree has exactly this many leaves. |
| `work_delay` | Number of extra trees retained so snark workers have enough lead time before work is required. |

With these constants the scan state holds at most
`(scan_state_transaction_capacity_log_2 + 1) × (work_delay + 1) + 1` trees.

#### Job Types

Every node in the scan state is a **job** for a snark worker:

| Job type | Input | Output |
|----------|-------|--------|
| `Base` | A `Transaction_with_witness.t` | An initial transaction SNARK |
| `Merge` | Two child SNARKs | A merged SNARK |

The top-level merge job of a complete tree produces the **ledger proof**, which
is then returned by the scan state and used to advance the snarked ledger hash.

#### Update Protocol

On each block:

1. **New transactions** are transformed into `Base` jobs and added to leaves
   of the current unfilled tree (or a new tree if the current one is full).
2. **Completed snark work** from the block is added to the scan state as
   completed `Merge` jobs.
3. The scan state checks whether completing work on any tree's root yields a
   ledger proof; if so, that proof is emitted and the tree is removed from the
   forest.

The amount of work required per block is predetermined by the number and
positions of transaction slots being filled. The invariant ensures at most one
ledger proof is emitted per block, and that at most two proofs are needed per
transaction slot.

For a step-by-step visual walkthrough of the scan state, see
`src/lib/parallel_scan/scan_state.md`.

### Pending Coinbase Collection

The pending coinbase collection (`src/lib/mina_base/pending_coinbase.ml`) records, for each
block in the chain, the coinbase recipient and the protocol state. It is a
stack-based structure that allows the transaction SNARK to commit to the
coinbase value without including the full coinbase transaction in the SNARK
statement.

---

## Staged Ledger Hash

The **staged ledger hash** commits to the complete state of the staged ledger:

```
staged_ledger_hash = hash(non_snark_part, pending_coinbase_hash)
```

Where:
```
non_snark_part = { ledger_hash, aux_hash, pending_coinbase_aux }
```

| Field | Description |
|-------|-------------|
| `ledger_hash` | Merkle root of the staged ledger's underlying Merkle ledger. |
| `aux_hash` | Hash of the scan state serialization. Captures the state of all pending SNARK work. |
| `pending_coinbase_aux` | Auxiliary hash of the pending coinbase collection. |
| `pending_coinbase_hash` | Root hash of the full pending coinbase data structure. |

The `staged_ledger_hash` is included in every block's blockchain state, so
validators can verify that the staged ledger embedded in a block is consistent
with the transactions and snark work in the block.

Implementation: `src/lib/mina_base/staged_ledger_hash.ml`

---

## Staged Ledger Diff

A **staged-ledger-diff** (`src/lib/staged_ledger_diff/staged_ledger_diff.ml`)
describes all the changes made to the staged ledger by a single block.

At the top level, the diff type is `{ diff : Diff.t }`, where `Diff.t` is a
pair of prediffs:

```
Diff.t = Pre_diff_with_at_most_two_coinbase.t
       * Pre_diff_with_at_most_one_coinbase.t option
```

The first prediff is always present; the second is optional and used when the
diff must be split across two scan state trees to satisfy the fee-excess
invariant (see [Fee Excess](#fee-excess) below).

Each prediff contains the following fields:

| Field | Description |
|-------|-------------|
| `completed_works` | List of snark work (`Snark_work.t`) covering pending jobs in the scan state. |
| `commands` | List of user commands (payments, delegations, zkApp transactions) to apply. |
| `coinbase` | The coinbase transaction(s) for the block producer. The first prediff allows at most two coinbase parts (`At_most_two`); the second allows at most one (`At_most_one`). |
| `internal_command_statuses` | Statuses for internal commands (fee transfers, coinbase). |

---

## Block Application

### Generating a Diff (`create_diff`)

When a block producer creates a new block, it calls `create_diff` on the
current staged ledger. The function:

1. Selects user commands from the mempool in descending order of fees.
2. Fetches required snark work for the selected transactions from the snark pool.
3. Assembles a staged-ledger-diff satisfying:
   - Transaction count ≤ `2^scan_state_transaction_capacity_log_2`.
   - All transactions are valid against the current ledger.
   - Snark work included covers at least as many pending jobs as new
     transactions being added (approximately 2 proofs per transaction slot).
   - Snark fees are fully covered by transaction fees (or by the coinbase
     amount for the coinbase transaction).
   - Total fee excess within each prediff sums to zero (see [Fee
     Excess](#fee-excess)).

### Applying a Diff (`apply`)

When a node receives a block, it applies the staged-ledger-diff to its staged
ledger for that block's parent:

1. **Validate transactions**: Each user command, fee transfer, and coinbase is
   validated against the current ledger state and protocol state.
2. **Apply transactions**: All transactions are applied to the Merkle ledger,
   updating account balances and nonces.
3. **Validate and integrate snark work**: Each piece of completed snark work is
   verified against its statement. Valid work is added to the scan state,
   marking pending jobs as done and creating new merge jobs.
4. **Update pending coinbase**: The coinbase recipient and current block's
   protocol state are added to the pending coinbase collection.
5. **Emit ledger proof (if any)**: If completing the scan state work causes a
   tree to be fully proven, a ledger proof is emitted and the snarked ledger
   hash is updated.
6. **Compute new staged ledger hash**: The hash of the resulting staged ledger
   (ledger hash + aux hash + pending coinbase) is computed and checked against
   the hash claimed in the block header.

If any validation fails, the block is rejected.

`apply_diff_unchecked` is a variant used for diffs generated locally by the
node itself. It skips snark verification (since snark work is verified before
entering the snark pool) but still enforces all other invariants.

---

## Fee Structure

### Fee Excess

A **fee excess** field in each transaction SNARK statement tracks fees that
have been debited but not yet credited (or vice versa). Because transaction
fees and snark fees are paid via separate fee-transfer transactions, the excess
must balance out across all transactions in a completed scan state tree.

**Invariant**: The ledger proof emitted by any tree must have a **zero
fee excess** — all fees debited within that tree must be credited within the
same tree.

To satisfy this, `create_diff` splits the diff into two prediffs when needed:
- **Prediff 1**: Fills remaining empty leaves of the current (partially filled)
  tree with a self-contained set of transactions and fee transfers that net to
  zero fee excess.
- **Prediff 2**: Starts a new tree with the remaining transactions and fee
  transfers, again netting to zero.

Example (leaves of a tree, showing fee excess per position):

```
                         0          ← root (zero fee excess = valid ledger proof)
                 4               -4
             2       2        2        -6
          1    1   1    1   1    1   -2  -4
```

### Coinbase Splitting

A coinbase may be split into two parts when the first prediff has exactly two
slots remaining that cannot accommodate a user transaction. In that case:
- Two coinbase transactions are created, each taking one slot, dividing the
  coinbase reward.
- If only one slot remains, a single coinbase is added to prediff 1.
- If no slots remain after transactions, a single coinbase goes into prediff 2.
- If after adding all user transactions there is insufficient snark work for a
  coinbase in prediff 2, both prediffs are discarded and a single prediff is
  generated with a coinbase and as many user transactions as fit.

---

## Invariants

The following invariants are maintained at all times:

1. **Ledger consistency**: The staged ledger's Merkle ledger always reflects the
   result of applying every transaction in the scan state (both proven and
   unproven) to the snarked ledger.

2. **Scan state completeness**: For every transaction in the staged ledger there
   is a corresponding `Base` job in the scan state. The scan state is the
   authoritative record of pending SNARK work.

3. **Fee excess zero at tree root**: Every ledger proof emitted by the scan
   state has zero fee excess — all fees within a proven tree net to zero.

4. **At most one ledger proof per block**: The scan state structure guarantees
   that completing the work in a block can cause at most one tree to become
   fully proven, so at most one ledger proof is emitted per block.

5. **Snarked ledger hash monotonicity**: The `snarked_ledger_hash` in the
   protocol state is a function of the most recent emitted ledger proof. It
   only advances when a new proof is emitted and never goes backwards.

6. **Staged ledger hash commitment**: The `staged_ledger_hash` in the blockchain
   state fully commits to the staged ledger contents. Any modification to
   transactions, pending snark work, or the pending coinbase collection changes
   the hash, making tampering detectable.

---

## Related Source Files

| Path | Description |
|------|-------------|
| `src/lib/staged_ledger/staged_ledger.ml` | Main staged ledger implementation: `create_diff`, `apply`, `apply_diff_unchecked`. |
| `src/lib/staged_ledger_diff/staged_ledger_diff.ml` | Staged ledger diff type definition. |
| `src/lib/transaction_snark_scan_state/transaction_snark_scan_state.ml` | Scan state instantiated with transaction SNARKs. |
| `src/lib/parallel_scan/` | Abstract parallel scan data structure underlying the scan state. |
| `src/lib/parallel_scan/scan_state.md` | Detailed walkthrough of the scan state with worked examples. |
| `src/lib/mina_base/staged_ledger_hash.ml` | Staged ledger hash definition and computation. |
| `src/lib/mina_ledger/ledger.ml` | Core Merkle ledger implementation. |
| `src/lib/mina_base/frozen_ledger_hash.ml` | Frozen (snarked) ledger hash. |
| `src/lib/mina_state/blockchain_state.ml` | Blockchain state, including `staged_ledger_hash` and `snarked_ledger_hash`. |
| `src/lib/mina_state/snarked_ledger_state.ml` | Snarked ledger state structure used in ledger proofs. |
| `src/lib/mina_base/pending_coinbase.ml` | Pending coinbase collection implementation. |
| `src/lib/ledger_proof/ledger_proof.ml` | Ledger proof (wraps a `Transaction_snark.t`). |
