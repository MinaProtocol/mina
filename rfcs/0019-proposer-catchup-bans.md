## Summary

Currently a peer would be instantly banned if it broadcast `Disconnected` transition.
By `Disconnected` transitions I mean transitions older than one's root.

This would cause some trouble for proposers that is doing ledger catchup. I propose several
different solutions to this problem.

## Motivation

The problem with currently design is that if a peer has some catchup job undergoing and
it proposes a transition before the catchup job finishes. There are chances that this peer
would produce `Disconnected` transitions.

Imagine the following scenario:

Node *A* is off by `k + 1` transitions compared to the network. This means its best tip is
worse than the root of most nodes. It certainly needs to do ledger-catchup, but since proposer
is not blocked by ledger-catchup, *A* could propose before ledger-catchup finishes. If this
happens, *A* would be banned for producing `Disconnected` transitions.

This often happens when a node just finishes bootstrap. In this state its best-tip is the root.
If the network happens to advanced by 1 block at that moment then we would see the off by `k + 1` transitions
described above.

## Detailed design
### Proposal 1: Block proposer when in ledger-catchup mode
This is an obvious solution, but this would introduce certain security flaws to our systems.
For example, a malicious user could take advantage of this design by intentionally triggering catchup on
other nodes in order to prevent them from proposing.

### Proposal 2: Modify trust system so that `Disconnected` won't cause instant ban
This means we should decrease some trust score instead of banning peers for transitions
that are older than the root but still better than root history. As for peers that broadcast
transitions that are worse than root history, we should still ban them.

If we decides to stick with this one, we should pick the amount of trust score being deducted
carefully. Since if a proposer goes on and off constantly, it could still be banned. But I believe the probability of
this happens in real world would be really low.

### Proposal 3: Block proposer when the length of best tip is not `k` (except during genesis)
The rationale behind this proposal is that we should only propose if we are fully synced.
If the length of the best tip is less than `k`, then it indicates that we are in a state that
bootstrap just finishes but ledger-catchup is still ungoing. This is the only possible state where
we have a frontier of length less than `k`.

This design should be safe in the `k + delta` situation. If the best tip is off by `k + delta` transitions,
then the root would be off by `2k + delta`, which means bootstrap should already be trigger on this node.

This proposal is the most complicated among the 3. We also needs to deal with the special case during genesis.
It could be combined with proposal 2.
