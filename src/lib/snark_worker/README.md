# Snark Worker Library

This directory contains the Mina SNARK worker library implementation. The SNARK
worker is responsible for generating zero-knowledge proofs (SNARKs) required by
the Mina protocol.

## Overview

The SNARK worker operates as either:

1. An integrated service within the Mina daemon
2. A standalone process (see the [`standalone/`](./standalone/) directory)

SNARK workers generate proofs for transactions and receive fees for their work,
creating an economic incentive for proof generation in the Mina network.

A SNARK coordinator is a Mina node exposing a "server" endpoint accessible by SNARK workers, implementing all RPCs necessary. These endpoints are defined in function `setup_local_server` in `src/app/cli/src/init/mina_run.ml`. The RPCs include requesting work specs, submitting completed proofs, and reporting failures via `failed_to_generate_snark`.

## What is a work?

The exact definition of a "work" differs before and after the Mesa HF.

### Before Mesa HF

A SNARK work is one or two single works, where a single work is either requesting a proof for a transaction (command, fee transfer, or coinbase), or a proof that is a merge of 2 proofs. The snark worker should return one or two proofs corresponding to the single work.

### After Mesa HF

A SNARK work is anything that requires generating one proof, which is one of: a proof for a non-zkApp command, a proof for a zkApp segment, or a proof that merges 2 proofs. The snark worker should return one proof exactly.

With Mesa HF, we can utilize more parallelism on SNARK workers, hence the number of segments per zkApp command is less relevant for proof generation latency.

## High-Level Design

The SNARK worker follows a simple polling loop:

1. **Request work** – The worker calls `Get_work` RPC on the daemon to obtain a
   `Spec.Partitioned.t`. The daemon's *work partitioner* partitions pending
   scan-state jobs into individually-provable chunks before handing them out.

2. **Generate proof** – `Prod.Impl.perform_partitioned` drives the actual proof
   generation.  Depending on the configured proof level it either:
   - Runs the full SNARK prover (`Transaction_snark`) for a `Single` spec or a
     `Sub_zkapp_command` segment/merge spec, or
   - Returns a dummy proof when the proof level is `Check` or `No_check`.

3. **Submit result** – The worker calls `Submit_work` RPC on the daemon with the
   completed `Result.Partitioned.t`.  The daemon's work partitioner combines
   partial sub-zkapp results and, once a full work unit is assembled, adds it to
   the snark pool.

4. **Report failures** – If proof generation fails, the worker calls
   `Failed_to_generate_snark` RPC so the daemon can reassign the work to another
   worker.

The worker retries all RPC calls with jitter-based back-off.  When no work is
available it naps for a randomised interval to avoid busy-polling.

### Worker State

`Prod.Impl.Worker_state.t` is created once at startup and holds:

- The proof-level variant (`Full`, `Check`, or `No_check`) together with the
  instantiated `Transaction_snark` module.
- A proof-cache database (`Proof_cache_tag.cache_db`) for storing intermediate
  ZK-app segment proofs to disk, avoiding out-of-memory issues for large ZK-app
  commands.
- Logger and signature-kind configuration.

## Library Structure

- `snark_worker.ml` – Top-level module re-exporting RPCs, entry point, and the
  production implementation.
- `intf.ml` – Legacy interface signatures (`Work_S` / `Rpcs_versioned_S`) from
  the original RPC design.  The current RPC protocol is defined in the individual
  `rpc_*.ml` modules using `Spec.Partitioned` / `Result.Partitioned` types.
- `prod.ml` – Production implementation: `Worker_state` creation and the
  `perform_partitioned` / `perform_single` proof-generation functions.
- `entry.ml` – The `main` polling loop and the `command_from_rpcs` CLI command
  used by the integrated worker.
- `events.ml` – Structured-log event definitions.
- `rpc_get_work.ml` – Versioned RPC definition for requesting work from the
  daemon.
- `rpc_submit_work.ml` – Versioned RPC definition for submitting completed
  proofs to the daemon.
- `rpc_failed_to_generate_snark.ml` – Versioned RPC definition for reporting
  proof-generation failures.

## Standalone Worker

For information about the standalone SNARK worker executable, see the
[standalone README](./standalone/README.md).

## Usage

The library is primarily used:

1. Internally by the Mina daemon (`entry.ml` / `command_from_rpcs`) to run an
   integrated SNARK worker process.
2. By external SNARK workers that connect to a Mina daemon via the versioned RPC
   protocol to perform proof generation independently.

SNARK workers communicate with the Mina daemon via versioned RPCs:

| RPC | Direction | Purpose |
|-----|-----------|---------|
| `Get_work` | Worker → Daemon | Poll for a partitioned work spec |
| `Submit_work` | Worker → Daemon | Submit a completed proof |
| `Failed_to_generate_snark` | Worker → Daemon | Report a proof-generation error |

For a high-level description of how the SNARK worker interacts with the SNARK
pool and the rest of the daemon, see
[docs/snark-worker-and-pool.md](../../../docs/snark-worker-and-pool.md).
