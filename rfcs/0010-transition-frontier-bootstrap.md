## Summary
[summary]: #summary

This RFC proposes adding a new field to the external transition which stores the state hash of the state at the root of the transition frontier after applying the external transition in question to its parent state and adding it to the transition frontier. The goal behind this addition is to simplify the process of bootstrapping a new node to the network by allowing bootstrapping nodes to forgoe the requirements of tracking the entire transition frontier while bootstrapping. This RFC also involves changes to the transition frontier to enable validation of this new field, and it includes a description of the new bootstrapping procedure.


## Motivation
[motivation]: #motivation

Bootstrapping the root ledger for the transition frontier involves creating a sync ledger that targets the current root ledger of the network, and retargetting that sync ledger whenever the root ledger transitions. A root ledger transition happens whenever a transition is added to the transition frontier that extends a path farther than the maximum path length. As the system works currently, the only way to determine when a root ledger transition happens is to maintain a full snapshot of the transition frontier. The is true because the you cannot trust a transition until you can fit it in the transition frontier and can validate its proof and that the consensus properties of the chain it belongs to hold. You have to trust a transition before you can determine its side effects on the rest of the transition frontier to prevent adversaries from tricking you into synchronizing to an incorrect transition frontier. The effect of this trick would be minimal, as adversaries taking advantage of such a vulnerability would only be able to delay new nodes from joining the network and not disrupt existing nodes, however the logic in order to recover from such error states would be complex to implement and would require a thorough design and testing pass on the transition frontier. Furthermore, with this system, the node that is bootstrapping would need to constantly download breadcrumb information for new paths in the transition frontier, which would have a significant overhead in relation to bandwidth, on top of the already present sync ledger task. Since the root is a rolling target and transitions on it invalidate information in the transition frontier, this could mean that a client that is bootstrapping could get stuck constantly requesting information in the transition frontier, only for it to be invalidated, wasting precious time while attempting to synchronize the root ledger, which is the only task it really needs to complete as part of bootstrapping. Therefore, some simpler, universally available method of determining when the locked tip transitions is preferable.

## Detailed design
[detailed-design]: #detailed-design

The external transition will contain a new field called `transition_frontier_root_hash` which stores the hash of the state at the root of the transition frontier after adding the external transition. More specifically, if the new transition extends its branch to be longer than the maximum branch length of the transition frontier, the `transition_frontier_root_hash` of that transition will be the immediate successor of the root of the transition frontier (before adding the new transition) which is in the path to the transition, and otherwise it will be same as the parent transition's `transition_frontier_root_hash`.

This field exists outside of the protocol state so that it does not have to be proved in the snark. It could be proved in the snark, and it would be nice to, but it would increase the size of the snark by a signficant enough amount that it would be better if we can avoid having to encode this field in the snark. However, this has added complexity to the usage of this information as it is information that cannot be trusted. While a bootstrapping node can still perform ordinary checks of the transitions it receives such that an entirely malformed transition would be rejected, it has no way to know that the `transition_frontier_root_hash` is the correct value to associate with the rest of the information. However, a node which has already bootstrapped (and has been online for long enough; see below) does have the capability to verify the correctness of the `transition_frontier_root_hash`, and can punish nodes which communicate this value incorrectly. This does not completely protect bootstrapping nodes, though, as an adversary could detect whether a node is bootstrapping or not before executing the attack by watching the network traffics on a per peer basis. Therefore, bootstrapping nodes still need to detect misalignment and recover from it.

### Constants

Thoughout the design, we will describe terms in relation to a constant `K`. The constant `K` is a natural number representing the transitions before finality can be assumed. As per Ouroboros proof of stake, `K = unforkable_slot_count = 2160`. The maximum length of a branch in the transition frontier is `K`, as the transition frontier root represents the point of finality of the network.

### Transition frontier root history

A new datastructure, the transition frontier root history, is introduced to provide partial or full view into the recent history of transition frontier roots. More specifically, it stores at most `K` root transition hashes preceeding the current transition frontier root. The hashes are keyed by length to quicken the interaction with it in relation to checking the validity of the `transition_frontier_root_hash`.

