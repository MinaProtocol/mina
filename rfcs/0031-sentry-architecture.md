## Summary
[summary]: #summary

Introduce a new "hidden" and "sentry" mode to the daemon for building
DoS-resilient network topologies.

## Motivation
[motivation]: #motivation

Block producer availability is important both for healthy consensus (blocks
have a limited time to be broadcast before they are no longer useful) and also
for node operator profits. Block producers (and, to a lesser extent, SNARK
workers) need to be powerful enough to produce their proofs in a reasonable
amount of time, and have operational security requirements around protecting
the private key. If a DoS takes a node offline such that they can't broadcast
their work, or put the CPUs to use, the operator loses money and consensus is
weakened. It is also risky to directly expose a machine with sensitive key
material to untrusted internet traffic. Sensitive nodes can be protected from
these risks by running them in a new "hidden mode". These hidden nodes will
communicate via nodes running in "sentry mode".

The recommended way to deploy this would be to have several sentries, possibly
in different cloud providers/datacenters, configured per hidden node.

## Detailed design
[detailed-design]: #detailed-design

New RPCs:

- `Sentry_forward`: sent from a hidden node to a sentry node with some new work, to be broadcast over the gossip net.
- `Please_sentry`: sent from a hidden node to its sentries periodically as a sort of "keepalive" to ensure the sentry node continues forwarding messages even if it crashes and forgets about us. These should be sent at least once per slot.
- `Hidden_forward`: sent from a sentry node to a hidden node on all new gossip.

### Hidden Mode

Nodes in hidden mode will not participate in discovery at all, by never calling
`begin_advertising`. They will also filter out all connections not from their
configured sentries. These are "soft" mitigations - hidden nodes, when deployed,
should not be publicly routable at all, or otherwise have the firewall carefully
configured to only allow communications with sentries. 

Because hidden nodes are not well connected, we can't rely on the usual
guarantees of the pubsub implementation to receive block gossip. Thus
`Hidden_forward`: instead of using `subscribe_encode`, new messages will be
received from this RPC. 

The sentries are configured with a new `--sentry-address MULTIADDR` daemon flag.
On startup and on a timer, hidden nodes will send `Please_sentry` to their
configured sentries.

### Sentry Mode

Sentry nodes are normal participants in networking. When they receive a new
message, they forward it to connected hidden nodes using `Hidden_forward`.

Hidden nodes can be configured with a `--sentry-for MULTIADDR` daemon flag,
which will ensure they always receive new messages. In addition, sentries will
accept `Please_sentry` RPCs from any IP address in an [RFC1918][1918] private
address range and add them to the `sentry-for` list. This allows hidden nodes
to be on unstable private addresses without having to reconfigure the sentries.

## Drawbacks
[drawbacks]: #drawbacks

- Not using pubsub requires some additional code.
- This unavoidably adds (at least) one hop of latency before the block producers will see new blocks from the network.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

- Instead of having a hidden mode, we could simply operate normally and configure the network filter to not allow non-sentry connections. This, however, requires a custom pubsub (see below), and is somewhat wasteful: hidden nodes shouldn't need to care about the DHT at all.
- We could have a custom pubsub implementation, which preferentially forwards to hidden nodes before hitting (eg) randomsub. This requires writing some Go code, versus regular OCaml RPCs as described.
- Instead of `Please_sentry`, we could monitor disconnects and then busy poll until the sentry comes back online. We probably should do this, at some point, as it's more precise.

## Prior art
[prior-art]: #prior-art

Similar to the [Cosmos Hub architecture](https://forum.cosmos.network/t/sentry-node-architecture-overview/454).

## Unresolved questions
[unresolved-questions]: #unresolved-questions

Should we use local mDNS discovery to find sentries?

[1918]: https://tools.ietf.org/html/rfc1918
