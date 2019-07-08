# Become a Node Operator

Now that we've run through the basic steps to set up our Coda node and sent our first transaction, let's turn our attention to the other ways we can interact with the Coda network - participating in consensus, and helping compress data by generating zk-SNARKs. By operating a node that helps secure the network, you can receive coda for your efforts.

## Participating in Consensus

The Coda network is secured by [Proof-of-Stake consensus](/glossary/#proof-of-stake). With this model of consensus, you don't need to have complex equipment like in Bitcoin mining. By simply having coda in our wallet, we can choose to either stake it ourselves, or delegate it to another node to have a voice in the network. Let's first see how to stake coda ourselves:

### Staking coda

Since we have some funds in our wallet from [the previous step](https://www.notion.so/codaprotocol/My-First-Transaction-0304f6d71707419fadf9678318c6107b), we can configure that wallet to stake its coda by issuing the following command, passing in the file path for the associated private key:

    $ coda.exe client set-staking -- <private-key-file>

!!! note
    You can provide a list of key files to turn on staking for multiple wallets at the same time

You can check which keys you're currently staking for using the `coda.exe client status` command, checking the `Proposers Running` field:

    $ coda.exe client status
    
    Coda Daemon Status 
    -----------------------------------
    
    Global Number of Accounts:                     18
    The Total Number of Blocks in the Blockchain:  1
    Local Uptime:                                  36s
    Ledger Merkle Root:                            ...
    Staged-ledger Hash:                            ...
    Staged Hash:                                   ...
    GIT SHA1:                                      ...
    Configuration Directory:                       ...
    Peers:                                         ...
    User_commands Sent:                            0
    Snark Worker Running:                          false
    Sync Status:                                   Offline
    Proposers Running:                             Total: 1 (8QnLUNW7sUxnApau4SLShwr25koiSKrECxtveu89PPmQW5pEyy3xK8YgRpZQkZEanc)
    Best Tip Consensus Time:                       0:0
    Consensus Time Now:                            11542:461
    Consensus Mechanism:                           proof_of_stake
    ...

### Delegating coda

To delegate your stake, instead of running your own staking node, you can send a transaction that will delegate your stake to another node:

    $ coda.exe client delegate-stake \
        -delegate <public-key> \
        -privkey-path <file> \
        -fee <fee>

Uses for this:

- Running your own staking node that uses funds from a "cold wallet"
- Delegating to a "staking pool" which will provide token payouts periodically

!!! note
    There is a waiting period of a day before this change will come into effect to prevent abuse of the network

## Compressing data in the Coda network

In addition to participating in consensus, Coda nodes can also help compress data in the network by generating cryptographic proofs (zk-SNARKs).

Run the following command to set your node as a "snark worker":

    $ coda.exe client set-snark-worker -pubkey <public-key> -snark-worker-fee <fee>