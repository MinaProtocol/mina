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

## Library Structure

- `snark_worker.ml/mli` - Main implementation and interface
- `intf.ml` - Core interfaces for the SNARK worker
- `functor.ml` - Functor for creating SNARK worker implementations
- `prod.ml` - Production implementation of the SNARK worker
- `rpcs.ml` - RPC definitions for communication between daemon and worker
- `debug.ml` - Debugging utilities

### RPCs

The SNARK worker communicates with the daemon through three main RPCs defined in
`rpcs.ml`:

1. **Get_work**
   - Request work from the daemon
   - Query: `unit` (no input needed)
   - Response: Optional tuple containing work specification and public key
   - Used by workers to request SNARK work to process

2. **Submit_work**
   - Submit completed SNARK work to the daemon
   - Query: Work result containing the completed proof
   - Response: `unit` (success acknowledgment)
   - Used by workers to return completed proofs to the daemon

3. **Failed_to_generate_snark**
   - Report failure in SNARK generation
   - Query: Error information, work specification, and public key
   - Response: `unit` (acknowledgment)
   - Used by workers to report errors during proof generation

## Standalone Worker

For information about the standalone SNARK worker executable, see the
[standalone README](./standalone/README.md).

## Usage

The library is primarily used:

1. Internally by the Mina daemon to process SNARK work
2. By external SNARK workers that connect to a Mina daemon to perform proof
   generation

SNARK workers communicate with the Mina daemon via a set of versioned RPCs for
requesting work and submitting completed proofs.
