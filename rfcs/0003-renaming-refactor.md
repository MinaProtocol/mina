# Summary
[summary]: #summary

Refactor our codebase with consistent, correct, and descriptive names.

# Motivation
[motivation]: #motivation

There are a multitude of naming issues which plague our codebase. Some names are not consistent (`Statement` vs. `Work`), others are not correct (`Ledger` is not a ledger; there is no log of transactions). We also have some names that are not very descriptive (`Statement`, `Work`, `Super_transaction`, `Ledger_builder`, `Ledger_builder_controller`). Having a standardized and descriptive set of names in our codebase will increase the initial readability, reduce potential areas of confusion, and increase our ability to communicate concept consistently (in person, in code, and in documentation).

# Detailed design
[detailed-design]: #detailed-design

### Merkle trees

| Current Name      | Description                                  | New Name                |
|-------------------|----------------------------------------------|-------------------------|
| `Ledger`          | Interface into merkle tree of account states | `Account_db`            |
| `Ledger_hash`     | Root hash of a `Account_db`                  | `Account_db_root`       |
| `Merkle_ledger`   | In memory implementation of `Account_db`     | `Volatile_account_db`   |
| `Merkle_database` | On disk implementation of `Account_db`       | `Persistent_account_db` |
| `Syncable_ledger` | Wrapper of `Account_db` to sync over network | `Sync_account_db`       |
| `Genesis_ledger`  | The initial `Account_db` for the protocol    | `Genesis_account_db`    |

### States

| Current Name          | Description                                                               | New Name               |
|-----------------------|---------------------------------------------------------------------------|------------------------|
| `Parallel_scan_state` | State of a series of parallel scan trees                                  | "                      |
| `Ledger_builder`      | State of `Parallel_scan_state` + `Transaction_work`                       | `Pending_account_db`   |
| `Ledger_builder_aux`  | Auxiliary datastructure of `Pending_account_db`                           | `Work_queue`           |
| `Blockchain_state`    | State of `Account_db` root and `Pending_account_db` root at a block       | `Account_db_state`     |
| `Consensus_state`     | Consensus mechanism specific state at a block                             | "                      |
| `Protocol_state`      | The `Account_db_state` and `Consensus_state` at a block                   | "                      |
| `Tip`                 | The `Protocol_state` and `Pending_account_db` at a block                  | `Full_state`           |

### Transitions

| Current Name          | Description                                          | New Name                         |
|-----------------------|------------------------------------------------------|----------------------------------|
| `Snark_transition`    | Subset of `Full_state_transition` that is snarked    | `Provable_full_state_transition` |
| `Internal_transition` | State transition on full states                      | `Full_state_transition`          |
| `External_transition` | State transition on lite states; sent to other nodes | `Protocol_state_transition`      |

### Transactions

| Current Name        | Description                                            | New Name      |
|---------------------|--------------------------------------------------------|---------------|
| `Super_transaction` | ADT for all types of account state transitions         | `Transaction` |
| `Transaction`       | Transaction for payment between accounts               | `Payment`     |
| `Fee_transfer`      | Transaction for distributing work fees                 | `Fee`         |
| `Coinbase`          | Transaction for new currency added each `Block_trans`  | `Coinbase`    |

### Snarks

| Current Name          | Description                                                      | New Name                      |
|-----------------------|------------------------------------------------------------------|-------------------------------|
| `Statement`           | A snark proving the application of a single `Txn` to an `Acc_db` | `Transaction_statement`       |
| `Work`                | A collection of one or two `Txn_statement`s                      | `Transcation_work`            |
| `Transaction_snark`   | The snark which proves `Txn_statement`s                          | `Transaction_snark`           |
| `Blockchain_snark`    | The snark which proves `Full_state_trans`s on `Full_state`s      | `Full_state_transition_snark` |

### Primary components

| Current Name                | Description                                                                    | New Name              |
|-----------------------------|--------------------------------------------------------------------------------|-----------------------|
| `Ledger_builder_controller` | Maintains locked `Full_state` and forks of potential future `Full_state`s      | `Full_state_frontier` |
| `Proposer`                  | Proposes new blocks                                                            | "                     |
| `Snark_worker`              | Generates `Transaction_work`s                                                  | `Snarker`             |
| `Prover`                    | Proves `Full_state_transition`s                                                | "                     |
| `Verifier`                  | Verifies `Full_state_transition_snark`s                                        | "                     |
| `Micro_client`              | A node which only tracks `State_summary` a limited number of account balances  | "                     |

# Drawbacks
[drawbacks]: #drawbacks

This may cause some initial headache while the development team gets used to the new vocabulary.

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

There are many alternative naming patterns that we could choose. The important thing is that we all come to consensus as a team with something we all like (or, if that's impossible, at least something the majority like and the remaining don't hate).
