# SNARK Worker and SNARK Pool — High-Level Implementation Guide

This document describes how the SNARK worker and SNARK pool subsystems are
designed, how they interact with each other and with the rest of the Mina
daemon, and where to find the relevant source files.

---

## Background

Mina uses a [scan state](./GLOSSARY.md#scan-state) — a tree of pending proof
jobs — to amortize the cost of proving transactions. Whenever a new block is
added, the block producer must supply one or two
[completed-work](./GLOSSARY.md#completed-work) bundles to "pay" for the new
transactions it includes. These proofs are produced asynchronously by *SNARK
workers* (see [snark work](./GLOSSARY.md#snark-work)) and collected in the
*SNARK pool*.

---

## Component Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Mina Daemon                                                                │
│                                                                             │
│  ┌──────────────┐       ┌───────────────────┐      ┌──────────────────────┐│
│  │ Work Selector│──────►│ Work Partitioner  │─RPC─►│  SNARK Worker        ││
│  │              │       │                   │◄─RPC─│  (integrated or      ││
│  └──────────────┘       └───────────────────┘      │   standalone)        ││
│          ▲                        │                 └──────────────────────┘│
│          │ pending_work           │ add_work (combined result)              │
│          │                        ▼                                         │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                         SNARK Pool                                    │  │
│  │   snark_tables.all  /  snark_tables.rebroadcastable                   │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
│          │                        ▲                                         │
│          │ completed proofs       │ gossip (Add_solved_work diffs)          │
│          ▼                        │                                         │
│  ┌──────────────┐         ┌───────────────────┐                            │
│  │Block Producer│         │  Gossip Network   │                            │
│  └──────────────┘         └───────────────────┘                            │
│                                   ▲                                         │
│                           other Mina nodes                                  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Key Source Directories

| Component | Location |
|-----------|----------|
| SNARK worker library | `src/lib/snark_worker/` |
| Standalone worker executable | `src/lib/snark_worker/standalone/` |
| Work selector | `src/lib/work_selector/` |
| Work partitioner | `src/lib/work_partitioner/` |
| SNARK pool | `src/lib/network_pool/snark_pool.ml` |
| Network pool base | `src/lib/network_pool/network_pool_base.ml` |

---

## Work Selector

**Source:** `src/lib/work_selector/`

The work selector maintains a view of the scan state's pending proof jobs and
decides which ones to hand out to SNARK workers.  Three selection strategies
are available (`Random`, `Sequence`, `Random_offset`).

The selector also consults the SNARK pool to avoid handing out work that
already has a proof.  Work is represented as a `Snark_work_lib.Selector.Single.Spec.t`
(a `Transition` proof or a `Merge` of two existing proofs).

---

## Work Partitioner

**Source:** `src/lib/work_partitioner/`

The work partitioner sits between the work selector and the SNARK worker RPC
layer.  It breaks work-selector units into smaller chunks for individual workers
and re-combines partial results into full proofs.

For detailed documentation, see the module's own README at
`src/lib/work_partitioner/README.md`.

---

## SNARK Worker

**Source:** `src/lib/snark_worker/`

### Integrated vs. Standalone

The SNARK worker can run either:

- **Integrated** – as a child process spawned by the daemon when
  `--run-snark-worker <pubkey>` is passed.  The daemon uses `Entry.main` to
  start the polling loop.
- **Standalone** – as an independent executable
  (`src/lib/snark_worker/standalone/run_snark_worker.exe`) that reads a work
  spec from the command line and submits the result to a daemon's GraphQL
  endpoint.

### Worker Loop (`entry.ml`)

```
loop:
  1. Read optional 'snark_coordinator' file to discover daemon address
  2. Call Get_work RPC  →  receive Spec.Partitioned.t option
     • None  →  nap for ~5 s with jitter, then repeat
     • Some spec  →
         3. Call Prod.Impl.perform_partitioned
            • Full proof level: run Transaction_snark prover
            • Check / No_check: return a dummy proof
         4. On success: call Submit_work RPC
            • `Ok        →  loop
            • `Removed   →  loop  (work was reassigned or no longer needed)
            • `SpecUnmatched → loop (shape mismatch, log warning)
         5. On failure: call Failed_to_generate_snark RPC, then loop
```

### Proof Generation (`prod.ml`)

`perform_partitioned` dispatches on the spec variant:

- **`Single { spec }`** – delegates to `perform_single_untimed`, which handles:
  - `Transition (stmt, witness)` – calls `Transaction_snark.of_non_zkapp_command_transaction`
    or, for ZK-app commands, runs the segment-prove-and-merge pipeline.
  - `Merge (stmt, p1, p2)` – calls `Transaction_snark.merge`.
- **`Sub_zkapp_command { spec = Segment … }`** – proves a single ZK-app segment
  via `Transaction_snark.of_zkapp_command_segment_exn`.
- **`Sub_zkapp_command { spec = Merge … }`** – merges two sub-zkapp proofs.

Large ZK-app proofs are written to disk via `Proof_cache_tag` to keep memory
usage bounded.

### RPC Protocol

| RPC name | Caller → Callee | Query type | Response type |
|----------|-----------------|-----------|---------------|
| `get_work` (V3) | Worker → Daemon | `unit` | `Spec.Partitioned.t option` |
| `submit_work` (V3) | Worker → Daemon | `Result.Partitioned.t` | `` `Ok ``, `` `Removed ``, or `` `SpecUnmatched `` |
| `failed_to_generate_snark` (V3) | Worker → Daemon | `(Wrapped_error.t * Id.Any.t)` | `unit` |

Versioning follows [RFC 0013](../rfcs/0013-rpc-versioning.md).

---

## SNARK Pool

**Source:** `src/lib/network_pool/snark_pool.ml`

### Storage

The pool stores proofs in two maps keyed by `Transaction_snark_work.Statement.t`
(one or two `Transaction_snark.Statement.t` values):

| Map | Contents |
|-----|----------|
| `snark_tables.all` | Every accepted proof (`Priced_proof.t`) |
| `snark_tables.rebroadcastable` | Locally-generated proofs pending inclusion in a block |

### Proof Acceptance (`verify_and_act`)

Before a proof is added to the pool, the following checks are performed:

1. **Fee sufficiency** – The prover's fee must cover the account-creation
   fee if the prover does not yet have an account.
2. **Prover permissions** – The prover account (if it exists) must allow
   receiving fees.
3. **Statement referenced** – The scan-state slot must still be needed by
   at least one block in the current transition frontier.
4. **Statement match** – The proof statement must match the claimed statement.
5. **Cryptographic validity** – The proof is verified via `Batcher.Snark_pool`
   (batched for efficiency).

A proof replaces an existing proof for the same statement only if its fee is
**strictly lower** (fee competition).

### Transition Frontier Integration

The pool subscribes to two broadcast pipes:

- **Refcount updates** (`Snark_pool_refcount` extension) – remove proofs whose
  scan-state slots are no longer referenced.
- **Best-tip diffs** – re-check prover fees and permissions against the new
  best-tip ledger after each chain reorganisation.

### Gossip

Accepted proofs are broadcast to peers as `Add_solved_work` diffs.  Locally
generated proofs are re-broadcast periodically until they appear in a block.
Incoming gossip diffs are rate-limited and peers are penalised (via the trust
system) for sending invalid proofs.

---

## End-to-End Flow

1. A new block arrives; the scan state is updated with new pending proof jobs.
2. The **work selector** reads these pending jobs and produces `Single.Spec.t`
   work items.
3. The **work partitioner** partitions each item into one or more
   `Spec.Partitioned.t` chunks and makes them available via `Get_work` RPC.
4. A **SNARK worker** polls `Get_work`, receives a chunk, generates a proof
   (`perform_partitioned`), and calls `Submit_work`.
5. The partitioner combines partial results; when a full proof unit is ready it
   calls `Mina_lib.add_work`.
6. `add_work` creates an `Add_solved_work` diff, calls
   `Resource_pool.Diff.unsafe_apply`, and gossips the diff to peers.
7. The **SNARK pool** stores the proof.
8. When the **block producer** assembles a new block, it reads from the SNARK
   pool to fill scan-state slots and removes used proofs via
   `remove_solved_work`.

---

## Configuration

| Daemon flag | Default | Description |
|-------------|---------|-------------|
| `--run-snark-worker <pubkey>` | (none) | Enable the integrated SNARK worker |
| `--snark-worker-fee <fee>` | 1 (nanomina) | Fee charged per proof |
| `--work-selection seq\|rand\|roffset` | `rand` | Work selection strategy |
| `--work-reassignment-wait <ms>` | 420000 ms | Timeout before a job is reassigned |

---

## Further Reading

- `src/lib/snark_worker/README.md` – SNARK worker library details
- `src/lib/network_pool/README.md` – Network pool and SNARK pool details
- `src/lib/snark_worker/standalone/README.md` – Standalone worker usage
- `rfcs/0013-rpc-versioning.md` – RPC versioning conventions
- `rfcs/0039-snark-keys-management.md` – SNARK key management
