# 22kB sized blockchain -- A technical refernce

"The entire Mina blockchain is and will always be about 22kb - the size of a couple of tweets."

To analyze the above statement, first, let us clarify what we mean by "blockchain" here: A term that captures two groups of information. (1) An unambiguous usable representation (ie. not merely hashes) of the parts of the state a typical user would care about -- namely the current balance of their account. (2) The data that a node needs in order to verify that this state is real in a trustless manner. (3) The ability to broadcast transactions on the network to make a transfer. "Blockchain" captures (1), (2), and (3) here.

In other networks, like Bitcoin or Ethereum, miners require the entire history of the transactions in the network (organized via the chain of blocks) to fully validate any portion of the current state of those networks. This is true for both account or UTXO-based networks. Any new node (or a node that was offline for a long period) will have to sync to the network trustlessly by downloading all the blocks they missed.

In other networks, like Bitcoin or Ethereum, there is a notion of a "light client". These light clients are intended for low-capacity environments help users to verify/access information relevant to them from the latest state of the blockchain without having to do an expensive (both in time and space) syncing operation. They do so by reading the header from a block and verifying that the balance is correct w.r.t to the block they recieved, thereby _trusting_ that the full node that sends them the data. These light nodes are not capable of representing "the blockhain" as we've defined it above.

Mina replaces the entire blockchain, starting from genesis to any block, with an easily verifiable constant-sized cryptographic proof. Verifying this proof corresponding to a block amounts to verifying [all the transactions up until a few blocks behind the current block](#snarked-ledger). The proof and inputs to the verification function are all in the latest block that gets gossiped. Note that due to the definition of "blockchain" above including the term "usable" This definition means in succinct protocol like Mina, we need more than just a proof object coupled with a state full of opaque hashes.

This process of verification applies to all the nodes in Mina network. Some roles in the network do need extra information to perform their duties, but this is beyond the definition we gave above. Read more about a "Block producer" node in the appendix.

## Data needed for a usable represntation of the blockchain

We wish (1) to be able to check balances of a specific account (2) to be able to submit transactions to the network. For this, a node, we call it a "non-consensus node" needs stored on in memory merely: a protocol state, the account, a merkle path to this account, and a verification key. Importantly, these powerful nodes are not light clients. They have equivalent security to full nodes.

This node role is not yet implemented. The protocol will support it, we just need to prioritize the engineering work.

### Protocol State

The protocol state is an unambiguous representation of the current state of network. It includes hashes of various datastructures including the ledger. Block producing nodes gossip around blocks that contain the protocol state inside.

A block in mina contains other information as well; a proof including new transactions and SNARKs for the transactions included in the previous blocks. Recursive zk-SNARKs, a verification function, and a verification key enable us to verify the entire sequence of blocks just via the proof and the protocol state from one single new block.

After verifying the new state is valid, the node can also independently check if the new block is better than the existing one without having to trust the source by comparing it to the last known best protocol state -- then we can choose to forget this information if it's not better than the existing one or replace the one we stored. In other words, we only need to hold on to _one_ protocol state as we're listening for newer states.

### Account

Mina uses an account-based model (similar to Ethereum); balance corresponding to a public key is stored in an account record. A node that does not store the entire account-based ledger, can request a particular account record from a node that stores it (for example, block producing nodes -- see the appendix).

### Merkle path to an account

Additionally, the node will also request the merkle path to the account to verify the account record is valid without needing to trust any node. The resulting merkle root should match the ledger state that was verified by the blockchain snark.

## Measurement of Size

A non-consensus node in Mina is therefore able to verify the entire blockchain and accounts from the ledger certified by the blockchain SNARK in a trustless manner like any other larger, more expensive (in syncing time, and space) full node would on other networks (like Bitcoin or Ethereum). Let's look at how big this data is:

The size of each of these pieces of data can be measured empirically — we determined them (the actual binary data that gets stored) using this code [https://github.com/MinaProtocol/mina/commit/8b77e0f25424a364eb8fad10e9fae9dd6d6a9126#diff-ff77f063832ae5235355bf7790b3b00910e57caec5940203628766a5888272e9R638](https://github.com/MinaProtocol/mina/commit/8b77e0f25424a364eb8fad10e9fae9dd6d6a9126#diff-ff77f063832ae5235355bf7790b3b00910e57caec5940203628766a5888272e9R638).
When executed, we get the following information (in bytes):

```

Proof size: 7063
Protocol State size: 822
Account size: 181
Path size: 741
Total size (combined): 8807

```

A node also requires a key to verify blockchain SNARKS and its size on disk is 2039 bytes

The result is approximately 11kB. Mina's cryptography has evolved since we initially crunched the numbers on the 22kB -- the protocol has gotten a bit more efficient.

#### Snarked-ledger

Note that the ledger proven by the blockchain snark is a few blocks behind the latest ledger because of the way transaction SNARKS are processed (explained in detail [here](https://minaprotocol.com/blog/scanning-for-scans)). We call this the snarked ledger and is proven by transaction SNARKS produced by snark worker nodes. The latest ledger corresponding to a block (staged-ledger) is verified explicitly by block producerss by applying the transactions to the ledger and are not guranteed by the blockchain proof.

## Conclusion

Our aim was to show that an entire blockchain can be represented and verified using data that is just 11kB. We claim `The entire Mina blockchain is and will always be about 22kb` -- in reality, it is even smaller.

## Appendix: Block-producing nodes

Block-producing nodes perform more tasks than just verifying the state. In order to effectively produce blocks, block producers maintain a chain of last `k` blocks (where `k` is a constant from our consensus algorithm - ouroboros samasika, and currently is set to 290). `k` signifies the finality aspect of a block; a block that has `k` blocks on top of it has a negligible probability to be reversed and therefore all the transactions in it will always be confirmed for all eternity (TODO: Vanishree to clarify). A block producer maintains any forks that occur within the last `k` blocks so as to determine the best chain and produce blocks off of it. A block producer also maintains all the data structures including the full ledger to be able to generate the protocol state that other nodes can then verify. Albeit needing a bigger state, for a new block-producing node, syncing to the latest state amounts to verifying `k` blockchain SNARKs and applying the transactions in those `k` blocks.
