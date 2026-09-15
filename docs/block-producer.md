# Block producer

The **block producer** (also referred to as the *proposer*) is the subsystem
of the Mina daemon that is responsible for winning slots in the Ouroboros
Samasika proof-of-stake protocol and creating new blocks.  A node participates
in block production only when it is started with one or more block-producer
keypairs.

## Table of contents

- [Overview](#overview)
- [Architecture and key modules](#architecture-and-key-modules)
- [VRF evaluation](#vrf-evaluation)
- [Block production scheduling](#block-production-scheduling)
- [Block production pipeline](#block-production-pipeline)
  - [1. Staged-ledger diff creation](#1-staged-ledger-diff-creation)
  - [2. Consensus transition generation](#2-consensus-transition-generation)
  - [3. Blockchain SNARK proving](#3-blockchain-snark-proving)
  - [4. Breadcrumb construction and frontier insertion](#4-breadcrumb-construction-and-frontier-insertion)
  - [5. Network broadcast](#5-network-broadcast)
- [Genesis proof](#genesis-proof)
- [Configuration and context](#configuration-and-context)
- [Error handling](#error-handling)
- [Metrics and tracing](#metrics-and-tracing)
- [Running precomputed blocks](#running-precomputed-blocks)

---

## Overview

Block production in Mina is slot-based.  Time is divided into *epochs* (each
containing a fixed number of slots).  For each slot a node may or may not be
eligible to produce a block, depending on its stake weight and the outcome of a
VRF (Verifiable Random Function) evaluation.

At a high level, the block producer:

1. Asks the **VRF evaluator** (a separate worker process) which slots in the
   current epoch it has won.
2. Schedules a block-production task for the beginning of each won slot.
3. At the scheduled time, builds a new block on top of the current best tip:
   - Creates a staged-ledger diff from the pending transaction pool.
   - Generates the next consensus state and blockchain state.
   - Asks the **prover** (another separate worker process) to extend the
     recursive blockchain SNARK.
4. Inserts the resulting breadcrumb into the transition frontier and broadcasts
   the block to peers.

---

## Architecture and key modules

| Location | Purpose |
|---|---|
| `src/lib/block_producer/block_producer.ml` | Main block-producer loop and block-building logic |
| `src/lib/vrf_evaluator/vrf_evaluator.ml` | Out-of-process VRF evaluation worker |
| `src/lib/prover/intf.ml` | Interface for the out-of-process blockchain SNARK prover |
| `src/lib/consensus/proof_of_stake.ml` | `Consensus.Hooks.get_epoch_data_for_vrf`, `Consensus.Hooks.get_block_data`, `Consensus.Hooks.select`; `Consensus_state_hooks.generate_transition` |
| `src/lib/staged_ledger/staged_ledger.ml` | `create_diff`, `apply_diff_unchecked` |
| `src/lib/transition_frontier/transition_frontier.ml` | `Breadcrumb.build`, transition registry |
| `src/lib/mina_lib/mina_lib.ml` | Wires all components and calls `Block_producer.run` |

The block producer is started from `Mina_lib` once it has confirmed that at
least one block-producer keypair is configured:

```ocaml
Block_producer.run
  ~context ~vrf_evaluator ~prover ~verifier ~trust_system
  ~get_completed_work ~transaction_resource_pool
  ~time_controller ~consensus_local_state ~coinbase_receiver
  ~frontier_reader ~transition_writer ~set_next_producer_timing
  ~log_block_creation ~block_reward_threshold ~block_produced_bvar
  ~vrf_evaluation_state ~net ~zkapp_cmd_limit_hardcap
```

---

## VRF evaluation

Slot eligibility is decided by a VRF: the producing node evaluates the VRF
with its private block-producer key and the epoch randomness, and wins the slot
if the output falls below a threshold proportional to its delegated stake.

Because VRF evaluation is computationally expensive, it is performed in a
dedicated worker process (`Vrf_evaluator`).  The main producer loop interacts
with the evaluator through two RPCs:

- `set_new_epoch_state` – sends the epoch number, staking ledger snapshot, and
  keypairs for the new epoch so the worker can begin evaluating slots.
- `slots_won_so_far` – polls the worker to retrieve the list of slots won so
  far (`Slot_won.t list`) together with the evaluator's progress status
  (`At global_slot | Completed`).

The `Vrf_evaluation_state` module inside `block_producer.ml` manages a FIFO
queue of won slots returned by the evaluator.  Slots are dequeued one at a
time and used to schedule block production.

**Epoch transition:** At the start of each epoch (detected by comparing epoch
numbers), `update_epoch_data` is called to send the new epoch's data to the
VRF evaluator and to reset the evaluation state.

---

## Block production scheduling

![Block production finite state machine](https://raw.githubusercontent.com/MinaProtocol/mina-resources/main/docs/res/block_production_fsm.png)

The core scheduling loop is `check_next_block_timing` (called recursively).
On every invocation it:

1. **Checks bootstrap mode** – if the transition frontier is not yet available
   (node is bootstrapping), the loop waits until the frontier appears.
2. **Retrieves epoch data** – calls
   `Consensus.Hooks.get_epoch_data_for_vrf` on the best-tip consensus state to
   obtain the current epoch and ledger snapshot.
3. **Updates the VRF evaluator** – if the epoch has advanced, sends the new
   epoch data and polls for won slots.
4. **Dequeues the next won slot** and decides what to do:
   - **Slot has already passed:** skip it and check again immediately
     (`next_vrf_check_now`).
   - **Slot is the current slot:** produce a block immediately
     (`produce_block_now`).
   - **Slot is in the future:** schedule production for the beginning of that
     slot using `Singleton_scheduler`.
   - **No more slots in this epoch:** schedule the next check for the epoch
     boundary.

Two helper types manage concurrency:

- **`Singleton_supervisor`** – ensures that at most one block-production task
  is running at any time.  Dispatching a new task cancels any in-progress one.
- **`Singleton_scheduler`** – a single `Block_time.Timeout` wrapper that
  reschedules itself to the minimum of any two requested times.

---

## Block production pipeline

The `produce` function executes the following steps inside an
`Interruptible.t` (so that production can be cancelled by the scheduler when a
new slot arrives or the chain tip changes):

### 1. Staged-ledger diff creation

```ocaml
Staged_ledger.create_diff
  ~constraint_constants ~global_slot staged_ledger ~logger
  ~coinbase_receiver ~current_state_view ~transactions_by_fee
  ~get_completed_work ~log_block_creation ~supercharge_coinbase
  ~zkapp_cmd_limit
```

Transactions are taken from the **transaction resource pool** (mempool) in
fee-priority order.  Completed SNARK work is obtained via `get_completed_work`.
The resulting diff is validated immediately by applying it to a temporary copy
of the staged ledger (`apply_diff_unchecked`).

Two optional limits can suppress transaction inclusion:

- `slot_tx_end` – beyond this global slot the producer emits empty blocks
  (no transactions).
- `slot_chain_end` – beyond this global slot the producer stops producing
  entirely.

If a `block_reward_threshold` is configured and the net coinbase reward of the
diff falls below it, an empty diff is substituted instead.

### 2. Consensus transition generation

```ocaml
Consensus_state_hooks.generate_transition
  ~previous_protocol_state ~blockchain_state ~current_time
  ~block_data ~supercharge_coinbase ~snarked_ledger_hash
  ~genesis_ledger_hash ~supply_increase ~logger ~constraint_constants
```

This call produces the next `Protocol_state` (combining `Blockchain_state` and
`Consensus_state`) together with the `Consensus_transition_data` needed for
the SNARK.  The blockchain state timestamp is set to the **beginning** of the
scheduled slot (not the current wall-clock time) so that minor delays do not
shift the producer into the next slot.

The resulting structures are packaged into an `Internal_transition` and a
`Snark_transition`.

### 3. Blockchain SNARK proving

```ocaml
Prover.prove prover
  ~prev_state:previous_protocol_state
  ~prev_state_proof:previous_protocol_state_proof
  ~next_state:protocol_state
  internal_transition pending_coinbase_witness
```

The `Prover` is a long-running child process that holds the proving keys in
memory.  The call is dispatched asynchronously and awaited inside the
`Interruptible` context.  Prover failures are logged and the produced block is
silently discarded (the loop continues).

Concurrently, a **delta block chain proof** is constructed from the transition
frontier:

```ocaml
Transition_chain_prover.prove
  ~length:consensus_constants.delta ~frontier previous_state_hash
```

This proof covers the last `delta` blocks and is included in the block header
so that light clients can verify chain continuity.

### 4. Breadcrumb construction and frontier insertion

The fully-proved block is wrapped into a `Header` + `Body` pair and validated
through the `Validation` pipeline (genesis state hash check, frontier
dependency check, etc.).  Proof validation is skipped here with
`` `This_block_was_generated_internally ``.

```ocaml
Breadcrumb.build
  ~logger ~precomputed_values ~verifier ~get_completed_work ~trust_system
  ~parent:crumb ~transition ~sender:None
  ~skip_staged_ledger_verification:`Proofs
  ~transition_receipt_time ~transaction_pool_proxy ()
```

The breadcrumb is written to `transition_writer` (a `Strict_pipe`).  The
producer then waits up to 20 seconds for the transition frontier to confirm
insertion via `Transition_registry`.  If the timeout fires, a fatal log is
emitted but production continues.

**Conflict handling:** if a block for the same slot arrives from the network
before the producer's own block is ready, the producer detects the collision
(same `global_slot_since_genesis` as best tip) and builds its block on top of
the best tip's *parent* instead.

### 5. Network broadcast

Once the breadcrumb is accepted into the frontier, the block is broadcast to
peers:

```ocaml
Mina_networking.broadcast_state net
  (Breadcrumb.block_with_hash breadcrumb
   |> With_hash.map ~f:Mina_block.read_all_proofs_from_disk)
```

---

## Genesis proof

When the node produces its very first block at height 1 (building on the
genesis breadcrumb), it needs a proof for the genesis protocol state.  The
`genesis_breadcrumb_creator` function lazily generates this proof via the
prover the first time it is needed, caching the result in an `Ivar`.  The
proof generation is retried up to 3 times on failure.

To avoid delaying block production, the genesis proof is pre-generated in the
slot *before* the won slot using `generate_genesis_proof_if_needed`.

---

## Configuration and context

The block producer is parameterised by the `CONTEXT` module type:

| Field | Description |
|---|---|
| `logger` | Structured logger |
| `precomputed_values` | Precomputed proving keys and genesis data |
| `constraint_constants` | Protocol constraint constants |
| `consensus_constants` | Slot/epoch durations, delta, etc. |
| `commit_id` | Git commit hash (included in error reports) |
| `zkapp_cmd_limit` | Optional per-block zkApp command count limit (mutable) |
| `vrf_poll_interval` | How long to wait between VRF evaluator polls |
| `proof_cache_db` | On-disk cache for serialised proofs |
| `signature_kind` | `Mainnet` or `Testnet` signature domain separator |

Runtime configuration also influences behaviour:

- `Runtime_config.slot_tx_end` – last slot that includes transactions.
- `Runtime_config.slot_chain_end` – last slot for block production.

---

## Error handling

| Error | Handling |
|---|---|
| VRF evaluator RPC failure | Retried up to 3 times (`retry` helper); daemon keeps running |
| Genesis proof generation failure | Retried up to 3 times; block production is deferred |
| Prover failure (`Prover_error`) | Error logged; produced block discarded; loop continues |
| Invalid genesis protocol state | Warning logged; block discarded |
| Block already in frontier | Error logged; block discarded |
| Block not selected over frontier root | Warning logged; block discarded (can happen during catch-up) |
| Parent missing from frontier | Warning logged; block discarded (can happen during catch-up) |
| Invalid staged ledger hash/diff | Exception raised (fatal) |
| Transition frontier insertion timeout | Fatal log emitted; loop continues anyway |

Failed transactions that could not be applied to the staged ledger during diff
creation are reported to the error collection service via
`report_transaction_inclusion_failures` (see `Node_error_service.send_dynamic_report`).

---

## Metrics and tracing

The block producer records the following Prometheus metrics (defined in
`src/lib/mina_metrics/`):

| Metric | Type | Description |
|---|---|---|
| `Block_producer.slots_won` | Counter | Number of slots won by the VRF |
| `Block_producer.blocks_produced` | Counter | Number of blocks successfully produced |
| `Block_producer.block_production_delay` | Histogram | Wall-clock delay between scheduled slot start and actual broadcast |

Internal tracing events (emitted via `[%log internal]` / `O1trace`) include:

- `Begin_block_production`
- `Get_transactions_from_pool`
- `Generate_next_state` / `Generate_next_state_done`
- `Create_staged_ledger_diff` / `Create_staged_ledger_diff_done`
- `Apply_staged_ledger_diff` / `Apply_staged_ledger_diff_done`
- `Hash_new_staged_ledger` / `Hash_new_staged_ledger_done`
- `Produce_state_transition_proof`
- `Produce_chain_transition_proof`
- `Produce_validated_transition`
- `Send_breadcrumb_to_transition_frontier`
- `Wait_for_confirmation` / `Transition_accepted` / `Transition_accept_timeout`
- `@produced_block_state_hash` (annotated with the new block's state hash)
- `@block_metadata` (annotated with blockchain length and transaction list)

---

## Running precomputed blocks

`Block_producer.run_precomputed` is a separate entry point used by the
**replayer** tool.  Instead of evaluating the VRF and building blocks from the
mempool, it reads pre-recorded `Precomputed_block.t` values from a pipe and
re-applies them to the ledger, verifying each against the transition frontier.
This path skips VRF evaluation and SNARK proving (the proofs are taken directly
from the precomputed block) but still runs full breadcrumb validation.
