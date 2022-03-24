## Mitigations for DOS attacks based on bogus transactions

We add some rules for deciding whether to store incoming transactions in the
pending transaction pool and gossip them. I'm using the phrase "pending
transaction pool" or "txpool" rather than "mempool" because I think it's
clearer. Lots of things are stored in memory. This is a simple approach that
offers basically equivalent DDoS resistance to existent cryptocurrencies. I have
some ideas for attacks that work against them and this, as well as a more attack
resistant design, but it's much more complicated. See [the private document](https://docs.google.com/document/d/1FhBThENWdSN6bfT4re_tt78uMjViSan5f212faabBNg/edit?usp=sharing) for
those.

## Motivation

Every transaction consumes resources: computation, storage, and bandwidth. In
the case of transactions that are eventually included in a block, those
resources are priced by transaction fees. But transactions that are never
included in a block don't pay transaction fees, so without good design bogus
transactions could be a vector for cheap DoS attacks. We want to make sure it
costs enough to make nodes consume resources that a DoS attack is too expensive
to be worthwhile.

(The transaction fees for *mined* transactions may or may not accurately reflect
the total cost to all network participants for processing the transaction, but
that's a problem for another day.)

We can't control what transactions we receive, but we can control whether we
store them and whether we forward them on, making other nodes deal with them.

## Detailed design

As a general principle, we want to accept transactions into the pool iff they
will eventually be mined into a future block. That's the purpose of the pending
transaction pool. For DoS protection, we assume that the cost of including a
transaction in a block is sufficient to deter DoS attacks on proposers, since
the cost of creating a SNARK greatly exceeds the cost of checking and storing an
incoming transaction. Where possible, we prefer to charge for things rather than
banning them. We don't mind if someone uses a lot of resources, so long as those
resources are paid for at a price that network participants would be happy with.

In this context, we have the following goals:

1.  Support a pool of pending transactions with a maximum size, evicting
    transactions when at the maximum size based on fee.

2.  Allow multiple queued transactions from one address. Since payments aren't
    instant, users will want this. We could make transaction senders responsible
    for queuing, but that wouldn't allow multiple transactions sent from the
    same address to be included in the same block.

3.  Allow for transaction replacement, while aligning incentives by charging for
    it appropriately. Users can e.g. cancel payments by replacing them with a
    no-op transaction (send themselves $0) or resend them with a higher fee if
    they're processing too slow. This is important for two reasons. A) a
    transaction sent with too low of a fee will get "stuck", and without the
    ability to replace it the user's account is bricked until the transaction
    ages out of the txpool or is evicted if the pool is full. B) a transaction
    sent with too low of a fee may simply take long enough that the user would
    rather not have sent it. E.g. if I'm buying a coffee I don't want to wait in
    the shop for half an hour while my payment goes through. Or if I'm using a
    market based on smart contracts and my trade execution is delayed, the reason
    I wanted to make the trade may no longer be valid when it actually executes.

### When we first receive a transaction: rules

When we receive a gossiped transaction, we will check the below constraints,
with respect to our current longest chain. If any of the checks fail, we ignore
the transaction and do not gossip it.

1.  The signature.

2.  The sender's account exists.

3.  The sender's balance (inclusive of any pending txs from the same account
    with lower nonce) is >= the transaction amount + fee.

4.  The tx nonce is equal to the sending account's next nonce, inclusive of
    transactions already in the pool. (If it conflicts with one in the pool, see
    below.)

#### New punishment scheme

There are scenarios where an honest node may send us transactions we don't want,
e.g. insufficient fee transactions if their pool is less full than ours or
out-of-date transactions if they're behind us. These consume resources but are
useless to us, and attackers may send lots of them. So we need a way to punish
nodes for sending them, while not banning innocent nodes. We may also be subject
to Sybil attacks - an attacker may create lots of nodes that never do anything
bannable but also don't properly gossip or otherwise contribute. They can
degrade service if the Sybil nodes crowd out real ones. So we want a way to
reward nodes for good conduct, and to punish them for bad but potentially honest
conduct.

