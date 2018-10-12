# Summary
[summary]: #summary

A proposal for how to think about SNARK-worker work-choice policies.

# Motivation
[motivation]: #motivation

On any given tip, there is a pool of SNARK work that needs to be done.

This work occurs in sequence $w_1, \dots, w_n$.

Let's say node with capacity $c$ can choose some subset of this work to do
in a given time slot. Further let's say there are $k$ SNARK-workers across
the network, with worker $i$ having capacity $c_i$.

We want to choose a default policy for nodes choosing which work to do in
such a way that

a. When a new block happens, there is a long prefix of completed work.
b. The amount of duplicated work across the network is small.

Until [this PR](https://github.com/o1-labs/nanobit/pulls/802). Each worker
was essentially given a uniform-random, order `c_i` subset of the available work.
This had the consequence that very often the longest prefix of completed work
was tiny, since you only have to miss one early piece of work to spoil the
prefix. So it was crappy on (a) but at least achieved (b).

# Detailed design
[detailed-design]: #detailed-design

This is the technical portion of the RFC. Explain the design in sufficient detail that:

- Its interaction with other features is clear.
- It is reasonably clear how the feature would be implemented.
- Corner cases are dissected by example.

# Drawbacks
[drawbacks]: #drawbacks

Why should we *not* do this?

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

- Why is this design the best in the space of possible designs?
- What other designs have been considered and what is the rationale for not choosing them?
- What is the impact of not doing this?

# Prior art
[prior-art]: #prior-art

Discuss prior art, both the good and the bad, in relation to this proposal.
A few examples of what this can include are:

# Unresolved questions
[unresolved-questions]: #unresolved-questions

- What parts of the design do you expect to resolve through the RFC process
  before this gets merged?
- What parts of the design do you expect to resolve through the implementation
  of this feature before merge?
- What related issues do you consider out of scope for this RFC that could be
  addressed in the future independently of the solution that comes out of this
  RFC?
