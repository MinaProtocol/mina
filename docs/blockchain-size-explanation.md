# 22kB sized blockchain!

"The entire Mina blockchain is and will always be about 22kb - the size of a couple of tweets."

To analyze the above statement, first, let us clarify what we mean by "blockchain" here.
The data that a node needs in order to verify a specific state of the blockchain and the state itself in a trustless manner is what we are mainly referring to as blockchain. In the UTXO model this would be transactions in each block which are processed to verify the resulting UTXOs in the latest block. In an account based model, this would again be transactions in each block which are applied to the accounts in a previous state to verify the accounts in the new state.

Miners/block producers or full nodes perform this verification to sync to the network without having to trust another node and therefore are able to verify the correctness of the state (account balances or resulting UTXOs). Any new node (or a node that was offline for a long period) will have to perform this verification by dowloading the required blocks to sync to the network.

Light clients which are intended for low-capacity environments help users to verify/access information relevant to them from the latest state of the blockchain without having to sync. They do so by reading the header from a block and verifying that the balance is correct w.r.t to the block they recieved, thereby trusting that the full node that sends them the data. The data light nodes need is therefore minimal and any new light node can sync to the network pretty quickly as a result of delegating trust.

Mina replaces the entire blockchain, starting from genesis to any block, with an easily verifiable constant-sized cryptographic proof. Verifying this proof corresponding to a block amounts to verifying [all the transactions up until a few blocks behind the current block](#snarked-ledger). The proof and inputs to the verification function are all in the block that gets gossiped.
This process of verification applies to all the nodes in Mina network. Let's dig a bit deeper to see how much state is required for different type of nodes in Mina network.

## Light clients

The main functionalities of a light client are 1) to be able to check balances of specific accounts 2) to be able to submit transactions to the network. For this, they need the following information.

#### Block

A block in mina respresents the state of the blockchain at a given height. It mainly consists of a blockchain proof, state represented using hashes of various datastructures including the ledger (we call this a protocol state), new transactions, SNARKs for the transactions included in the previous blocks. To verify the current block and all the previous blocks in the chain starting from genesis, one just needs the proof and the protocol state included in the current block (all hail recursive zk-SNARKS!). Then using the verifier function and verification keys, a node can determine whether this state is valid or not.

On receiving a new block, the node can also independently check if the new block is better than the existing one without having to trust the source. The protocol state basically has all the information to perform this check.

#### Merkle path to an account

Mina uses an account-based model (similar to Ethereum); balance corresponding to a public key is stored in an account record. A node that does not store the entire account-based ledger, can request a particular account record from a node that stores it (For example, block producing nodes). Additionally, the node will also request the merkle path to the account to verify the account record. The resulting merkle root should match the ledger state that was verified by the blockchain snark.

#### Size

A light client in Mina is therefore able to verify the entire blockchain and accounts from the ledger certified by the blockchain SNARK in a trustless manner like any other full node. Let's look at how big this data is.

The size of each of these pieces of data can be measured empirically — we determined them (the actual binary data that gets stored) using this code [https://github.com/MinaProtocol/mina/commit/8b77e0f25424a364eb8fad10e9fae9dd6d6a9126#diff-ff77f063832ae5235355bf7790b3b00910e57caec5940203628766a5888272e9R638](https://github.com/MinaProtocol/mina/commit/8b77e0f25424a364eb8fad10e9fae9dd6d6a9126#diff-ff77f063832ae5235355bf7790b3b00910e57caec5940203628766a5888272e9R638).
When executed we get the following information (in bytes):

```

Proof size: 7063 
Protocol State size: 822
Account size: 181
Path size: 741
Total size (combined): 8807

```

A node also requires a key to verify blockchain SNARKS and its size on disk is 2039 bytes  

The result is approximately 11kB! Mina's cryptography has evolved, and the protocol has gotten a bit more efficient so we're actually significantly below 22kB now.

#### Snarked-ledger
Note that the ledger proven by the blockchain snark is a few blocks behind the latest ledger because of the way transaction SNARKS are processed (explained in detail [here](https://minaprotocol.com/blog/scanning-for-scans)). We call this the snarked ledger and is proven by transaction SNARKS produced by snark worker nodes. The latest ledger corresponding to a block (staged-ledger) is verified explicitly by block producerss by applying the transactions to the ledger and are not guranteed by the blockchain proof.

## Block-producing nodes

Block-producing nodes perform more tasks than just verifying the state. In addition to producing blocks and generating blockchain SNARKs, block producers maintain a chain of last `k` blocks (where `k` is a constant from our consensus algorithm - ouroboros samasika, and currently is set to 290). `k` signifies the finality aspect of a block; a block that has `k` blocks on top of it has a negligible probability to be reversed and therefore all the transactions in it can be confirmed. A block producer maintains any forks that occur within the last `k` blocks so as to determine the best chain and produce blocks off of it. A block producer also maintains all the data structures including the full ledger to be able to generate the protocol state that other nodes can then verify. Albiet needing a bigger state, for a new block-producing node, syncing to the latest state amounts to verifying `k` blockchain SNARKs and applying the transactions in those `k` blocks. The batch-verification functionality has made this process much faster!
