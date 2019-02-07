FIFO change:

Before the  change, in the parallel scan state, the proofs were expected in the order of the transactions processed i.e., proofs for newly created `merge` statements of older transactions were consumed before the `base`/`merge` proofs of newer transactions that could have existed for a while in the pool.

Changing it to consume proofs int the order of statement creation irrespective of the order in which transactions are processed. Therefore, the statement which gets created first, its proof is consumed first.  A FIFO consumption of proofs. The transaction order, however, is tracked in order to fold over the tree to chain the statements correctly (used to validate the tree state).

This required adding an extra 2xtree-space for the case when all the proofs are available at every block and throughput fluctuates.