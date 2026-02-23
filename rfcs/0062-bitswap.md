# Summary
[summary]: #summary

This RFC proposes adding Bitswap to our libp2p networking stack in order to address issues related to our current gossip network pub/sub layer.

# Motivation
[motivation]: #motivation

Mina has very large messages that are broadcast over the gossip net pub/sub layer. This incurs a high bandwidth cost due to the nature of our pub/sub rebroadcast cycles work in order to consistently broadcast messages throughout the network. For example, we observer blocks on mainnet as large as ~2mb. This would represent only a single block, and each block broadcast message has a multiplicative cost on bandwidth as it's being broadcast throughout the network. This bandwidth cost also translates into CPU cost due to the cost of hashing incoming messages to check against the de-duplication cache before processing them. We currently observe behaviors where the libp2p helper process can be pegged at 100% CPU on certain hardware setups when there is high pub/sub throughput on the network. Since gossip pub/sub is used not only for blocks, but also transactions and snark work, the broadcasting of each of these simultaneously ends up compounding the issue.

Implementing Bitswap in our libp2p layer will address this issue by allowing us to immediately reduce our pub/sub message size, while making the larger data referenced by pub/sub messages available upon request. It provides a mechanism for breaking up large data into chunks that can be distributed throughout the network (streamed back from multiple peers), and a system for finding peers on the network who are able to serve that data.

# Detailed design
[detailed-design]: #detailed-design

