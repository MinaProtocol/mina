# Merkle Tree

A Merkle tree is a data structure which is a binary tree in which the leaves are some arbitrary data and the branches each hashes of their successors. There are many ways to represent and compose Merkle trees together. For that reason, we define various Merkle trees, and unify them under a base interface. The primary representations of a Merkle tree in coda are: an in memory Merkle tree, an on disk key value database backed persistent Merkle tree, and a sparse in memory Merkle tree which can mask information on top of other Merkle trees. Many of the choices made in the base interface of the Merkle tree are specifically to enable masking while maintaining efficiency.

## Base Interface

The primary interactions of a Merkle tree are:
- read hash
- read data
- write data
- retrieve Merkle path

When accessing information of the Merkle tree, a Merkle location is provided. A Merkle location is a length encoded bitstring. Each bit represents a binary direction to take when traversing the Merkle tree, starting from the first bit. If the bit is 0, traverse left, and if the bit is 1, traverse right.

Reads to obtain hashes and data are distinguished, because the types returned are distinct. Write are performed as batch operations, meaning that the calling code is responsible for batching as many writes as it can at once. Batching of writes is an important optimization for both the persistent database, and for the Merkle tree masks. Writing data has the side effect of recalculating the hashes affected by that data.

Retrieving a Merkle path involves traversing a given data Merkle location and returning the sibling of each node in the traversal.

## Maskable Interface

A maskable Merkle tree is a superset of the base Merkle tree interface which allows masks to be derived from the structure.

There are also masking operations:
- register mask
- unregister mask

Registering a mask creates a new mask as a child of the Merkle tree. Whenever the maskable Merkle tree receives a write request, it will notify all of its children with the data modified as part of the write. More details on this are in the "Mask" section.

## Mask

A Merkle tree mask is a sparse collection of Merkle tree nodes which are disjoint from its parent's nodes. Whenever a read occurs on a mask, the mask will first attempt to retrieve the node from its internal sparse collection, and if it does not exist there, will forward the read request to its parent. Writing to a Merkle tree mask will only update its internal sparse collection.

The Merkle tree mask implements a superset of the base Merkle tree interface. The unique operations of a mask are:
- commit
- update on parent notification

Committing a Merkle tree mask will cause it to batch write all of its changes to its parent, and then clear all of its internal state. This is useful for use masks as temporary views into a set of changes that you may or may not want to apply back to another Merkle tree. For instance, you may want to apply transactions to a mask first and validate the Merkle path of the new tree before you update the underlying Merkle tree.

Every mask provides a hook for updating its cache. The hook is intended to be called whenever the mask's parent is updated. This hook takes in a set of nodes that have been modified in that parent Merkle tree. The invalidation rule is that if any of the nodes received by the hook are the same as the corresponding node stored internal to the mask, then that information is deleted from the mask. This works because if the parent Merkle tree's node is the same as the mask's node, then reading from the mask's cache is equivalent to forwarding the read to the parent. When nodes are considered to be the same is not considered here.