So we modify `banlist.ml` and friends. Rather than a node being either `Normal`,
`Punished`, or `Suspicious`, every node has a continuous, real valued "trust"
score. Nodes that give us useful data gain trust, nodes that give us useless
data lose trust, and nodes that give us invalid data lose a lot of trust. Trust
exponentially decays towards zero over time, with the decay rate set such that
half of it decays in 24 hours. This works out to decay factor of
~0.999991977495368389 as applied every second. We'll update trust scores lazily:
for each node we store the score the last time it was updated, and the time it
was updated. The new score = `decay_factor**(seconds since last update) * old
score`. We'll need to adapt the existing code that bans/punishes peers.

If a node's trust goes below -100, we'll ban it for 24 hours. In the future it
may be worth it to prioritize nodes based on trust rather than using a sharp
threshold. This would mitigate Sybil attacks: if we bias peer selection towards
more trusted nodes, then an attacker would have to contribute in order to get
connections, and can't crowd out honest nodes. The best way to do that is to
modify the Kademlia system. The way it works now is that nodes are prioritized
in buckets based on how old they are - on the basis that nodes that have been up
for longer are likelier to continue to be up than newer ones, and that having to
run nodes for a long time makes Sybil attacks expensive. We'd replace age with
trust score. But this is a pretty substantial modification (and maybe we're
replacing kad anyway?), so for now we'll just use the discrete banned/not banned
state.

If we get any transactions where the signature is invalid, we reduce the peer's
trust by 100, effectively banning it for 24 hours. No honest node sends
transactions like that. If we get transactions that fail for other reasons - the
ones that depend on the current chain state - then we reduce the peer's trust by
`tx_trust_increment`. If we accept the transaction we increase trust by the same
amount. Honest nodes that are out of date might innocently send us transactions
that are not valid, but they won't send us a lot of them. If a node detects it
is substantially behind the network, it should disable gossip until it catches
up.

There was [some discussion](https://github.com/minaprotocol/mina/pull/761#issuecomment-424456658)
about score decay when the RFC for banlisting was first proposed. It wasn't
resolved and the current system doesn't implement any decay. A punishment score
system with decay is equivalent to trust scores if you only count bad behavior.
These are pretty close in effect, especially when we're doing discrete bans
rather than prioritization, but there is an important difference. Imagine a very
active peer, an exchange or a payment processor or something. It's not beyond
the realm of possibility for a single node to send 1000txs/hr, especially since
scalability is one of our core goals. If such a peer sends e.g. 2% bad
transactions due to network delay + data corruption + whatever else, it will be
banned if we only track bad behavior and not good - its punishment score will
rise over time, by assumption faster than the decay. In this design with trust
scores, its trust will increase faster than it falls and everything will be
fine.

#### Replacing transactions

A useful feature of existing cryptocurrencies is the ability to replace a
pending transaction with a different one by broadcasting a new one with the same
nonce.

We want to have this feature, but it allows an attacker to make proposers
process transactions which won't eventually get mined (the ones that are
replaced), which violates our first guiding principle. So we require the fee of
the new transaction be at least `min_fee_increment` higher. This is the
"standard" approach.

#### Multiple pending transactions from the same account

Since payments aren't instant, users may want to queue multiple outgoing
transactions. This listed rules above cover this case, but things get
complicated when you allow transaction replacement. Imagine Mallory broadcasts
1000 valid transactions with sequential nonces, then replaces the first one with
one that spends all the money in the account. The other 999 of them are now
invalid and won't be mined, but the proposers still had to validate, store and
gossip them, violating our first principle. So the new fee in the example needs
to be at least `min_fee_increment` * 1000 higher.

### When txpool size is exceeded: rules

We have a set limit on txpool size: `max_txpool_size`, in transactions. If an
incoming transaction would cause us to exceed the limit, we evict the lowest fee
transaction from the mempool, or drop the incoming transaction if its fee is <=
the lowest fee transaction in the mempool.

If an incoming transaction has too low of a fee for us to accept, we count it as
bad for the purposes of trust scores. Except in the case of replacement
transactions. If we punished nodes for sending transactions without the
replacement fee increment, an attacker could induce nodes to banlist each
other by sending them different transactions at the same nonce.

### Constants

