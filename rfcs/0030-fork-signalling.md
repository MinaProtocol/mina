## Summary
[summary]: #summary

Nodes can signal to other nodes that they intend to switch from the current fork to a new fork.

## Motivation
[motivation]: #motivation

Each node in the network has a notion of the current fork it's running on. A node may wish to
change forks, perhaps because it's running new software, or to create a new subnet of nodes with
some common interest. Such an ability is a limited form of on-chain governance. When a node
proposes a new fork, other nodes need to be informed of the proposal.

## Detailed design
[detailed-design]: #detailed-design

A fork is denoted by a fork identifier (`fork ID`). Blocks have two fork ID fields, one to
indicate the current fork, another to indicate a proposed fork. Because there will usually
not be a proposed fork, that field has an option type.

When a node is started, the current fork ID is retrieved from the node's configuration.
If the node is being run for the first time, the fork ID must be provided as a command-line
flag. Alternatively, a current fork ID can be provided via a compile-time constant,
which can be overridden via the configuration or command-line flag.

For RPCs between nodes, if the response contains a block with a different current fork ID,
that response is ignored, and the sender punished. The next fork ID is ignored for these RPCs.

For gossiped blocks, if the block's current fork ID differs from the node's current fork ID,
that block is ignored, and the sender is punished.

To signal a proposed fork change, there needs to be a mechanism for the node to set its
next fork ID, to be included in the blocks it gossips. That can be accomplished by a
client command that stores the next fork ID in the configuration, to be used the
next time the node is run. Additionally, we may wish to change a node's next fork ID
dynamically via a GraphQL query, which would also store the next fork ID in the configuration.

A node can track the number of gossiped blocks with a proposed next fork ID and elect to
restart with a new current fork ID. Nodes should log statistics of proposed next fork IDs that
appear in received gossip, so that node operators can make informed choices whether
to switch. Such statistics should also be available via GraphQL. We defer discussion
of the details of such statistics.

Some of this design appears in PR #4347, which has not been merged as of this writing.
The punishment implemented there for mismatched current fork IDs is an Instaban, which
may be too severe. In that PR, there is no code to set next fork IDs.

## Drawbacks
[drawbacks]: #drawbacks

If switching the current fork ID is under manual control, a possible outcome of this mechanism
would be extreme fragmentation of the network into sub-networks, each sharing a common
current fork ID.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

Allowing nodes to set their current fork ID provides flexibility to node operators; it also
engenders the issue mentioned in `Drawbacks`. An alternative would be to require that the
current fork ID comes from the compile-time configuration, and as such, tracks significant
changes to the software such that nodes running old software can't accept blocks from
nodes running newer softare. That alternative would identify *bona fide* hard forks.

## Prior art
[prior-art]: #prior-art

There are related issues and PRs. Issue #4199 mentions adding the fork ID fields to
blocks (the type `External_transition.t`). Issue #4200 mentions examining those fields.
PR #4347 is meant to address both of those issues.

Issue #4201 mentions reporting statistics of fork IDs seen in gossiped blocks, although
details are still needed.

Bitcoin introduced a mechanism called `Miner-activated soft forks`, where miners could
increment a version number in blocks. Nodes would be required to accept blocks with
the new version number once they'd seen a certain frequency of them within a
number-of-blocks window, and reject lower-versioned blocks upon a higher frequency threshold.
The new version number signalled an `activation`, a change in consensus rules. The Bitcoin
mechanism does not handle hard forks. The design here is inspired by that mechanism.

There are other soft fork mechanisms in Bitcoin. See [this article] (https://medium.com/@elombrozo/forks-signaling-and-activation-d60b6abda49a)
for a discussion of them.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

Do we want the flexibility of setting the current fork ID, given its possible drawbacks?

If a node receives a block with a current fork ID that doesn't match its own, either by RPC or gossip, what
should the punishment be for the sender?

Do we wish to accomodate both soft forks and hard forks? The next fork ID could be tagged with `Hard` or `Soft`.
For `Hard`, restarting a node would require upgrading software. In the `Soft` case, the current
fork ID would change, while the software would be unchanged.
