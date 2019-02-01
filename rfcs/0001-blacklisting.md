# Summary
[summary]: #summary

Punish peers by refusing to connect to their IP when they misbehave.

# Motivation
[motivation]: #motivation

Our software receives diffs, transactions, merkle tree components, etc from
other peers in the network. Much of this is authenticated, meaning we know what
the resulting hash of some object must be. This happens for the `syncable_ledger`
queries and the staged ledger aux data. When a peer sends us data that
results in a state where the hash doesn't match, we know that the peer was
dishonest or buggy. Some other instances of misbehavior that we want to punish
with a ban:

- A received SNARK fails to verify
- An external transition was invalid for any of a number of reasons
- A VRF proof fails to verify

When a node misbehaves, typically it is trying to mount an attack, often a
denial of service attack. We can mitigate the effectiveness of these attempts
by just ignoring that node's messages.

# Detailed design
[detailed-design]: #detailed-design

The basic design is pretty obvious: when a peer misbehaves, notice this, add
their IP to a list, and refuse to communicate with that IP for some amount of
time.

For this we have a persistent table mapping IPs to ban scores.

Introduce the banlist:

```ocaml
module type Banlist_intf = sig
  type t

  type ban =
  { host: string
  ; score: int
  ; reason: string option
  ; remaining_dur: Time.Span.t }

  val record_misbehavior : t -> host:string -> score:int -> ?reason:string -> unit

  val ban : t -> host:string -> ?reason:string -> dur:Time.Span.t -> unit

  val unban : t -> host:string -> unit

  val bans : t -> ban list

  val lookup_score : t -> host:string -> int option

  val flush : t -> unit Deferred.t
end
```

First, where the code currently has `TODO: punish` or `Logger.faulty_peer`, we
should insert a call to `record_misbehavior`. When the score for a host exceeds
some threshold, the banlist will make sure that:

- The banned hosts won't show up as a result of querying the membership layer
  for peers
- RPC connections from those IPs will be rejected.

The banlist should be persistent, and the CLI should allow manually
adding/removing IPs from the banlist:

```
coda client ban add IP duration
coda client ban remove IP
coda client ban list
```

By default, bans will last for 1 day.

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

- Is there any reason to have a more sophisticated ban policy?
