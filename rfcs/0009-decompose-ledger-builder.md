## Summary
[summary]: #summary

This RFC proposes a decoupling of the ledger builder which is will make the components of the ledger builder more composable and pave the way for properly encoding the ledger builder into the new transition frontier data structure.

## Motivation
[motivation]: #motivation

The ledger builder has been suffering from scope creep for some time now. As we are moving towards the new transition frontier data structure, we are already decoupling the storage mechanism for the underlying ledger for a ledger builder. This is going to have a number of difficult ramifications on the existing data structure, so now seems as good a time as any to fully decouple the ledger builder.

## Detailed design
[detailed-design]: #detailed-design

[Full architecture](../docs/res/all_data_structures.png)

![](../docs/res/ledger_builder_data_structures.png)

### `Merkle_tree`

A `Merkle_tree.t` is a value and a first class module implementing a `Merkle_tree_intf`, which is a common subset of all ledgers. Having a first class module representation of a ledger allows us to build code which can be generic over an interface without functoring over it.

### `Merkle_tree_diff`

A `Merkle_tree_diff.t` is a compressed difference from a base merkle tree to a target merkle tree. It can be applied to a base merkle tree to make it a target merkle tree. More formally, a `Merkle_tree_diff.t` is a base merkle root, a target merkle root, and a set of accounts. The set of accounts represents all of the accounts that have changed between the base and the target. A `Merkle_tree_diff.t` can be applied to a merkle tree by iterating through the set of accounts and writing them to the merkle tree. After applying to a merkle tree, the root of the merkle tree should be equal to the target merkle root iff the root before applying was equal to the base merkle root.

### `Parallel_scan_state`

A `Parallel_scan_state.t` is a generic data structure representing the state of a parallel scan operation. This state is represented as a binary tree of nodes and a binary operation (`node -> node -> node`) that reduces nodes. The state keeps track of multiple parallel sets of nodes that are being reduced at once, all fitted into a single tree. Interaction with the `Parallel_scan_state` is separated into steps in which both completed binary operations (or "work") are applied and new nodes are added to the leaves of the tree. When a set of nodes is reduced to the top, the `Parallel_scan_state` will emit the final value. The number of new nodes that can be added each step is limited by the amount of work that was submitted during that step.

### `Parallel_scan_state_diff`

A `Parallel_scan_state_diff.t` is a formalization around the difference between steps of a `Parallel_scan_state.t`. It contains both the set of completed work and the set of new work to add for a step.

### `Transaction_snark_work`

A `Transaction_snark_work.t` represents the work completed by a snark worker that contributes towards the generation of a single transaction snark proof. This can either be an initial proof of the application of a transaction to a merkle tree, or it can be a recursive composition of these application proofs.

### `Transaction_snark_scan_state`

A `Transaction_snark_scan_state.t` is an instantiation of the `Parallel_scan_state` which defines the nodes and work for generating transaction snark proofs to be included in the transition snark proof.

### `Staged_ledger`

A `Staged_ledger.t` is a combination of a `Merkle_tree.t` and a `Transaction_snark_scan_state.t` which represents a state with staged transactions. The underlying `Merkle_tree.t` is a representation of a ledger in which all of the transactions in `Transaction_snark_scan_state.t` are applied, even though they have not been fully verified yet. The `Staged_ledger` allows for high level applications of transitions, emitting changes to be applied back to a fully verified ledger as they are available.

### `Staged_ledger_diff`

A `Staged_ledger_diff.t` is a combination of a `Merkle_tree_diff.t` and a `Transaction_snark_scan_state.Diff.t` (which is an instantiations of `Parallel_scan_state_diff.t`). It provides the difference between two staged ledgers and can be applied to a `Staged_ledger.t` to transition it.

## Rationale
[rationale]: #rationale

### `Ledger_builder` -> `Staged_ledger`

`Ledger_builder` is not a very descriptive name for what the old type represented, and it is even less so now that it has been decoupled. `Staged_ledger` is a better descriptor as it represents the process of _staging_ transactions into the ledger before they are fully verified. Previously, the term "staged ledger" has been used to refer to the ledger that contains the state of the unproven transactions in the old ledger builder, so this is a change of use for the term. Now, the actual ledger that represents the sate is a `Staged_ledger.ledger`, and the type of `Staged_ledger.t` is the union of a ledger and a `Transaction_snark_scan_state`.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

A `Staged_ledger_diff` could be more compact than it is. There is some duplication in information between the `Merkle_tree_diff` and the `Parallel_scan_state_diff`. Specifically, the `Merkle_tree_diff` can be constructed from the transactions in the `Parallel_scan_state_diff` along with a base `Merkle_tree`. The `Merkle_tree_diff` is a more effecient and compact format for application to a `Merkle_tree` however. Still, perhaps there is a better way to do this.