[Bitswap](https://docs.ipfs.io/concepts/bitswap/) is a module provided by [libp2p](https://libp2p.io/) that enables distributed data synchronization over a p2p network, somewhat comparable to how [BitTorrent](https://en.wikipedia.org/wiki/BitTorrent) works. It works by splitting up data into chunks called blocks (we will explicitly refer to these as "Bitswap blocks" to disambiguate them from "blockchain blocks"), which are structured into a DAG with a single root. When a node on the network wants to download to some data, it asks it's peers to see which (if any) have the root Bitswap block corresponding to that data. If none of the peers have the data, it falls back to querying the gossip network's [DHT](https://docs.ipfs.io/concepts/dht/#kademlia) to find a suitable node that can serve the data.

In this design, we will lay out an architecture to support Bitswap in our Mina implementation, along with a strategy for migrating Mina blocks into Bitswap to reduce current gossip pub/sub pressure. We limit the scope of migrating Mina data to Bitswap only to blocks for the context of this RFC, but in the future, we will also investigate moving snark work, transactions, and ledger data into Bitswap. Snark work and transactions will likely be modeled similarly to Mina blocks with respect to Bitswap, but ledger data will require some special thought since it's Bitswap block representation will have overlapping Bitswap blocks across different ledgers.

## Bitswap Block Format

Bitswap blocks are chunks of arbitrary binary data which are content addressed by [IPFS CIDs](https://docs.ipfs.io/concepts/content-addressing/#cid-conversion). There is no pre-defined maximum size of each Bitswap block, but IPFS uses 256kb, and the maximum recommended size of a Bitswap block is 1mb. Realistically, we want Bitswap blocks to be as small as possible, so we should start at 256kb for our maximum size, but keep the size of Bitswap blocks as a parameter we can tune so that we can optimize for block size vs block count.

While the Bitswap specification does not care about what data is stored in each block, we do require each block have a commonly-defined format:

 1. `[2 bytes]` count of links n
 2. `[n * 32 bytes]` links (each link is a 256-bit hash)
 3. `[up to (maxBlockSize - 2 - 32 * n) bytes]` data

Hence, data blob is converted to a tree of blocks. We advertise the "root" block of the tree as the initial block to download for each resource we store in Bitswap, and the libp2p helper process will automatically explore all the child blocks referenced throughout the tree. To construct the full binary blob out of this tree, breadth-first search (BFS) algorithm should be utilized to traverse the tree. BFS is a more favourable approach to DFS (another traversal order) as it allows to lazily load the blob by each time following nodes links to which we already have from the root block (counter to the order induced by DFS where one has to go to the deepest level before emitting a chunk of data).

For links a 256-bit version of Blake2b hash is to be used. Packing algorithm can be implemented in the way that no padding is used in blocks and there are maximum `n = (blobSize - 32) / (maxBlockSize - 34)` blocks generated with `n - 1` blocks of exactly `maxBlockSize` bytes.

## Bitswap Block Database

There exist some key constraints in choosing a good solution for the Bitswap block db. Importantly, the block database needs to support a concurrent readers and a writer at the same time. Additionally, the database should be optimized for existence checks and reads, as these are the operations we will perform the most frequently against it. Some consistency guarantees (ability to rely on happens-before relation between write and read events) are also required. The database would ideally be persisted, so that we can quickly reload the data in the event of node crash (we want to avoid increasing bootstrap time for a node, as that keeps stake offline after crashes).

Given these constraints, [LMDB](http://www.lmdb.tech/doc/) is a good choice for the Bitswap block storage. It meets all of the above criteria, including persistence. As a bonus, it's light on extra RAM usage.

### Database Schema

| Key                  | Value                | Key bytes                   |
|----------------------|----------------------|-----------------------------|
| `status/<root_cid>`  | integer: 0..2        | `<1><32-byte blake2b digest>` |
| `block/<cid>`        | bitswap block bytes  | `<0><32-byte blake2b digest>` |

Status is an integer taking one of the values:

  * `0` (not all descendant blocks present)
  * `1` (all descendant blocks present)
  * `2` (delete in process)

### Additional data to store in the Daemon db

In addition to data already stored in the DB controlled by the Daemon, we would need to store:

* `headerHashToRootCid`: relation between header and associated root cid (if known)
* `rootCidsToDelete`: list of root cids marked for deletion (i.e. root cids related to blocks which were completely removed from frontier)
* `recentlyCreatedBlocks`: list of recently created blocks for which we didn't receive confirming upcall

### Invariants

The following invariants are maintained for the block storage:

* For each `status/{rcid}` in DB, there is an entry for `{rcid}` in the `headerHashToRootCid`
* For each cid for which `block/{cid}` exists in DB, either holds:
  * There exists `status/{cid}`
  * There exists `cid'` such that `cid` is in the link list of bitswap block at `block/{cid'}`
* `status/{rc}` can progress strictly in the order: `null -> 0 -> 1 -> 2 -> null`

### Initialization

Daemon initialization:

1. Remove keys `k` from `rootCidsToDelete` for which `status/{k}` is absent
2. Remove blocks `b` from `recentlyCreatedBlocks` for which `status/{b.root_cid}` is present and is not equal to `0`
3. Start Helper
4. Send bulk delete request to Helper for keys from `rootCidsToDelete`
5. Send bulk download request to Helper for blocks that are known to frontier but which do not have `status/{b.root_cid} == 1`
6. Send add resource request for each block in `recentlyCreatedBlocks`

Helper has no initialization at all.

### Helper to Daemon interface

Helper receives requests of kind:

* Delete resources with root cid in list `[cid1, cid2, ...]`
  * Sends a single upcall upon deletion of all of these resources
* Download resources with root cid in list `[cid1, cid2, ...]`
  * Sends an upcall upon full retrieval of each resource (one per resource)
* Add resource with root cid `{root_cid}` and bitswap blocks `[block1, ..., blockN]` (no checks for hashes are made)
  * Sends an upcall confirming the resource was successfully added

### Synchronization

Block creation:

1. Block is added to `recentlyCreatedBlocks`
2. Add resource request is sent to Helper
3. Upon add resource confirmation upcall, block is removed from `recentlyCreatedBlocks`

Frontier is moved forward and some old blocks get removed:

1. Remove record for block from `headerHashToRootCid`
2. Add block to `rootCidsToDelete`
3. Delete resource request is sent to Helper
4. Upon delete resource confirmation upcall, block is removed from `rootCidsToDelete`

A gossip for the new header is received and Daemon decides that the block body corresponding to the header has to be fetched:

1. Store record in `headerHashToRootCid` for the header
2. Send download request to Helper
3. Upon download upcall is received, block and header are added to frontier
  a. In case downloaded block came late and the block is not more of an interest, launch the deletion flow as described above

(We assume root cid is received along with the header in the gossip)

## Migrating Mina Blocks to Bitswap

To migrate Mina block propagation to Bitswap, we will separate a Mina block into 2 portions: a block header, and a block body. Most of the data in a Mina block is stored inside of the `staged_ledger_diff`. The common data in every Mina block is ~8.06kb (including the `protocol_state_proof`), so using everything __except__ for the `staged_ledger_diff` as the block header seems natural. The `staged_ledger_diff` would then act as the block body for Mina blocks, and would be downloaded/made available via Bitswap rather than broadcast over pub/sub.

When blocks are broadcast through the network now, only the block header and a root CID for the `staged_ledger_diff` are in the message. When a node receives a new block header, the node will first verify the `protocol_state_proof` (all public information that needs to be fed in for proof verification will be available in the block header). Once the proof is checked, a node would then download the `staged_ledger_diff` via Bitswap. Once that is downloaded, the node would follow the same pattern right now for generating a breadcrumb by expanding the `staged_ledger` from the parent breadcrumb and the new `staged_ledger_diff`, after which the Mina block will be fully validated. At this point, the breadcrumb is added to the frontier.

In summation, the proposed changes in order to move Mina blocks into Bitswap are:

1. Define separate block header (block w/o `staged_ledger_diff` with new field `staged_ledger_diff_root_cid`).
2. Verify `staged_ledger_diff_root_cid` relation to the header.
3. Rebroadcast block headers after proofs are checked, but before `staged_ledger_diff`s are verified and the breadcrumb is added to the frontier.
4. Punish block producer public keys if they submit an invalid `staged_ledger_diff` by ignoring all future block headers from that producer within the epoch (do not punish senders, as they may not have banned or checked the `staged_ledger_diff` yet).

Punishing is done only within the epoch as otherwise punish lists would be accumulating without boundary and real adversaries will nevertheless find the way around by mnoving stake for to other address for the next epoch.

## Verifying relation between root CID and header

One large difference from before is that nodes will rebroadcast the block header to other nodes on the network before the `staged_ledger_diff` is downloaded and verified, in order to avoid increasing block propagation time on the network with the new addition of Bitswap. This change brings some unique problems that we need to solve now, as previously, we wouldn't forward Mina blocks to other nodes until we knew the block was fully valid.

In the new world, an adversary could broadcast around the same block header and proof, but swap out the `staged_ledger_diff` root Bitswap block CID with different values to attack the network. An adversary can do that both being a block producer and as a man-in-the-middle (MITM).

To rule out the MITM attack vector, a signature is to be carried along with the header. The signature is made of a pair of root CID and header hash with block producer's public key. No MITM actor can forge the signature, hence the attack becomes infeasible.

To mitigate adversary the block producer attack case, the following tactic is employed: if a node ever downloads a `staged_ledger_diff` which does not achieve the target staged ledger hash after application to the parent staged ledger, that node will ban the block producer public key associated with the block. This significantly raises the cost of attack and makes it in effect pointless.

# Shipping plan
[shipping]: #shipping

Shipping of the feature is two-staged with first stage being shipped as a soft-fork release and the second stage being shipped as part of a hard-fork.

## Soft-fork

For soft-fork stage, here is the anticipated changeset:

1. Support for sharing blocks via Bitswap
2. New pub/sub topics:
    * `mina/block-body/1.0.0`
    * `mina/tx/1.0.0`
    * `mina/snark-work/1.0.0`
3. Engine to rebroadcast blocks from the new topics to old `coda/consensus-messages/0.0.1` and vice versa

### Legacy topic management

Most new nodes will support both old and new topics for broadcast. Nodes are able to filter subscriptions from other nodes based on what they subscribe to, configured using the [`WithSubscriptionFilter` option](https://github.com/libp2p/go-libp2p-pubsub/blob/55d412efa7f5a734d2f926e0c7c948f0ab4def21/subscription_filter.go#L36). Utilizing this, nodes that support the new topics can filter out the old topic from nodes that support both topics. By filtering the topics like this, nodes running the new version can broadcast new blocks over both topics while avoiding sending the old message format to other nodes which support the new topic.

In particular, following method of the filter is to be implemented:

```
type SubscriptionFilter interface {
  ...
  FilterIncomingSubscriptions(peer.ID, []*pb.RPC_SubOpts) ([]*pb.RPC_SubOpts, error)
}
```
On receiving of these incoming subscription for the old topic, we check whether the same peer is already subscribed to all three new topics and if so, subscriptions is filtered out. Node configuration code shall be implemented accordingly, subscribing to the new topics first.

Over time, when most of the network participants adopt the newer version, only a few specifically configured nodes (including some seeds) will continue servicing the old topic, while most of the network will live entirely on the new topic.

Mina node will take two additional arguments:

* `--pubsub-v1`: `rw`, `ro` or default `none`
* `--pubsub-v2`: default `rw`, `ro` or `none`

Daemon runs message propagation for legacy topic as follows:

1. If `--pubsub-v2=rw` or `--pubsub-v2=ro`, listen to `mina/tx/1.0.0` and `mina/snark-work/1.0.0`
   1. For each valid message if `--pubsub-v1=rw` resend it to `coda/consensus-messages/0.0.1`
2. If `--pubsub-v2=rw` or `--pubsub-v2=ro`, listen to `mina/block/1.0.0` and add headers to frontier
3. For each new block in frontier, publish it to `coda/consensus-messages/0.0.1` if `--pubsub-v1=rw`
4. If `--pubsub-v1=rw` or `--pubsub-v1=ro`, listen to `coda/consensus-messages/0.0.1`
   1. For each valid block message if `--pubsub-v2=rw` resend corresponding header to `mina/block/1.0.0`
   2. For each valid transaction message if `--pubsub-v2=rw` resend it to `mina/tx/1.0.0`
   3. For each valid snark work message if `--pubsub-v2=rw` resend it to `mina/snark-work/1.0.0`
 
Releasing of Bitswap will happen in two stages:

1. Release with default parameters `--pubsub-v1=rw` and `--pubsub-v2=rw`
2. After most block producers adopt new version, change to default `--pubsub-v1=none`
3. Launch a network of "pubsub relays" which will service both `--pubsub-v1=rw` and `--pubsub-v2=rw` until the next hardfork

### New block topic

New block topic presents a new message type comprising:

1. Block header (as defined above)
2. Block body certificate

Block body certificate in turn is the data structure with the following fields:

1. 32-byte block body root
2. Signature

Block body root is a hash of a root bitswap block containing bytes of block body.

Signature is a digital signature of pair `(block body root hash, block header hash)` made with secret key corresponding to block producer's key specified in the block's header.

Frontier absorbs block headers along with the corresponding block body roots and keeps them as 1:1 relation. Whenever the same block header is received with a different block body root (and a valid block producer signature), block producer is banned from producing a block for the given slot.

Additionally, if bitswap block referenced by block body root is broken, block producer is banned from producing a block for the given slot.

In case of ban for a slot, all of the corresponding data is cleaned out, ban is local.

## Hard-fork

In the next hardfork old topic becomes entirely abandoned.

Also, consider migrating to hash-based message ids as described in [issue #9876](https://github.com/MinaProtocol/mina/issues/9876).

# Drawbacks
[drawbacks]: #drawbacks

This adds significant complexity to how the protocol gossips around information. The control flow for validating blocks is more complex than before, and there is new state to synchronize between the processes in the architecture. It also adds new delays to when the full block data will be available to each node (but the tradeoff here is that we are able to more consistently gossip block 
s around the network within the same slot those blocks are produced).

# Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

- it would be possible to download larger data from peers via RPC and still reduce the pub/sub message size, though there are some issues with this approach
  - it is not guaranteed that any of your peers will have the data you need, in which case you need some alternative mechanism to discover who does have it
  - puts a lot of bandwidth pressure on individual peers rather than spreading the load between multiple peers (which helps with both bandwidth pressure and data redundancy for increase availability)
- alternatives to using LMDB as the Bitswap cache
  - use [SQLite](https://www.sqlite.org/index.html)
    - even though all we need is a key/value db, not a relational db, SQLite is portable and performant
    - would require us to enable both the [write-ahead logging](https://sqlite.org/wal.html) and use [memory-mapped I/O](https://www.sqlite.org/mmap.html) features in order to use it the way we would like to
  - use raw Linux filesystem (from @georgeee)
    - would use a lot of inodes and file descriptors if we do not build a mechanism that stores multiple key-value pairs in shared files, which could prove tricky to implement
    - would need to solve concurrency problems related to concurrent readers/writers, which could be tricky to get correct and have confidence in


## Verifying root CID to header relation

There is another option to verify the relation: include a commitment in the snark not only to the target staged ledger hash, but also the root Bitswap block CID of the `staged_ledger_diff` that brings us to that state.

Two options compare with one other in the following way:

|                          |Snark commitment|Signature |
|--------------------------|----------------|----------|
|_Snark proving time_      |Increased       |Unchanged |
|_Computational complexity_|High            |Low       |
|_Soft-fork_               |Incompatible    |Compatible|

For the _Snark commitment_ option, adversary needs to generate a snark proof for each `staged_ledger_diff` they want to broadcast to the network, hence the high computational complexity of an attack, which is a desirable property. However, _Signature_ option is preferred due to the fact that it's softfork-compatible and doesn't increase the complexity of circuit.

# Appendix

_For reference on the above computation of ~8.06kb for a block without a staged ledger diff, here is a snippet of OCaml code that can be run in `dune utop src/lib/mina_transition`_

```ocaml
let open Core in
let open Mina_transition in
let precomputed_block = External_transition.Precomputed_block.t_of_sexp @@ Sexp.of_string External_transition_sample_precomputed_block.sample_block_sexp in
let small_precomputed_block = {precomputed_block with staged_ledger_diff = Staged_ledger_diff.empty_diff} in
let conv (t : External_transition.Precomputed_block.t) =
  External_transition.create
    ~protocol_state:t.protocol_state
    ~protocol_state_proof:t.protocol_state_proof
    ~staged_ledger_diff:t.staged_ledger_diff
    ~delta_transition_chain_proof:t.delta_transition_chain_proof
    ~validation_callback:(Mina_net2.Validation_callback.create_without_expiration ())
    ()
in
Protocol_version.set_current (Protocol_version.create_exn ~major:0 ~minor:0 ~patch:0) ;
External_transition.Stable.Latest.bin_size_t (conv small_precomputed_block) ;;
```
