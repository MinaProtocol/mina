---
title: Scanning for Scans
date: 2018-12-18
author: Brandon Kase
---

While developing [Coda](https://codaprotocol.com), we came across an interesting problem that uncovered a much more general and potentially widely applicable problem: Taking advantage of parallelism when combining a large amount of data streaming in over time. With much iteration, we were able to come up with a solution that scales up for any throughput optimally while simultaneously minimizing latency and space usage. We’re sharing our results with the hope that others dealing with manipulation of online data streams will find them interesting and applicable.

## Background

A transaction SNARK proof tells us that given some starting account state $$\sigma_0$$ there was a series of transactions that eventually put us into account state $$\sigma_k$$. Let’s refer to such a proof as $$\sigma_0 \Longrightarrow \sigma_k$$. So what does it mean for a single transaction to be valid? A transaction, $$T_i^{i+1}$$, is valid  if it can successfully transition our account state $$\sigma_i$$ to some new state $$\sigma_{i+1}$$ and so is represented as $$\sigma_iT_i^{i+1}\sigma_{i+1}$$. We could recompute this proof for every new transaction, but that would be slow, with the cost of generating a proof growing with the number of transactions—instead we can reuse the previous proof recursively. So as transactions appear over the network, we fold them recursively into what we call “ledger proofs”. These ledger proofs are a big part of how Coda allows any users to be sure that the database and consensus state have been computed correctly.[^1]

[^1]: `~foo` in OCaml means a named argument, and `::` means “cons” or prepend to the front of a linked list

```ocaml
(* scan [1;2;3] ~init:0 ~f:(fun b a -> b + a) => [1,3,6] *)
val scan : 'a list -> ~init:'b -> ~f:('b -> 'a -> 'b) -> 'b list
```

A scan is a type of reduction operation that produces every intermediate value as the data is being computed. As you see we build up a list of intermediate results as we’re feeding back those results via the `~init` argument.

![Each transaction emits a proof that we can use along with the next transaction to get our next proof](/static/blog/scans/merge-tree3.png)

## Requirements

Now that we understand the root problem, let’s talk about requirements to help guide us toward the best solution for this problem. We want to optimize our scan for the following features:


1. Maximize transaction throughput

Transaction throughput here refers to the rate at which transactions can be processed and validated in the Coda protocol network. Coda strives to be able to support low transaction fees and more simultaneous users on the network, so this is our highest priority.


2. Minimize transaction latency

It’s important to minimize transaction latency to enter our SNARK to keep the low RAM requirements on proposer nodes, nodes that propose new transitions during Proof of Stake. (footnote: The more we sacrifice latency the longer proposer nodes have to keep around full copies of the state before just relying on the small SNARK itself). SNARKing a transaction is not the same as knowing a transaction has been processed, so this is certainly less important for us than throughput.


3. Minimize size of state

Again, to keep low RAM requirements on proposer nodes we want to minimize the amount of data we need to represent one state. If latency is non-unitary, we’ll need to materialize more copies of the state.

And moreover, this is the order of importance of these goals from most to least important: Maximize throughput, minimize latency, minimize size of state.

## Properties

Assumptions:

- Let’s say for simplicity that all SNARK proofs take one unit of time to complete
- Transactions arrive into the system at a constant rate $$R$$ per unit time
- We effectively have any number of cores we need to process transactions because we can economically incentivize actors to perform SNARK proofs and use transaction fees to pay those actors. (footnote: This is possible because of a cryptographic notion known as “Signature of Knowledge” which lets us embed information about the creator and a fee into the proof in a way that is unforgeable. We will talk more about how we use this information in another blog post.)

### Naive Periodic Scan

|          | Throughput (in data per minute) | Latency (in seconds) | Space (in nodes) |
| -------- | ------------------------------- | -------------------- | ---------------- |
| $$R=2$$  | 6                               | 40                   | 5                |
| $$R=4$$  | 6                               | 60                   | 11               |
| $$R=8$$  | 8                               | 80                   | 23               |
| $$R=16$$ | 12                              | 100                  | 47               |




