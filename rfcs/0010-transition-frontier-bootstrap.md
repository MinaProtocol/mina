## Summary
[summary]: #summary

The goal of this RFC is to create a simple process for bootstrapping a new node or a node who has been inactive for a long time to the network. This is done by asking a peer for its root external transition and a proof of it along with the staged ledger scan state corresponding to the transition. Bootstrap allows a node to forgoe its entire transition frontier and sync with the network by syncing just with the network's root.

## Motivation
[motivation]: #motivation

With the derivations constructed by Oroborous Praos/Genesis, we can assume that finality is achieved at the a node's root external transition. Thus, there is only one uniquly valid `snarked_ledger` and `staged_ledger` that a node has to bootstrap to. In this RFC, we discuss how we can achieve this efficiently. 

## Detailed design
[detailed-design]: #detailed-design

### Constants

Thoughout the design, we will describe terms in relation to a constant `K`. The constant `K` is a natural number representing the transitions before finality can be assumed. As per Ouroboros proof of stake, `K = unforkable_slot_count = 2160`. The maximum length of a branch in the transition frontier is `K`, as the transition frontier root represents the point of finality of the network.

### Activation Conditions

A node would want to bootstrap when it sees that is not synced to the network compared to its peers. It does this by comparing the length of its root's consensus state and the length of the consensus state of the transition that it currently sees from its peers, `seen_transition`. A node can see if the length of its peer's root consensus state is at least `seen_transition.length - K`. If this value is greater than  the node's current root length, then the node is out of sync with the network compared to its peer. This peer's root may exist in the node's frontier, so it would not be too out of synced and the node could run a catchup job to be in synced with the network (See [ledger_catchup.ml](src/lib/ledger_catchup/ledger_catchup.ml) for more details). It would very out of sync when this does not occur. As a result, a node would want to bootstrap when `seen_transition.length - root.length > 2k`.

### Root Syncing 
The main goal of bootstrapping is to have a node sync with a peer's root. A node would listen to transitions and would only sync with a peer via a seen transition after the condition discussed in the section, `Activation Conditions`, is met . An honest peer would need to prove a node its root `external_transition` and a proof that it's valid. A peer can show that their root is valid by showing that the path from their root to one of their breadcrumb is length `K`. The root can do this by showing a path of `external_transition`s between it's root `external_transition` and its best tip. The node should prefer the best tip over the seen transition that the peer sent. Rather than sending an entire path of `external_transitions` through the network, a peer can a provide merkle list proof of this path.

An `external_transition` can be represented by its `protocol_state`, which contains a `blockchain_state` and `consensus_state`. An `external_transition` can be hashed by the hash of the hash of the `blockchain_state` and the `consensus_state` and its parent's hash. This hash is represented as the type `State_hash.t` and the hash of `blockchain_state` and the `consensus_state` is represented as the type `State_body_hash.t`. The hash of an `external_transition` is eqauted to :
$$state\_body\_hash(t) = H(t.blockchain\_state|t.consensus\_state)  $$
$$ state\_hash(t) = H(state\_body\_hash(t)|parent\_hash(t)) $$

Thus, if a peer wants to prove that it has a path from it's root to its best tip, it has to provide a merkle list of `State_body_hash.t`. The first element on this list is the child of the root's `state_body_hash` and the last element is the `best_tip`'s `state_body_hash`. Iteratively folding this with the root's `state_hash` as the initial acculumulator of the fold should equal to the `best_tip`'s `state_hash`. The length of this list should also equal to `K`.

This proof is about 200 kb (2000 field elements). A node only needs to request these proofs while it is in the bootstrapping phase. Once it has bootstrapped it no longer needs them. Furthermore, we could optimize it to save previously obtained inclusion proofs so that it would need far shorter inclusion proofs for subsequent updates.

After receiving a peer's root and verifying it's correct, the node will ask the network to help it sync its `snarked_ledger`. A sync ledger job will start with the hash of the root state set as the target. While bootstrapping, the node continues to listen to new transitions. If a new transition is heard and is more preferred than the seen transition that causes the node to run a sync ledger job, the node requests a new root state and proof and the sync ledger is retargetted to the new `snarked_ledger` hash. It should be noted that the sync ledger would not be retargetted very often, since a ledger proof is emitted seldomly and causes the `snarked_ledger` to change. 


### Staged_ledger Syncing

After syncing with a peer's root `external_transition` and `root_snarked_ledger`, a node would need to materialize its `staged_ledger`. In order to do this, the node would need to ask its peers for the `parallel_scan_state` corresponding to its new root's `staged_ledger`. The `parallel_scan_state` can by verified by hashing it together with the hash of the ledger inside the `root`'s `staged_ledger`.  This should equal to the `staged_ledger_hash` in the `blockchain_state`. 

After verifying the `parallel_scan_state`, the node would extract the full set of staged ledger transactions from the `staged_ledger` and apply them to the empty merkle mask of the root snarked ledger. The node would then verify that the new merkle mask merkle root is equal to the staged ledger merkle root that it received. It would then construct the staged ledger from the merkle mask and the `parallel_scan_state`.


### Collected transitions

While bootstrapping, the node would listen to multiple transitions. These transitions are cached and are seen as future breadcrumbs of the node's transition frontier. Once bootstrapping is completed, these external transitions will be fed into the catchup scheduler and catchup jobs should eventually be materialized into the frontier.

## Drawbacks
[drawbacks]: #drawbacks

The biggest drawback of this proposal is that a bootstrapping node needs to download 200 kb additional for each block which occurs before it has synced. As mentioned this could be mitigated by saving the proofs and requesting smaller proofs as time goes on, which should make the size of later proofs pretty small.

## Rationale
[rationale]: #rationale

While this is not a fully optimal solution, as layed out in the [drawbacks](#drawbacks) section, it does involve the least amount of work while simplifying a significant amount of other work and addressing one of the immediate problems of the current methodology for bootstrapping.

## Prior Art
In order for a node to fully sync with the Bitcoin or Ethereum, they need to download the entire blockchain leading to the best tip. As of 03/13/2019, this process can take days. Bitcoin and Ethereum have light client wallets that enables a node to sync with the network quickly. However, these blocks that the clients received are not fully verified.

Through this proposed method, a node can fully sync with the network in a constant amount of time because we only need to download a constant amount of blocks, from a node's root to their best tip.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

- Are there any vulnerabilities introduced by this change which were not discussed already?
- After a node syncs with peer's transition and root snarked ledger, what will happen if no peer can provide it the `scan_state` that it is requesting for? Is this possible?

