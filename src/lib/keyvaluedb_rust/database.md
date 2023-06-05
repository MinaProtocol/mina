
# Database, a Rust-based lightweight key value store for the Mina blockchain state


## Table of Contents
1. [Introduction](#Introduction)
2. [How Mina stores blockchain state in its ledger](#How-Mina-stores-blockchain-state-in-its-ledger)
3. [A custom-built key-value store for Mina](#A-custom-built-key-value-store-for-Mina)
4. [Try it out yourself](#Try-it-out-yourself)

  
## Introduction

To enhance the overall performance of a blockchain node, one of the primary areas to focus on is the storage that contains the blockchain state. Regular and ongoing access to this storage by the node is necessary for the validation of new blocks. By optimizing the speed of the storage module, we can greatly reduce the time it takes to apply new blocks and thus improve the overall performance of the node.

In Mina, the blockchain state is stored in the format of a Merkle tree. For rapid reading and writing to the blockchain state, it is vital to create a high-performance Merkle tree storage system.

## How Mina stores blockchain state in its ledger

In Mina, the current state of the network is kept in a data structure called the _ledger_. The ledger contains information about all the accounts in the network and their balances. Every time transactions from a block are applied, a new updated version of the ledger is produced.

These various versions of the ledger that result from applying blocks are kept in the _transition frontier_, which contains all the intermediary states of a subset of the blockchain, from the latest block up to k=290 parents.

In Mina, these structures are manipulated and kept in-memory, and need to be reconstructed whenever the node restarts. This usually requires the node to sync up to the network by making requests to other peers to get the data required to reconstruct the ledger.

However, nodes that have previously synchronized to the network keep a local on-disk copy of the _epoch ledgers_, that is, a snapshot of the ledger at the beginning of an epoch. When this snapshot is present, the nodes can skip some of the work required to sync up to the network by reusing this already available state.

These snapshots of the ledger are stored on-disk by using RocksDB, a database library that provides key-value storage.

Additionally, RocksDB is used to store:

-   **The state of the trust system,** which keeps a record of the peer’s trust score
-   **The transitions (blocks)** that must be re-applied to reconstruct the synced in-memory state
-   **The current best tip**
-   **Protocol state data and scan state**
-   **Auxiliary data** that is required to reconstruct the transition frontier

While RocksDB is an excellent database, it was not suitable for our use case because it is intended for general purposes. RocksDB has many features that are not necessary in our use case — we only utilize it as a key-value store.

While the RocksDB store has been useful thus far, we want to create a custom solution that maximizes the node’s efficiency and performance. We wanted to reduce its size on disk, and remove our dependency on RocksDB, which would allow us to build (compile from source code into an executable program) Mina faster.

## A custom-built key-value store for Mina

For these reasons, we’ve replaced RocksDB with _Database_, a custom-built Rust-based key-value store. Database is a lightweight, single append-only file, key-value store that has improved performance. Storage data is now saved into the file system, which grants us more control and oversight for C++, increasing the node’s security. The new database follows the same API as the previous `rocksdb` package, making it a drop-in replacement.

The database is a single append-only file, where each entry (key-value) are preceded by a header. Each entry in the Database has the following structure:

![image](https://github.com/openmina/mina/assets/60480123/1295ac9f-d182-4933-ab7c-b1b81333f6b0)


We are using compression on both keys and values with the library `zstd`. This provides the following advantages:

-   **Space Efficiency**: Compression significantly reduces the amount of storage space required for our data.
-   **Improved I/O Efficiency**: Data compression improves I/O efficiency by reducing the amount of data that needs to be read from or written to disk. Since disk I/O tends to be one of the slowest operations in a database system, anything that reduces I/O can have a significant impact on performance.
-   **Cache Utilization**: By compressing data, more of it can fit into the database’s cache. This increases cache hit rates, meaning that the database can often serve data from fast memory, leading to better performance.
-   **Reduced Latency**: With smaller data sizes due to compression, the time taken for disk reads and writes is lowered.

The compression makes the biggest difference on the transition frontier:

-   With RocksDB, the frontier takes **245 MB** on disk.
-   With our Rust implementation, takes **140 MB**.

Although we’ve replaced the storage, we still use the same format (`binprot`) for encoding the Merkle tree as well as the accounts. To validate data integrity, we use `crc32`.

The design of the Rust-based storage is based on information by performance-related data. This includes a redesign and improvement upon the implementation of the on-disk ledger (and possibly other similar data stores) used by the Mina node software.

This employs techniques such as removing wasteful copying, delaying the application of actions until commit, optimizing space usage, and more.

## Try it out yourself

Use the instructions from the readme to build Mina with the new storage:

[mina/README.md at ledger-ondisk · openmina/mina ](https://github.com/openmina/mina/blob/ledger-ondisk/src/lib/keyvaluedb_rust/README.md "https://github.com/openmina/mina/blob/ledger-ondisk/src/lib/keyvaluedb_rust/README.md")[](https://github.com/openmina/mina/blob/ledger-ondisk/src/lib/keyvaluedb_rust/README.md)

  

The development of the new Database storage module is the first step to improving the Mina ledger, and by removing the hard dependency on RocksDB, it brings us one step closer to developing storage support for the Mina [web node](https://openmina.com/web-node).

We thank you for taking the time to read this article. If you have any comments, suggestions or questions, feel free to contact me directly by email. To read more about OpenMina and the Mina Web Node, subscribe to our [Medium](https://medium.com/openmina) or visit our [GitHub](https://github.com/openmina/openmina).
