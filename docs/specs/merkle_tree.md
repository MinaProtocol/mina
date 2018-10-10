# Merkle Tree

A merkle tree is a data structure which is a binary tree in which the leaves are some arbitrary data and the branches each hashes of their successors. There are many ways to represent and compose merkle trees together. For that reason, we define various merkle trees, and unify them under a base interface. The primary representations of a merkle tree in coda are: an in memory merkle tree, an on disk key value database backed persistent merkle tree, and a sparse in memory merkle tree which can mask information on top of other merkle trees. Many of the choices made in the base interface of the merkle tree are specifically to enable masking while maintaining efficiency.

## Base Interface

The primary interactions of a merkle tree are:
- read hash
- read data
- write data
- retrieve merkle path

When accessing information of the merkle tree, a merkle location is provided. A merkle location is a length encoded bitstring. Each bit represents a binary direction to take when traversing the merkle tree, starting from the first bit. If the bit is 0, traverse left, and if the bit is 1, traverse right.

Reads are separated by hash and data as the return values are different. Both reads and writes are performed as bulk operations, meaning that the code that calls into these is responsible for batching as many reads and writes as it can at once. Batching of reads and writes is an important optimization for both the persistent database, and for the merkle tree masks. Writing data has the side effect of recalculating the preceeding hashes of that data.

Retrieving a merkle path involves traversing a given data merkle location and returning the sibling of each node in the traversal.

## Maskable Interface

A maskable merkle tree is a superset of the base merkle tree interface which allows masks to be derived from the structure.

There are also masking operations:
- register mask
- unregister mask

Registering a mask creates a new mask as a child of the merkle tree. Whenever the maskable merkle tree receives a write request, it will notify all of its children with the data modified as part of the write. More details on this are in the "Mask" section.

## Mask

A merkle tree mask is a sparse collection of merkle tree nodes which are different from its parent. Whenever a read occurs on a mask, the mask will first attempt to retrieve the node from its internal sparse collection, and if it does not exist there, will forward the read request to its parent. Writing to a merkle tree mask will only update its internal sparse collection.

The merkle tree mask implements a superset of the base merkle tree interface. The unique operations of a mask are:
- commit
- invalidate cache

Committing a merkle tree mask will cause it to bulk write all of its changes to its parent, and then clear all of its internal state. This is useful for use masks as temporary views into a set of changes that you may or may not want to apply back to another merkle tree. For instance, you may want to apply transactions to a mask first and validate the merkle path of the new tree before you update the underlying merkle tree.

Every mask provides a hook for invalidating its cache. The hook is intended to be called whenever the mask's parent is updated. This hook takes in a set of nodes that have been modified in that parent merkle tree. The invalidation rule is that if any of the nodes received by the hook are the same as the corresponding node stored internal to the mask, then that information is deleted from the mask. This works because if the parent merkle tree's node is the same as the mask's node, then reading from the mask's cache is equivalent to forwarding the read to the parent.
