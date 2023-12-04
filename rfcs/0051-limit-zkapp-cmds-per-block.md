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
fees. The `create_diff` function in `Staged_ledger` then takes that
sequence and tries to apply as many transactions from it as can fit
into the block. In the latter function it is possible to simply
count successfully applied zkApp commands and filter out any
transactions which:
- would violate the set zkApp command limit
- or depend on any previously filtered transactions because of
  a nonce increase.

The exact number of zkApps allowed in each block should be set
dynamically, so that we can adjust it without redeploying nodes.
Therefore we are going to provide an authorised GraphQL mutation
to alter the setting at runtime. A sensible default will be compiled
into the binary as well.

The setting can be stored in the Mina_lib configuration and
initialized when the mempool is being created at startup.
The limit will also be controllable through an authenticated GraphQL
mutation, which will update the setting in the configuration at
runtime.

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

Some payments and delegations may wait a long time for inclusion or
even get dropped if they are created by the same fee payer as a
zkApp command waiting for inclusion due to the limit. This cannot
be helped, unfortunately.

Another risk arises when we decide to turn of the limitation, because
the underlying issue is fixed. In order to safely turn the limit
off, a node needs to be updated with the fix. Because this will be
a non-breaking change, nodes may be slow to adopt it. According to
rough estimates, if 16% of the stake upgrades and turns the limit
off, they're capable of taking the non-upgraded nodes down with
memory over-consumption and taking over the network. To prevent this
we have to ensure that at least the majority of the stakeholder
upgrades as quickly as possible.

Finally, the limit introduces an attack vector, where a malicious
party can submit `limit + 1` zkApp commands and arbitrarily many more
commands depending on them, so that they are guaranteed not to be
included. They can set up arbitrarily high fees on these commands
which won't be included in order to kick out other users' transactions
from the mempool and increase the overall fees on the network. An
attacker would have to pay the fees for all their included zkApp
commands, but not for the skipped ones Then they can use another
account to kick out their expensive transactions form the mempool. So
conducting such an attack will still be costly, but not as costly as
it should be.

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
develop it, while it still wouldn't properly solve the problem.
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
