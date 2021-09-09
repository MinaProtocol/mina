## Summary
[summary]: #summary

Nodes can signal to other nodes that they intend to switch from the current fork to a new fork.
This RFC is scoped to changes needed for mainnet launch.

## Motivation
[motivation]: #motivation

Each node in the network has a notion of the current fork it's running on. A node may wish to
change forks, perhaps because it's running new software, or to create a new subnet of nodes with
some common interest. Such an ability is a limited form of on-chain governance. When a node
proposes a new fork, other nodes need to be informed of the proposal.

## Detailed design
[detailed-design]: #detailed-design

A fork is denoted by a protocol version, which is a semantic version. That is, the protocol
version has the form `m.n.p`, where `m` is an integer denoting a major version, `n` is a minor
version number, and `p` is a patch number.  Blocks have two protocol version fields, one to
indicate the current fork, another to indicate a proposed fork. Because there will not always
be a proposed fork, that field has an option type.

A change to the patch number represents a software upgrade, and does not require signalling.
A change to the minor version is signalled, but nodes can continue to run existing software
(a soft fork). A change to the major version number is signalled, and requires that nodes
upgrade their software (a hard fork).

The compile-time configuration includes a current protocol version. For testing and debugging,
that protocol version can be overridden via a command-line flag, which is saved to the node's
dynamic configuration. If the dynamic configuration includes the protocol version, the next time
the node is started, that protocol version will be used. It's an error to start the node with
a protocol version from the command line that's different from one stored in the dynamic
configuration. The command-line flag feature should be removed by the time of mainnet.

For RPCs between nodes, if the response contains a block with a different major current protocol version,
that response is ignored, and the sender punished. The next protocol version is ignored for these RPCs.

For gossiped blocks, if the block's major protocol version differs from the node's major protocol
version that block is ignored, and because the protocol has been violated, the sender is punished.

To signal a proposed fork change, we need mechanisms for a node to set its
proposed protocol version, to be included in the blocks it gossips subsequently. An optional
command-line flag indicates the proposed protocol version to be used, which also stores the
proposed protocol version in the dynamic configuration, to be used the next time the node is run.
Additionally, we'll provide a GraphQL endpoint to set the proposed protocol version, which would
also store the proposed protocol version in the dynamic configuration.

Much of this design appears in PR #4565, which has not been merged as of this writing.
The punishment implemented there for mismatched current protocol versions is a trust decrease of
0.25, allowing a small number of mismatches in blocks before banning a peer.

## Drawbacks
[drawbacks]: #drawbacks

If switching the protocol version is under manual control, a possible outcome of this mechanism
would be extreme fragmentation of the network into sub-networks, each sharing a common
current protocol version. Limiting the current protocol version to a compile-time value
in mainnet should remove this concern.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

Semantic versioning allows us to distinguish hard and soft works. An alternative
would be to limit fork signalling to hard forks, since soft forks maintain
compatibility with old code. Signalling soft forks is nonetheless useful, so that
nodes are certain of the protocol being used.

## Prior art
[prior-art]: #prior-art

There are related issues and PRs. Issue #4199 mentions adding the "fork ID" fields to
blocks (the type `External_transition.t`). Issue #4200 mentions examining those fields.
PR #4347 was meant to address both of those issues. Issue #4201 mentions reporting
statistics of fork IDs seen in gossiped blocks, although details are still needed.
The protocol version notion in this RFC subsumes fork IDs.

Bitcoin introduced a mechanism called `Miner-activated soft forks`, where miners could
increment a version number in blocks. Nodes would be required to accept blocks with
the new version number once they'd seen a certain frequency of them within a
number-of-blocks window, and reject lower-versioned blocks upon a higher frequency threshold.
The new version number signalled an `activation`, a change in consensus rules. The Bitcoin
mechanism does not handle hard forks. The design here is inspired by that mechanism, although
our design is intended for hard forks in the first instance.

There are other soft fork mechanisms in Bitcoin. See [this article] (https://medium.com/@elombrozo/forks-signaling-and-activation-d60b6abda49a)
for a discussion of them.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

Is the trust decrease of 0.25 the right level of punishment for a peer that sends a
mismatched current fork ID?