-   `tx_trust_increment`: Let's say we target a max rate of bad transactions of
    one per 10 seconds. The maximum rate bad transactions can be sent at without
    getting banned is when the peer is just below the ban threshold -
    exponential decay means the trust decays fastest when it's absolute value is
    highest. The ban threshold is 100, so the algebra comes out to
    `100 * decay_rate ** 10 + 100` = 8.022215015188294e-3.

-   `max_txpool_size`: This is interesting. If there were a fixed limit on the
    number of transactions per block I'd say set it to an hour's worth or
    something. But the limit is set by the parameters of the parallel scan, and
    supposedly that'll become dynamic in the future, so I'm not sure. So let's say
    1000?

## Drawbacks

This is vulnerable to the attack in the private document.

## Rationale and alternatives

-   Why is this design the best in the space of possible designs?

There is virtue in simplicity, especially in a winner-take-all market like ours.
This is simple and relatively easy to implement and not worse than what else
exists. A fancier thing would delay launch further.

-   What other designs have been considered and what is the rationale for not choosing them?

    -   Allow pending txs that spend money not (yet) in the sender's account

        Ethereum does this. It's abusable, an attacker can send transactions that
        will never be mined. The countermeasure is having a hard limit on pending
        transactions per account, which I don't like:

    -   Max pending tx per account

        There are legitimate use cases for sending lots of transactions from one
        address rapidly, and I strongly prefer charging for things to banning
        things. For an example, imagine an exchange. To process withdrawals they may
        need to send 100s of transactions per minute from a single address. So long
        as that is priced efficiently they should be able to do so. Yes, they should
        probably be doing transaction batching in this scenario, but it's better
        that doing individual transactions is expensive than if it were impossible.

    -   Skip validation for speed

        This is (partly) what we do now, and is vulnerable to all sorts of stuff.

    -   Block lookback window for validity.

        Part of Brandon's original plan was to accept transactions that were valid
        at any point in the transition frontier, or within some fixed lookback from
        a current tip. This is abusable. Mallory can move funds around such that she
        can make transactions that were valid recently but aren't now, and consume
        resources for free. The attack requires her to move them around at least
        once every lookback window blocks, and lets her consume resources for
        lookback window blocks, so with a sufficiently small window it's probably
        impractical, but I'd rather avoid the headache. I don't see a use case for
        it. Since the account holder is the only one who can spend funds from their
        account, and since insufficient funds is (almost) the only reason payments
        can fail, they should never be sending transactions that used to be valid
        but aren't now.

    -   Have a minimum transaction fee

        In this design, an attacker can fill the txpool with bogus transactions with
        fees too low to ever be included in a block for "free". This is bad, and
        imposing a overall minimum fee that is at least as much as SNARKing a
        payment costs would prevent it, but figuring out what that minimum should be
        is complicated, and the attack is only good so long as the pool isn't full,
        so I think it's not worth it.

-   What is the impact of not doing this?

    Various vulnerabilities.

## Prior art

Ethereum allows transaction replacement, and multiple pending transactions from
the same account, without requiring they be valid when run sequentially. If a
transaction's smart contract errors out, or runs out of gas, miners get to keep
the fees. So it's sort of a like a deposit. But I don't think they check that
the there's sufficient balance in the account to cover the sum of transaction
fees from all pending transactions before accepting another transaction. That
would be expensive, since the balance of the sending account after a transaction
runs may be higher than when it started due to smart contracts. There's no
explicit replacement fee, and there's definitely no deposit system for it. There
might be a minimum fee increment though. I think they're vulnerable to some of
these attacks. They evict transactions from the mempool on a lowest-fee-first
basis.

Bitcoin will do what they call "replace-by-fee" which is the transaction
replacement thing. They may have a minimum increment, but not a deposit system.
Transactions are evicted on a lowest-fee-first basis. They allow mempool
transactions to depend on each other, but not on hypothetical future
transactions. When a transaction is evicted from the mempool, they also evict
any transactions that depend on it.

## Unresolved questions

-   What parts of the design do you expect to resolve through the RFC process
    before this gets merged?

    Decide if it's worth it to do the more complicated thing.

-   What parts of the design do you expect to resolve through the implementation
    of this feature before merge?

    Nothing comes to mind.

-   What related issues do you consider out of scope for this RFC that could be
    addressed in the future independently of the solution that comes out of this
    RFC?

    The SNARK pool has similar concerns.
