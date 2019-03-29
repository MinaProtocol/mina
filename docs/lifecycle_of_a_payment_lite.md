# The Lifecycle of a Payment (overview)

In Coda, payments pass through several steps before they are considered verified and complete. This document is meant to walk through what happens to a single payment in a simplified overview to help users understand a little about how Coda payments work. It it not a comprehensive technical overview, but instead a simplified walkthrough for users. For a more detailed technical overview aimed at developers wishing to understand the codebase check out the [technical lifecycle of a payment](lifecycle_of_a_payment_technical.md).

### Assumption About Communications
Coda uses a Gossip protocol to ensure that messages can be reliably transmitted to all other members of the network in a timely manner.

## Payments:
What is a Payment? - Bob wants to send Alice some currency.
A payment is a request to transfer value from one account, to another account and the associated fee the sender is willing to pay for the payment to go through.

## Stage 1 - Payment Creation - Bob clicks ‘send’.
Any member of the network can create and transmit a payment. The payment is
cryptographically signed with a private key so that the sender’s account can be verified. It is then sent out on the network to be processed.

## Stage 2 - Proposing a Transition - Bob’s payment gets put in a todo list
A proposer node is chosen on the network for a given time slot. The currently active proposer choses in-flight payments based on payment fees and places them in a list to be processed called a transition block. Proposers earn currency for building these blocks. The proposer generates a snark defining the structure of the transition block as compared to the previous block (but not yet verifying these new payments). The proposer transmits this new information for snark workers to process.

## Step 3 - Transaction Snark Proving - Bob’s payment gets snark-signed
Snark worker nodes on the network begin performing snark calculations on each step of the new transition block. These are individual proofs of each payment and then merge proofs of neighboring payments. Eventually all the payments are verified. Snark workers can earn currency by generating these proofs, paid for by proposers. These proofs are transmitted out over the network.

## Step 4 - Payment Verification - Alice and Bob’s accounts show the result of the transfer
Once the whole block has been proven, the proposer will send out a confirmation of the transition block. Then member nodes on the network apply the changes to their local account balances to reflect these changes.

## Step 5 - Payment Confidence Level - Alice is confident the transfer is complete
With each subsequent block, a recipient has a higher degree of confidence that the payment is actually complete and that the network has consensus about that block.

