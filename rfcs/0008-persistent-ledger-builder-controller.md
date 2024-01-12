# Summary
[summary]: #summary

This adds a persistent backend for the ledger builder controller.

# Motivation
[motivation]: #motivation

Having a persistent backend will allow nodes that go offline, whether for a short period or an extended period of time, to catch back up to the network with as little work as reasonably possible.

# Detailed design
[detailed-design]: #detailed-design

In order to achieve this, we will persist the locked tip using the existing Merkle database. The backend Merkle database is designed in a way such that queries for the most commonly performed operations can be batched together as one request to the database.

The best tip, materialized by the ledger builder controller, will be represented as a Merkle ledger mask on top of the persistent Merkle ledger database. This data structure will only store the modified nodes of the Merkle ledger in memory, and defer to the contents of the persistent Merkle ledger database for any information outside of that. The persistent Merkle ledger database will maintain a reference to all of these data structures derived for it. These references will be used to garbage collect outdated information in the mask representations whenever changes are written to the persistent copy. In other words, information will be removed from the mask whenever it is no longer different from the information in the underlying database, ensuring that the data structure will not leak memory. If a mask is empty, it may need to be retained, in case there are existing references to it.

There may be several points between the locked tip and the best tip, and we may need to examine any such point. For performance reasons, we'll daisy-chain masks on top of one-another all throughout the tree. Whenever an underlying db updates, changes should only be propagated to the immediate mask-children of that DB. Because masking is associative, we can merge mask-children in with there parents without needing to notify any children. In [RFC 0009](0009-transition-frontier-controller.md), we take advantage of this property.

These representation choices involve trade-offs that should be considered. The Map representation contains just key and value data, while the prefix tree representation add summary hashes, which could consume more memory. To find account data with the Map, where the account does not appear in that mask, would mean first consulting the mask, which fails, then making an additional database lookup. That could be slower than a lookup in the prefix tree, where summary hashes could be used to guide the database lookup without a failure step.

There's an existing Sync functor that takes a database module, to perform catchup operations. The masks just described work also with a database, so a MakeMask functor that takes a database module would be a way to make this setup work. The database module that's passed in is not copyable, but both the Sync and Diff functors will offer a copy function to copy their local data, leaving the underlying database unaffected.

Later, a cache can be introduced onto the Merkle ledger database, allowing us to perform fewer database queries for commonly looked up information. The details of caching, however, is not addressed as part of this particular RFC. See [Use Merkle mask as a proxy](https://github.com/CodaProtocol/coda/issues/1073), which requests such a feature.

The module type for the mask could be:

  ```ocaml
  module type Mask = sig
    type t
	type key
	type value

    type db = Database_intf.S.t

    (* group identity, operations *)
    val empty : t
    val add : t -> t -> t
	val inverse : t -> t

    val insert : key -> value -> t -> t
	val remove : key -> t -> t
    val from_list : (key * value) list -> t

    (* look up in diff; if key not present, delegate to database for locked tip *)
    val get : db -> key -> value option
  end
  ```

# Drawbacks
[drawbacks]: #drawbacks

The drawback of this is that the persistent Merkle database is not easy to copy. However, this is by design, as there is only one copy that should be persisted as the central source of truth. Any other information which we wish to persist should live outside of this representation. For instance, if we want to persist the best tip, then only the diff between that tip's database and the locked tip's database should be stored. This is much more efficient for both storage and quick synchronizing, in the case of short term downtimes.

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

An alternative design is to restructure the persistent database so that it can be cheaply copied. This can be done by keying nodes not by their path in the Merkle tree and instead use keys that directly identify nodes, and only copy the nodes that are modified for the copied database. However, there are a few issues with this. For one, it makes many of the common queries to the data structure far less efficient. If you want to find a leaf given a path, you would need to make `k` successive requests to the database, where `k` is the depth of your tree, versus the single request of bulk lookups required by the other representation. This concern can be alleviated with more indices into the database, but those in turn also introduce more request requirements, and also increase the cost of garbage collection. The second reason is that garbage collection could prove challenging. The main logic behind when something is considered garbage is simple: keep a ref count for each node, and when it's zero, delete it. But, that adds cost to each operation on nodes; or, alternatively, requires us to perform collection cycles in our scheduler. This also becomes exponentially more complex as we add in indices to make the representation more efficient, which will be necessary. Thirdly, this representation adds even more accesses to the database, since you need to do all work with ledger through the database. This will make caching more important for efficiency, and if you are already going to represent the active part of the ledger in memory via a cache, why not just opt for the more efficient representation on the persistent side and use an in memory abstraction for representing the active part of a ledger.

# An algebra of masks

It may be useful if there are operations on masks with nice mathematical properties. For example, there could be an addition operation on masks that results in the composition of those masks. To "undo" a mask, one could produce the negation of a mask. These ideas suggests an algebraic group, where the carrier set is the set of masks.
