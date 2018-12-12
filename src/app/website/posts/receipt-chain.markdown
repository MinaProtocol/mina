---
title: How to make a scalable blockchain (1), techniques of SNARK 
How do you prove you sent someone a transaction when there's no blockchain?
date: 2018-03-11
---

As we wrap up 2018 at O(1) Labs, we thought it would be fun to look back on
the year's developments, highlighting some interesting aspects TODO

Let's imagine Alice and Bob have gone to the grocery store. Alice gets a jar
of peanut butter and a bunch of bananas, the total ringing up as 8 Coda.
Bob gets some cheddar cheese and a loaf of bread, which also ends up costing
8 Coda. They both go to pay the grocery store at their separate cashiers at
about the same time. But now there seems to be an issue, the grocer's balance
has gone up by only 8 Coda: one of Alice's or Bob's transactions failed to go
through.

Alice needs to get to basketball practice and Bob is meeting his friend Carol to
eat the bread, so each is anxious to get out of there. So, each wants to convince
the grocer that their transaction was the one that went through.

If Alice and Bob were using a heavy blockchain the answer would be clear: just have the grocer look
through the transaction history on the blockchain to see which was sent. But Alice
and Bob are using Coda, where there is no history stored on the blockchain. How can
they convince the grocer that their transaction was sent?

Let's discuss some potential solutions, and then how Coda actually solves this problem.

# Potential solution 1: One grocer account per cashier
The above was predicated on the grocer having only one account. If
the grocer had one account per cashier, there would be no ambiguity
about who sent the money. This is a totally valid solution and could
be done with Coda. However, having multiple accounts has some drawbacks.
Besides the complexity of managing them, if the grocer wanted to later
combine them, they would have to explicitly send transactions to do so,
costing them in fees.

As such, we'd like to find a solution that makes it possible to know who
sent you Coda even with one account.

# Coda's solution: receipt chains

Somehow, we want to have Alice's account encode all the transactions she's
sent. We don't want to actually store the transactions though, as we're
trying to keep our blockchain constant-sized. What to do? The solution
is pretty simple: use a blockchain! Specifically, we'll store a hash in
Alice's account which is equal to `H(t_n, H(t_{n-1}, H(..., H(t_1, "")...)))`
where `t_1, ..., t_n` are all the transactions that Alice has sent. Let's
call this hash Alice's "receipt chain hash".

Coda's SNARK ensures that this hash is updated correctly when Alice sends a new
transaction. Now if Alice wants to convince the grocer that she sent the
transaction, she justs needs to show them her current receipt chain hash `h_n`,
the transaction `t_n` that she sent them, and her previous receipt chain hash
`h_{n-1}`. The grocer then computes `H(t_n, h_{n-1})` and checks that it's
equal to Alice's current receipt chain hash `t_n`. This is just a Merkle
inclusion proof. The grocer knows that Alice's current receipt chain hash is indeed
`h_n`, because they have Coda's succinct-blockchain guaranteeing it.

It turns out it was Alice's that went through, so she goes off to basketball while
Bob resends his transaction and then goes to eat some bread.

# Drawbacks and future improvements

One drawback of this approach is that the inclusion proofs grow linearly with the
number of transactions one sends. This could be improved to logarithmic by using
a Merkle tree instead of a Merkle list (or possibly a tree combined with a list).

# Wrapping up

I hope you enjoyed this post and stay tuned for more secrets of Coda.
