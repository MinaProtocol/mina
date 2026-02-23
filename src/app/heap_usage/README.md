# Heap Usage Analysis Tool

The Heap Usage (`heap_usage`) tool is a utility for analyzing the memory 
footprint of various data structures in the Mina protocol. It provides detailed 
measurements of heap memory consumption for key components, helping developers 
understand the memory requirements of the protocol and identify potential 
optimization opportunities.

## Features

- Measures and reports heap usage of critical Mina data structures
- Reports both heap word count and byte size for each data structure
- Analyzes complex structures including ZkApp commands, proofs, and verification keys
- Evaluates memory consumption of scan state components
- Helps identify memory-intensive structures for optimization

## Prerequisites

- OCaml development environment
- Mina codebase
- OPAM package dependencies for Mina

## Compilation

To build the utility:

```
dune build src/app/heap_usage/heap_usage.exe
```

## Usage

Run the executable to see memory usage statistics for various data structures:

```
_build/default/src/app/heap_usage/heap_usage.exe
```

The tool requires no command-line arguments and will output memory usage 
information for key data structures in a tabular format.

## Example Output

```
Data of type Account.t (w/ zkapp)                       uses   1253 heap words =    10024 bytes
Data of type Zkapp_command.t                            uses  33245 heap words =   265960 bytes
Data of type Pickles.Side_loaded.Proof.t                uses   7862 heap words =    62896 bytes
Data of type Mina_base.Side_loaded_verification_key.t   uses    965 heap words =     7720 bytes
Data of type Dummy Pickles.Side_loaded.Proof.t          uses    115 heap words =      920 bytes
Data of type Dummy Mina_base.Side_loaded_verification_key.t uses    41 heap words =     328 bytes
Data of type Ledger.Db.path.t                           uses    259 heap words =     2072 bytes
Data of type Protocol_state.t                           uses   1151 heap words =     9208 bytes
Data of type Pending_coinbase.t                         uses    249 heap words =     1992 bytes
Data of type Staged_ledger_diff.t (payments)            uses   8711 heap words =    69688 bytes
Data of type Parallel_scan.Base.t (coinbase)            uses   2222 heap words =    17776 bytes
Data of type Parallel_scan.Base.t (payment)             uses   2363 heap words =    18904 bytes
Data of type Parallel_scan.Base.t (zkApp)               uses  47782 heap words =   382256 bytes
Data of type Parallel_scan.Merge.t                      uses   2455 heap words =    19640 bytes
Data of type Transaction_snark.Statement.t              uses    334 heap words =     2672 bytes
```

## Technical Notes

The Heap Usage tool operates by creating representative instances of each data
structure and measuring their memory consumption using OCaml's `Obj.size` and
`Obj.reachable_words` functions. 

Key data structures analyzed include:

1. **Account structures**: Standard accounts and accounts with ZkApps
2. **Transaction types**: Signed commands and ZkApp commands
3. **Cryptographic components**: Proofs, verification keys
4. **Ledger structures**: Merkle paths, pending coinbase records
5. **Consensus components**: Protocol state
6. **Transaction processing**: Scan state nodes, staged ledger differences

For ZkApp-related structures, the tool creates realistic examples with proofs and
multiple account updates to better reflect real-world memory usage patterns.

The memory measurements include both the direct size of the data structure (words
allocated to the structure itself) and reachable words (memory allocated to data
referenced by the structure), providing a comprehensive view of total memory
impact.

This tool is particularly valuable for identifying memory-intensive components
and guiding optimization efforts in memory-constrained environments like the
Mina daemon.