This data structure handles any number of root transition hashes `<= K`. As such, the interface of the datastructure should be such that there are three possible results from a query: `Known of hash`, `Unknown`, `Out_of_bounds`.

### Root hash validation/punishment
[detailed-design-root-hash-validation-punishment]: #detailed-design-root-hash-validation-punishment

A `transition_frontier_root_hash` is valid iff one of the following conditions is true:
1. `transition.transition_frontier_root_hash = genesis_state_hash && transition.protocol_state.blockchain_state.length < K`
2. `transition.transition_frontier_root_hash = transition_frontier.root_hash_at_length(transition.protocol_state.blockchain_state.length - K)`

In order to check condition #2, the transition frontier now contains and maintains a transition frontier root history, updating it on root transitions. The transition frontier can be created with an initial history, allowing the program to pass the history accumulated during the bootstrapping phase to the transition frontier when it is initialized.

### Bootstrapping
[detailed-design-bootstrapping]: #detailed-design-bootstrapping

Bootstrapping is initialized by listening for any initial transition on the network. Then, a sync ledger is started with the `transition_frontier_root_hash` field of the initial transition set as the target and the stored ledger as its base (or the genesis ledger if the client has no stored ledger). While bootstrapping, the node continues to listen to new transitions. If a new transition is heard with a greater length than the current target of the sync ledger, the sync ledger is retargetted to the new transition's ledger hash. A transition frontier root history is kept during this time as well, which will be forwarded to the transition frontier once bootstrapping has completed.

#### Misalignment detection/recovery
[detailed-design-bootstrapping-misalignment-detection-recovery]: #detailed-design-bootstrapping-misalignment-detection-recovery

During bootstrapping, an adversary can provide the node with bad data and cause the node to misalign its sync ledger target from the network. If this were to happen, the node should recover from this by switching the target to a new `transition_frontier_root_hash` from a random transition received over the network. This new recovery target should be verified to not exist in the transition frontier root history before switching to it. The history should be thrown out upon recovery as the information in there is now invalid. Misalignment can be detected by setting a threshold rule on the number of nodes that are not aware of a ledger being requested by the sync ledger. If more than 50% of the nodes queried report that they have no such ledger, then it can be assumed that misalignment has taken place and recovery can be performed. This threshold should not trigger until enough nodes have been sampled, proportional to a function of the total size of the network.

## Drawbacks
[drawbacks]: #drawbacks

This design proposal only has limited advantages over the current implementation. While it has a significant impact on the edge cases and required network bandwidth, reduces the required information for bootstrapping, and reduces the complexity of the transition frontier, it still fails to address the issue where adversaries can trick new nodes into synchronizing to the incorrect root ledger. As mentioned in the [motivation](#motivation) section, this vulnerability does not open up any interesting attacks for an adversary to take advantage of by itself. However, an adversary could potentially use this in tandem with a second attack which is able to take nodes offline or invalidate their local transition frontier, causing them to bootstrap, in order to effectively take nodes offline for an extended period of time. The [detailed design](#detailed-design) section talks about how network punishment and incorrect bootstrap invalidation can mitigate this kind of an attack, but there is still an imbalance of responsiblities within the network for preventing this: the attack only effects bootstrapping nodes, yet regular nodes are the only ones that have enough information to punish for this attack, so while our codebase will be written to punish for this attack, there is no real incentive for full nodes to do so otherwise. I don't think this is too big of a drawback to continue moving forward with this RFC, however, it does point to the fact that they may be better, fuller solutions to this problem.

## Rationale
[rationale]: #rationale

While this is not a fully optimal solution, as layed out in the [drawbacks](#drawbacks) section, it does involve the least amount of work while simplifying a significant amount of other work and addressing one of the immediate problems of the current methodology for bootstrapping.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

- Are there any vulnerabilities introduced by this change which were not discussed already?
- What is the cost of checking the validity of the `transition_frontier_root_hash` of every transition to already bootstrapped nodes?
  - At what point in the validation process should this be checked (the order of validation steps is significant)?
