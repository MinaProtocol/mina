## Summary

During the ITN stress testing it was noticed that daemon's memory
consumption tends to increase dramatically after a block containing a
large number of zkApp commands. Before appropriate optimizations can
be developed, we need a temporary solution to prevent nodes crashing
due to insufficient memory. The idea is to limit the number of zkApp
commands that can be included in any single block.

## Motivation

By limiting the number of zkApp commands going into blocks we avoid
the aforementioned issue until a proper solution can be devised and
implemented. The root cause of the issue is that proofs contained
within these commands are stored in the scan state and tend to occupy
a lot of space. Fixing these storage issues won't affect the
protocol, so ideally we want a workaround that doesn't affect the
protocol either, so that at the convenient time we can turn it off
without making a fork.

## Detailed design

Since the solution should not affect the protocol, it should be
implemented at the mempool/block producer boundary. In the mempool
there is `transactions` function, which returns a sequence of
transactions from the mempool in the order of decreasing transaction
fees. The block producer module just takes a number of transactions
from that sequence and includes them. It is relatively easy to limit
the number of zkApp commands returned by this functions.  ZkApp
commands above a certain limit would simply be discarded (from the
sequence, but not from the mempool).

The exact number of zkApps allowed in each block should be set
dynamically, so that we can adjust it without redeploying nodes.
The easiest way to control it is through a command line argument
to the node. Thus changing the setting is as easy as restarting
the node.

The setting can be stored in the mempool configuration and
initialized when the mempool is being created at startup.
It will likely involve some plumbing to transport the setting
from the command line arguments to the function which initializes
the mempool, but other than that the solution is quite
straightforward to implement.

## Drawbacks

Any non-protocol-level solution to this issue has a drawback that a
malicious node operator could modify their node to turn off the
safeguard. However, because the safeguard only affects block
production, it doesn't really matter unless the malicious agent is
going to produce blocks. If so, their chance of conducting a
successful DoS attack against the network is proportional to their
stake, but their incentive to do so is **inversely** proportional
to their stake, which means the more capable one is to conduct the
attack, the more they are going to lose in case of success.

With the safeguard turned on, if the zkApps are coming in faster than
they can be processed, they will stack up in nodes' mempools.
Mempools **will** eventually overflow, which means that either some of
these zkApp commands or some regular user commands will start to
drop. This will likely inflate transaction fees as users will attempt
to get their transactions into increasingly crowded mempools. Also a
lot of transactions will be lost in the process due to mempool
overflow.

## Rationale and alternatives

This is a temporary solution until the scan state storage can be
optimised to accommodate storing proofs more efficiently. Therefore
it is more important that it's simple and easy to implement than
to solve the problem in a robust manner. Because the issue endangers
the whole network, some smaller drawbacks are acceptable as long as
the main issue is prevented from happening.

An alternative would be to assign more precise measurement of memory
occupied to each command and limit the amount of the total memory
occupied by commands within a block. Better still, we could compute
the difference in memory occupied by the scan state before and after
each block and make sure it does not go above certain limit.  This
would, however, complicate the solution and require more time to
develop it, while it sill wouldn't properly solve the problem.
Therefore we should strive for a quick solution which already improves
the situation and wait for the proper fix to come.

## Prior art

The problem of blockchain networks being unable to process incoming
transactions fast enough is a well-known one and there are several
techniques of dealing with it.

One solution is to limit the block size (and hence indirectly the
number of transactions fitting in a single block). The most notable
example here is Bitcoin, which has a hard block size limit of 1MB.
This is often criticized for limiting the network's throughput
severely, but the restriction remains in place nonetheless, because
the consequences of lifting it would be even worse.

Mina also has its own block size limit, however, the problem we are
dealing with here is different in that we've got two distinct
categories of commands, only one of which is affected. Unfortunately,
unless we move zkApp commands to a separate mempool, any limit set on
zkApp commands throughput will also affect user commands by occupying
mempool space (see Drawbacks above).

Another solution is more related to execution time, especially that of
smart contracts, which can - in principle - run indefinitely without
termination and there is no easy way of preventing this without
hindering expressiveness of a smart contract language significantly
(due to insolvability of the halting problem). Major blockchains like
Ethereum or Tezos, instead of limiting block size directly, restrict
the number of computational steps (defined by some VM model) necessary
to replay a block. A block which cannot be replayed in the specified
number of steps is automatically considered invalid.

The operation's execution time is modelled with gas. Each atomic
computation is assigned a gas cost roughly proportional to the time
the VM takes to execute that computation. Simultaneously, a block
is given a hard gas limit and the total gas required by all the
transactions within the block must be below that limit.

Translating this solution to the discussed problem would involve
modelling memory occupied by each operation in the scan state with
some measure (analogous to gas) and then limiting the maximum value
of operations (expressed in that measure) fitting in a block. This
is a more complex solution than the one proposed here and probably
requires significant time to devise the right model. It wouldn't
also remove the problem of zkApp commands stacking in the mempool,
although it might make it less severe by setting a more fine-grained
limit. However, considering that it would still be a temporary
solution, it's probably not worth the effort.

## Unresolved questions

Are the drawbacks described in this document an acceptable trade-off
for preventing crashes due to out-of-memory issues? Is the
alternative, more fine-grained solution viable?

## Testing

As any change involving mempool and block production, it would require
an integration test to check. Such a test could generate a lot of
zkApp commands and observe how they stack in the mempool. It could
also verify that regular payments get included to fill remainder
of space available in each block.
