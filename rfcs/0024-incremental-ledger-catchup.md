## Summary

The origin transition catchup design has performance issues. In
current implementation, we would always downloading the a list of transitions
from requested hash to peer's root (plus the entire root history).
This is not very efficient in a realistic setting where k is ~3000. The new
design features
1) avoids requesting unnecessary transitions;
2) instead of having a monolithic request to download everything; try to
   download small pieces from different peers at the same time.

## Motivation

The new design would improve the efficiency of doing ledger catchup.

## Detailed design

Split ledger catchup into 2 phases:

1) instead of requesting a path/list of transitions from the requested hash to
   peer's root (plus the root history), requesting a path/list of hashes. And
   then use this path of hashes to compute the list of missing
   transitions.
   
2) Depending on the size of the list of the missing transitions, spawn one or
   more parallel requests to get the missing transitions from peers.
   
## Drawbacks & unsolved questions

Asking peers to return a list of hashes is hacky. Malicious attackers could
return a list of garbage and we have no way to verify that list of hashes.

I am trying to find a better way than that.

## Rationale and alternatives

We currently have an almost stable testnet which is quite small. We are
moving toward the direction of solving the known performance issues that would
hinder us from scaling up to a more realistic setting.

## Prior art

The current implementation is summaried in the `Summary` part.
