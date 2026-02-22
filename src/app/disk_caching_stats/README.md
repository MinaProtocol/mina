# Disk Caching Statistics Tool

The Disk Caching Statistics (`disk_caching_stats`) tool is a utility for analyzing
memory usage and serialization performance in the Mina codebase, with a primary
focus on ZkApp-related data structures. It computes the expected worst-case memory
usage of the daemon before and after applying the disk caching changes proposed in
[RFC 56: Reducing Daemon Memory Usage](../../rfcs/0056-reducing-daemon-memory-usage.md).

## Features

- RAM usage estimation for various data structures in the Mina protocol
- Serialization benchmarking for critical data types
- Analysis of pre-fix and post-fix memory optimization impacts
- Estimates of serialization overhead for key protocol operations
- Memory profiling for transaction pools, snark pools, and scan states

## Prerequisites

- OCaml development environment
- Mina codebase
- OPAM package dependencies for Mina

## Compilation

To build the utility:

```
dune build src/app/disk_caching_stats/disk_caching_stats.exe
```

## Usage

Run the executable to see memory usage estimations and serialization performance:

```
_build/default/src/app/disk_caching_stats/disk_caching_stats.exe
```

The tool requires no command-line arguments. The `Params` module in the source code
contains parameters for the computation, which can be changed before recompiling
the program to produce different results.

## Technical Notes

The tool counts the size of GC allocations on various data structures used by the daemon
by carefully ensuring every value is a unique allocation with no shared references
within data structures. It transports values back and forth via bin_prot, simulating 
the same behavior the daemon will have when it reads and deserializes data from the 
network.

These measurements are then used to estimate the expected worst-case memory footprint
of larger data structures in the system, such as the mempools and the frontier.
Expectations around shared references across these larger data structures are
directly subtracted from the estimates.

The tool focuses on analyzing several key aspects of Mina's memory usage:

1. **Data Structure Sizes**: Measures memory footprint of key data types like:
   - ZkApp commands and proofs
   - Ledger proofs
   - Transaction witnesses
   - Verification keys

2. **Memory Usage Categories**:
   - Baseline daemon memory usage
   - Scan state memory requirements
   - Ledger mask memory usage
   - Staged ledger diff storage
   - Snark pool memory usage
   - Transaction pool memory usage

3. **Serialization Performance**:
   - Measures write/read times for key data structures
   - Calculates hash computation overhead
   - Estimates overall serialization impact on protocol operations

4. **Memory Optimization Assessment**:
   - Compares pre-optimization and post-optimization memory usage
   - Quantifies impact of content-addressed storage techniques

The tool helps protocol developers understand memory bottlenecks, optimize
serialization code, and make informed decisions about protocol parameters that
affect memory usage.
