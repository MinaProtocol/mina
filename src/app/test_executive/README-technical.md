# Test Executive Technical Reference

The Test Executive is a comprehensive integration testing framework for the Mina
protocol. It provides a structured environment for running various integration
tests that verify different aspects of the Mina blockchain, such as peer
reliability, payment processing, and ZkApp functionality.

## Features

- Modular test architecture with pluggable test implementations
- Supports multiple test execution engines (currently local Docker-based)
- Comprehensive test suite covering various aspects of the Mina protocol
- Detailed test reporting with color-coded error categorization
- Live monitoring of node status during test execution
- Graceful cleanup of test resources upon completion or failure

## Prerequisites

- OCaml development environment
- Mina codebase
- OPAM package dependencies for Mina
- Docker (for local engine tests)
- Docker Compose (for local engine tests)

## Compilation

To build the utility:

```
dune build src/app/test_executive/test_executive.exe
```

## Usage

```
_build/default/src/app/test_executive/test_executive.exe local TEST_NAME --mina-image MINA_IMAGE [--archive-image ARCHIVE_IMAGE] [--debug]
```

### Arguments:

- `local`: Currently the only supported engine
- `TEST_NAME`: Name of the test to run (see available tests below)
- `--mina-image`: Docker image for Mina nodes (required)
- `--archive-image`: Docker image for archive nodes (required for tests using archive nodes)
- `--debug`: Enable debug mode with paused cleanup on failure

### Available Tests:

- `peers-reliability`: Tests the reliability of peer connections
- `chain-reliability`: Tests the reliability of the blockchain
- `payments`: Tests payment processing
- `gossip-consis`: Tests gossip consistency
- `medium-bootstrap`: Tests bootstrapping of nodes
- `zkapps`: Tests basic ZkApp functionality
- `zkapps-timing`: Tests timing aspects of ZkApps
- `zkapps-nonce`: Tests account nonce behavior with ZkApps
- `verification-key`: Tests verification key updates
- `block-prod-prio`: Tests block production priority
- `block-reward`: Tests block reward distribution
- `hard-fork`: Tests hard fork procedures
- `epoch-ledger`: Tests epoch ledger management
- `slot-end`: Tests slot end behavior

### Example:

```
_build/default/src/app/test_executive/test_executive.exe local payments \
  --mina-image gcr.io/o1labs-192920/mina-daemon:1.3.0 \
  --archive-image gcr.io/o1labs-192920/mina-archive:1.3.0
```

## Environment Variables

- `MINA_IMAGE`: Can be used instead of the `--mina-image` flag
- `ARCHIVE_IMAGE`: Can be used instead of the `--archive-image` flag

## Technical Notes

The Test Executive uses a modular architecture with several key components:

1. **Test Implementation**: Each test implements the `Intf.Test.Functor_intf` interface,
   defining the test configuration and execution logic.

2. **Test Engine**: The engine handles deployment and management of the test environment.
   Currently, only the `local` engine is supported, which uses Docker for test execution.

3. **Domain-Specific Language (DSL)**: The DSL provides high-level abstractions for
   interacting with the test network, such as waiting for conditions, sending transactions,
   and monitoring node status.

4. **Error Handling**: The framework uses a sophisticated error handling system that
   categorizes errors as "hard" or "soft" and provides detailed reporting.

5. **Event Routing**: An event routing system allows tests to respond to events from
   the network, such as nodes going offline or new blocks being produced.

When a test is run, the Test Executive:

1. Initializes the test environment and network
2. Starts all required nodes (seeds first, then non-seed nodes)
3. Waits for all nodes to initialize
4. Executes the specific test logic
5. Collects and reports errors
6. Cleans up resources

The framework is designed to handle interruptions gracefully, cleaning up resources
even if the test is terminated prematurely.

## For Test Developers

To create a new test, you need to:

1. Create a new module in `src/app/test_executive/` that implements the `Intf.Test.Functor_intf` interface
2. Define a `config` function that specifies the network configuration
3. Implement the `run` function containing the test logic
4. Add the test to the `tests` list in `test_executive.ml`

The DSL provides various utilities for test implementation:

- `wait_for`: Waits for specific conditions in the network
- Network state access through `network_state`
- Node interaction through the `Node` module
- Error tracking and reporting

## Exit Codes

The Test Executive uses the following exit codes:

- Exit code `4`: Not all pods were assigned to nodes and ready in time
- Exit code `5`: Some pods could not be found
- Exit code `6`: Subscriptions, Topics, or Log sinks could not be created
- Exit code `20`: Testnet nodes hard timed-out on initialization