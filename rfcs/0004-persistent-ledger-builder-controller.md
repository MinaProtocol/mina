# Summary
[summary]: #summary

This adds a persistent backend for the ledger builder controller.

# Motivation
[motivation]: #motivation

Having a persistent backend will allow nodes that go offline, whether for a short period or an extended period of time, to catch back up to the network with as little work as reasonably possible.

# Detailed design
[detailed-design]: #detailed-design

In order to achieve this, we will persist the locked tip using the existing merkle database. The backend merkle database is designed in a way such that queries for the most commonly performed operations can be batched together as one request to the database.

The best tip, materialized by the ledger builder controller, will be represented as a sparse merkle ledger mask on top of the persistent merkle ledger database. This data structure will only store the modified nodes of the merkle ledger in memory, and defer to the contents of the persistent merkle ledger database for any information outside of that. The persistent merkle ledger database will maintain a reference to all of these data structures derived for it. These references will be used to garbage collect outdated information in the sparse diff representations whenever changes are written to the persistent copy. In other words, information will be removed from the sparse diff whenever it is no longer different from the information in the underlying database, ensuring that the data structure will not leak memory.

Later, a cache can be introduced onto the merkle ledger database, allowing us to perform less database queries for commonly looked up information. The details of this, however, is not addressed as part of this particular RFC.

# Drawbacks
[drawbacks]: #drawbacks

The drawback of this is that the persistent merkle database is not easy to copy. However, this is by design, as there is only one copy that should be persisted as the central source of truth. Any other information which we wish to persist should live outside of this representation. For instance, if we want to persist the best tip, then only the diff between that tip's database and the locked tip's database should be stored. This is much more efficient for both storage and quick synchronizing, in the case of short term downtimes.

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

The alternative design to this is to restructure the persistent database so that it can be cheaply copied. This can be done by not keying nodes by their path in the merkle tree and instead key nodes uniquely and only copy the node that are modified for the new copy. However, there are a few issues with this. For one, it makes many of the common queries to the data structure far less efficient. If you want to find a leaf at the bottom of the tree given a path, you would need to make `k` successive requests to the database, where `k` is the depth of your tree, versus the single request of bulk lookups required by the other representation. This can be allieviated with more indices into the database, but those in turn also introduce more request requirements, and also increase the cost of garbage collection. The second reason is that garbage collection could prove challenging. The main logic behind when something is considered garbage is simple: keep a ref count for each node, and when it's zero, delete it. But, that adds cost to each operation on nodes; or, alternatively, requires us to perform collection cycles in our scheduler. This also becomes exponentially more complex as we add in indices to make the representation more efficient, which will be necessary. Thirdly, this representation adds even more accesses to the database, since you need to do all work with ledger through the database. This will make caching more important for effeciency, and if you are already going to represent the active part of the ledger in memory via a cache, why not just opt for the more efficient representation on the persistent side and use an in memory abstraction for representing the active part of a ledger.

# Unresolved questions
[unresolved-questions]: #unresolved-questions

- How should the sparse ledger diff be represented in memory?
- Should this be designed to work with a cache from the beginning, or should we revisit that later as an optimization?
