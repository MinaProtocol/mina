# Summary
[summary]: #summary

Punish peers by refusing to connect to their IP when they misbehave.

# Motivation
[motivation]: #motivation

Our software receives diffs, transactions, merkle tree components, etc from
other peers in the network. Much of this is authenticated, meaning we know what
the resulting hash of some object must be. This happens for the `syncable_ledger`
queries and the ledger builder aux data. When a peer sends us data that
results in a state where the hash doesn't match, we know that the peer was
dishonest or buggy. The other primary method of detecting dishonesty is when a
SNARK fails verification.

When a node misbehaves, typically it is trying to mount an attack, often a
denial of service attack. We can mitigate the effectiveness of these attempts
by just ignoring that node

# Detailed design
[detailed-design]: #detailed-design

The basic design is pretty obvious: when a peer misbehaves, notice this, add
their IP to a list, and refuse to communicate with that IP for some amount of
time.

First, where the code currently has `TODO: punish`, we should insert
`Logger.faulty_peer`. `faulty_peer` in turn, should propagate the `peer` into
the current `Kademlia.Membership` (probably over a pipe), which will run `dead t
[bad_peer]`, and add the IP to some list that gets filtered out of `lives`
before `Connect` events are emitted.

The banlist should be persistent, and the CLI should allow manually
adding/removing IPs from the banlist:

```
cli client ban add IP duration
cli client ban remove IP
cli client ban list
```

# Drawbacks
[drawbacks]: #drawbacks

In the case of bugs and not dishonesty, this could really cause chaos. In the
worst case, the network can become totally disconnected and no peer will
willingly communicate with any other for very long.

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

It's not clear what the ideal punishment for misbehaving nodes is. A 1-day IP
ban limits most opportunities for DoS, and bitcoin does it, so it seems
reasonable. The main alternative is a permaban, but this is unnecessarily harsh.
Someone else is probably going to reuse that IP soon enough.

A more complex system could haves nodes sharing proofs of peer misbehavior,
which would enable trustless network-wide banning. This would need a fair
amount of work for probably not much gain.

# Prior art
[prior-art]: #prior-art

Bitcoin, when handling network messages from a peer, is careful to check a variety of
conditions to ensure the message conforms to the protocol. When a check fails,
a "ban score" is added to. When the ban score reaches a given threshold (default
100), the node's IP is banned for a default of 24 hours. Some checks are
insta-bans (most causes of invalid blocks). See in the bitcoin core source:

- `src/validation.cpp`, grep for `state.DoS`
- `src/net_processing.cpp`, grep for `Misbehaving`

# Unresolved questions
[unresolved-questions]: #unresolved-questions

- Is blocking peers at the membership layer sufficient? Is there a different
  place we should do it?
- How should our code report an IP as misbehaving internally? Tack a channel
  onto our `Logger.t`? Something else? This is one of those cross-cutting
  concerns that are so annoying.
- How long should we ban by default?
