# Summary
[summary]: #summary

Refactor our codebase with consistent, correct, and descriptive names.

# Motivation
[motivation]: #motivation

There are a multitude of naming issues which plague our codebase. Some names are not consistent (`Statement` vs. `Work`), others are not correct (`Ledger` is not a ledger; there is no log of transactions). We also have some names that are not very descriptive (`Statement`, `Work`, `Super_transaction`, `Ledger_builder`, `Ledger_builder_controller`). Having a standardized and descriptive set of names in our codebase will increase the initial readability, reduce potential areas of confusion, and increase our ability to communicate concept consistently (in person, in code, and in documentation).

# Detailed design
[detailed-design]: #detailed-design

Firstly, in order to keep names short, we define a table of short words for our most commonly words. When naming components in the system, these short words should be used.

| Long        | Short |
|-------------|-------|
| Account     | Acc   |
| Database    | Db    |
| Transaction | Txn   |
| Transition  | Trans |

Now, let's categorize and define the individual name changes of various components in the system. These changes are categorized logically so that work to perform each name refactor can be split up accordingly.

### Merkle trees

| Current Name      | Description                                  | New Name            |
|-------------------|----------------------------------------------|---------------------|
| `Ledger`          | Interface into merkle tree of account states | `Acc_db`            |
| `Ledger_hash`     | Root hash of a `Acc_db`                      | `Acc_db_root`       |
| `Merkle_ledger`   | In memory implementation of `Acc_db`         | `Irresolute_acc_db` |
| `Merkle_database` | On disk implementation of `Acc_db`           | `Persistent_acc_db` |
| `Syncable_ledger` | Wrapper of `Acc_db` to sync over network     | `Sync_acc_db`       |

### States

| Current Name          | Description                                                | New Name               |
|-----------------------|------------------------------------------------------------|------------------------|
| `Parallel_scan_state` | State of a series of parallel scan trees                   | "                      |
| `Ledger_builder`      | State of `Parallel_scan_state` + `Txn_work`                | `Theoretic_txns_state` |
| `Blockchain_state`    | State of `Acc_db` and `Theoretic_txns` at a block          | `Acc_db_state`         |
| `Consensus_state`     | Consensus mechanism specific state at a block              | "                      |
| `Protocol_state`      | The `Acc_db_state` and `Consensus_state` at a block        | `Lite_state`           |
| `Tip`                 | The `Protocol_state` and `Theoretic_txns_state` at a block | `Full_state`           |

### Transitions

| Current Name          | Description                                          | New Name                    |
|-----------------------|------------------------------------------------------|-----------------------------|
| `Snark_transition`    | Subset of `Full_state_trans` that is snarked         | `Provable_full_state_trans` |
| `Internal_transition` | State transition on full states                      | `Full_state_trans`          |
| `External_transition` | State transition on lite states; sent to other nodes | `Lite_state_trans`          |

### Transactions

| Current Name        | Description                                            | New Name            |
|---------------------|--------------------------------------------------------|---------------------|
| `Super_transaction` | ADT for all types of account state transitions         | `Txn`               |
| `Transaction`       | Transaction for payment between accounts               | `Payment_txn`       |
| `Fee_transfer`      | Transaction for distributing work fees                 | `Fee_txn`           |
| `Coinbase`          | Transaction for new currency added each `Block_trans`  | `Coinbase_txn`      |

### Snarks

| Current Name          | Description                                                      | New Name                 |
|-----------------------|------------------------------------------------------------------|--------------------------|
| `Statement`           | A snark proving the application of a single `Txn` to an `Acc_db` | `Txn_statement`          |
| `Work`                | A collection of one or two `Txn_statement`s                      | `Txn_work`               |
| `Transaction_snark`   | The snark which proves `Txn_statement`s                          | `Txn_snark`              |
| `Blockchain_snark`    | The snark which proves `Full_state_trans`s on `Full_state`s      | `Full_state_trans_snark` |

### Primary components

| Current Name                | Description                                                               | New Name              |
|-----------------------------|---------------------------------------------------------------------------|-----------------------|
| `Ledger_builder_controller` | Maintains locked `Full_state` and forks of potential future `Full_state`s | `Full_state_frontier` |
| `Proposer`                  | Proposes new blocks                                                       | "                     |
| `Snark_worker`              | Generates `Txn_work`                                                      | "                     |

# Drawbacks
[drawbacks]: #drawbacks

This may cause some initial headache while the development team gets used to the new vocabulary.

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

There are many alternative naming patterns that we could choose. The important thing is that we all come to consensus as a team with something we all like (or, if that's impossible, at least something the majority like and the remaining don't hate).
