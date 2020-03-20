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

A fork is denoted by a protocol version, which is a semantic version. That is, the protocol
version has the form `m.n.p`, where `m` is an integer denoting a major version, `n` is a minor
version number, and `p` is a patch number.  Blocks have two protocol version fields, one to
indicate the current fork, another to indicate a proposed fork. Because there will usually not
be a proposed fork, that field has an option type.

A change to the patch number represents a software upgrade, and does not require signalling.
A change to the minor version is signalled, but nodes can continue to run existing software
(a soft fork). A change to the major version number requires that nodes upgrade their software
(a hard fork).

The compile-time configuration includes a current protocol version. That protocol version
can be overridden via a command-line flag, which is saved to the node's dynamic configuration. If the
dynamic configuration includes the protocol version, the next time the node is started, that
protocol version will be used. It's an error to start the node with a protocol version from the
command line that's different from one stored in the dynamic configuration.

For RPCs between nodes, if the response contains a block with a different current protocol version,
that response is ignored, and the sender punished. The next protocol version is ignored for these RPCs.

For gossiped blocks, if the block's current fork ID differs from the node's current fork ID,
that block is ignored, and the sender is punished.

To signal a proposed fork change, we need mechanisms for a node to set its
next fork ID, to be included in the blocks it gossips subsequently. An optional command-line
flag indicates the next fork ID to be used, which also stores the next fork ID in the dynamic
configuration, to be used the next time the node is run. Additionally, we'll provide a GraphQL
endpoint to set the next fork ID, which would also store the next fork ID in the dynamic
configuration.

Much of this design appears in PR #4347, which has not been merged as of this writing.
The punishment implemented there for mismatched current fork IDs is a trust decrease of
0.25, allowing a small number of mismatches in blocks before banning a peer. That PR
does not implement any mechanism for setting the next fork ID.

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
mechanism does not handle hard forks. The design here is inspired by that mechanism, although
our design is intended for hard forks in the first instance.

There are other soft fork mechanisms in Bitcoin. See [this article] (https://medium.com/@elombrozo/forks-signaling-and-activation-d60b6abda49a)
for a discussion of them.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

Do we want the flexibility of setting the current fork ID to a value other than the compile-time
default, given the possibility of network fragmentation?

Is the trust decrease of 0.25 the right level of punishment for a peer that sends a
mismatched current fork ID?

Do we wish this design to accomodate both soft forks and hard forks? The next fork ID could be tagged
with `Hard` or `Soft`. For `Hard`, restarting a node would require upgrading software. In the `Soft` case,
the current fork ID would change, while the existing software would continue to work.
