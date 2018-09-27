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

| Current Name       | Description                                       | New Name       |
|--------------------|---------------------------------------------------|----------------|
| `Blockchain_state` | State of `Acc_db` and `Theoretic_txns` at a block | `Acc_db_state` |
| `Consensus_state`  | Consensus mechanism specific state at a block     | "              |
| `Protocol_state`   | State of the entire protocol at a block           | `Block`        |

### Transitions

| Current Name          | Description                                     | New Name            |
|-----------------------|-------------------------------------------------|---------------------|
| `External_transition` | State transitions on blocks sent to other nodes | `Block_trans`       |

### Transactions

| Current Name          | Description                                            | New Name            |
|-----------------------|--------------------------------------------------------|---------------------|
| `Super_transaction`   | ADT for all types of account state transitions         | `Txn`               |
| `Transaction`         | Transaction for payment between accounts               | `Payment_txn`       |
| `Fee_transfer`        | Transaction for distributing work fees                 | `Fee_txn`           |
| `Coinbase`            | Transaction for new currency added each `Block_trans`  | `Coinbase_txn`      |

| `Statement`           | A snark proving an `Acc_db`

### Primary components

| Current Name          | Description                                            | New Name            |
|-----------------------|--------------------------------------------------------|---------------------|
| `Ledger_builder`      | Manages `Parallel_scan_state` + `Txn_snark_work`       | `Theoretic_txns`    |
| `Ledger

# Drawbacks
[drawbacks]: #drawbacks

Why should we *not* do this?

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

- Why is this design the best in the space of possible designs?
- What other designs have been considered and what is the rationale for not choosing them?
- What is the impact of not doing this?

# Prior art
[prior-art]: #prior-art

Discuss prior art, both the good and the bad, in relation to this proposal.
A few examples of what this can include are:

# Unresolved questions
[unresolved-questions]: #unresolved-questions

- What parts of the design do you expect to resolve through the RFC process
  before this gets merged?
- What parts of the design do you expect to resolve through the implementation
  of this feature before merge?
- What related issues do you consider out of scope for this RFC that could be
  addressed in the future independently of the solution that comes out of this
  RFC?
