## Summary
[summary]: #summary

This RFC proposes separating the protocol state into a 'body', which contains everything but the previous protocol state hash, and the previous protocol state hash. This is to make it possible to give much shorter "ancestor proofs". I.e., proofs that a given protocol state is an ancestor of another one.

The goal behind this is to simplify the process of bootstrapping a new node to the network by allowing bootstrapping nodes to forgoe the requirements of tracking the entire transition frontier while bootstrapping. This RFC also includes a description of the new bootstrapping procedure.

## Motivation
[motivation]: #motivation

Bootstrapping the root ledger for the transition frontier involves creating a sync ledger that targets the current root ledger of the network, and retargetting that sync ledger whenever the root ledger transitions. A root ledger transition happens whenever a transition is added to the transition frontier that extends a path farther than the maximum path length. 

As the system works currently, the only way to determine when a root ledger transition happens is to maintain a full snapshot of the transition frontier. The is true because the you cannot trust a transition until you can fit it in the transition frontier and can validate its proof and that the consensus properties of the chain it belongs to hold. You have to trust a transition before you can determine its side effects on the rest of the transition frontier to prevent adversaries from tricking you into synchronizing to an incorrect transition frontier. The effect of this trick would be minimal, as adversaries taking advantage of such a vulnerability would only be able to delay new nodes from joining the network and not disrupt existing nodes, however the logic in order to recover from such error states would be complex to implement and would require a thorough design and testing pass on the transition frontier. Furthermore, with this system, the node that is bootstrapping would need to constantly download breadcrumb information for new paths in the transition frontier, which would have a significant overhead in relation to bandwidth, on top of the already present sync ledger task. Since the root is a rolling target and transitions on it invalidate information in the transition frontier, this could mean that a client that is bootstrapping could get stuck constantly requesting information in the transition frontier, only for it to be invalidated, wasting precious time while attempting to synchronize the root ledger, which is the only task it really needs to complete as part of bootstrapping. Therefore, some simpler, universally available method of determining when the locked tip transitions is preferable.

## Detailed design
[detailed-design]: #detailed-design

The protocol state will now be a record with two fields `previous_state_hash` and `body`. The `body` will contain all the other fields previously in protocol state (i.e., `blockchain_state` and `consensus_state`.) We now hash a protocol state as `H(previous_state_hash, H(body))`.

A bootstrapping node that wants to obtain the root corresponding to a proven protocol state `s` will request the root protocol state `root` along with an efficient ancestor proof: a value of type `State_body_hash.t list`. It verifies the proof by checking the list as a Merkle inclusion proof. This proof is about 200 kb (2000 field elements). A node only needs to request these proofs while it is in the bootstrapping phase. Once it has bootstrapped it no longer needs them. Furthermore, we could optimize it to save previously obtained inclusion proofs so that it would need far shorter inclusion proofs for subsequent updates.

### Constants

Thoughout the design, we will describe terms in relation to a constant `K`. The constant `K` is a natural number representing the transitions before finality can be assumed. As per Ouroboros proof of stake, `K = unforkable_slot_count = 2160`. The maximum length of a branch in the transition frontier is `K`, as the transition frontier root represents the point of finality of the network.

### Root hash validation/punishment
[detailed-design-root-hash-validation-punishment]: #detailed-design-root-hash-validation-punishment

A `transition_frontier_root_hash` is valid iff one of the following conditions is true:
1. `transition.transition_frontier_root_hash = genesis_state_hash && transition.protocol_state.blockchain_state.length < K`
2. `transition.transition_frontier_root_hash = transition_frontier.root_hash_at_length(transition.protocol_state.blockchain_state.length - K)`

In order to check condition #2, the transition frontier now contains and maintains a transition frontier root history, updating it on root transitions. The transition frontier can be created with an initial history, allowing the program to pass the history accumulated during the bootstrapping phase to the transition frontier when it is initialized.

### Bootstrapping
[detailed-design-bootstrapping]: #detailed-design-bootstrapping

Bootstrapping is initialized by listening for any initial transition on the network. Then, the bootstrapping node requests (likely from the sender of that transition) a root state along with an ancestor proof, which it verifies.

A sync ledger is started with the hash of the root state set as the target and the stored ledger as its base (or the genesis ledger if the client has no stored ledger). While bootstrapping, the node continues to listen to new transitions. If a new transition is heard with a greater length than the current target of the sync ledger, the node requests a new root state and proof and the sync ledger is retargetted to the new root hash.

## Drawbacks
[drawbacks]: #drawbacks

The biggest drawback of this proposal is that a bootstrapping node needs to download 200 kb additional for each block which occurs before it has synced. As mentioned this could be mitigated by saving the proofs and requesting smaller proofs as time goes on, which should make the size of later proofs pretty small.

## Rationale
[rationale]: #rationale

While this is not a fully optimal solution, as layed out in the [drawbacks](#drawbacks) section, it does involve the least amount of work while simplifying a significant amount of other work and addressing one of the immediate problems of the current methodology for bootstrapping.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

- Are there any vulnerabilities introduced by this change which were not discussed already?
