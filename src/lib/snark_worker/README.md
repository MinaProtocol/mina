# Snark Worker Library

The Snark Worker library provides infrastructure for creating and managing SNARK
workers in the Mina protocol. SNARK workers are specialized processes that
generate zero-knowledge proofs for transactions, allowing the blockchain to
maintain a small, constant-sized proof of the entire chain state.

## Overview

The Snark Worker system follows a client-server architecture where the Mina
daemon acts as a coordinator that distributes SNARK work to worker processes.
These workers connect to the daemon, request work, perform cryptographic proof
generation, and submit the completed proofs back to the daemon.

## Architecture

The library is structured into several key components:

### Core Components

1. **Worker Interface (`intf.ml`)**: Defines the contract that worker
   implementations must fulfill, specifying how to create worker state and
   perform SNARK work.

2. **Worker Implementations**:
   - **Production Implementation (`prod.ml`)**: The standard implementation used
     in the production environment, with full proof generation capabilities.
   - **Debug Implementation (`debug.ml`)**: A simplified implementation that can
     be used for testing and debugging.

3. **Entry Point (`entry.ml`)**: Provides the main interface for creating and
   running a SNARK worker process, including:
   - Command-line argument parsing
   - Connection handling with the daemon
   - Work retrieval and submission loop
   - Error handling and recovery

4. **RPC Communications**:
   - **Get Work (`rpc_get_work.ml`)**: RPC for requesting work from the daemon
   - **Submit Work (`rpc_submit_work.ml`)**: RPC for submitting completed proofs
   - **Failed to Generate SNARK (`rpc_failed_to_generate_snark.ml`)**: RPC for
     reporting failures

5. **Events (`events.ml`)**: Structured logging events for monitoring SNARK
   worker operations.

6. **Standalone Runner (`standalone/run_snark_worker.ml`)**: Provides an entry
   point for running a SNARK worker as a standalone process.

### Key Features

1. **Proof Level Configuration**: Workers can be configured with different proof
   levels:
   - `Full`: Generates complete, cryptographically secure proofs
   - `Check`: Performs verification checks without generating full proofs
   - `No_check`: Skips verification entirely (useful for testing)

2. **Caching**: The system implements caching to avoid redundant proof
   generation:
   - In-memory caching of recent proofs
   - Disk-based proof caching

3. **Zkapp Support**: Special handling for zkApp command transactions, which may
   require multiple proof segments

4. **Metrics and Monitoring**: Comprehensive metrics for tracking proof
   generation time and performance

5. **Error Handling**: Robust error reporting and retry mechanisms for handling
   failures

## Usage

### Starting a Snark Worker

Snark workers can be started using the `snark-worker` command with the following
options:

```bash
mina snark-worker --daemon-address HOST:PORT [options]
```

#### Required Options:

- `--daemon-address`: The address and port where the Mina daemon's SNARK
  coordinator is listening

#### Optional Options:

- `--proof-level`: The level of proving to perform (`full`, `check`, or `none`)
- `--shutdown-on-disconnect`: Whether to shut down when disconnected from the
  daemon (default: true)
- `--conf-dir`: Directory for configuration and logs

### Integrating with the Daemon

The Snark Worker follows this workflow:

1. Connect to the daemon (coordinator) via RPC
2. Request work using the `Get_work` RPC
3. If work is available, generate proofs for the provided work specification
4. Submit the completed work using the `Submit_work` RPC
5. If no work is available, wait and retry
6. If errors occur, report them and implement appropriate retry logic

## Performance Considerations

- SNARK proof generation is computationally intensive
- The library includes metrics to track proof generation time for different
  transaction types
- The caching system helps avoid redundant work
- Workers implement a wait-and-retry strategy when no work is available to avoid
  overwhelming the daemon

## Developers Guide

### Key Files and Their Purpose

- `snark_worker.ml`: Main module entry point exporting the library's components
- `intf.ml`: Core interfaces defining the worker contract
- `prod.ml`: Production implementation of the SNARK worker
- `entry.ml`: Main entry point and work loop
- `rpc_*.ml` files: RPC definitions for communication with the daemon
- `events.ml`: Structured logging events

### Adding New Features

When adding new functionality to SNARK workers:

1. Update the appropriate worker implementation (usually `prod.ml`)
2. Ensure proper error handling and metrics
3. Add appropriate logging using the structured events in `events.ml`
4. Consider versioning implications for any RPC changes

### Testing

The system can be tested with different proof levels:

- Use `--proof-level=check` or `--proof-level=none` for faster testing without
  full proof generation
- The library includes inline tests that can be run with dune