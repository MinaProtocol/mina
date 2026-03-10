## Summary
[summary]: #summary

This RFC proposes standardized glossary terms for various concepts in the Coda Protocol and how they are communicated to the external world in documentation, logging, user interfaces, and public communications. This is not intended to cover the existing codebase in scope, as it may be too cumbersome at this point to rename everything to fit these proposed conventions. 

However, it is advisable that over time the codebase also migrates to this shared terminology so that future community members can on-board seamlessly from high level documentation to contributing code.

## Motivation

[motivation]: #motivation

Currently, multiple terms exist for several concepts in the Coda protocol, and they are used interchangeably when communicating to the world. This has some downsides as there is a lack of clarity on which terms to use, and could potentially cause confusion for people unfamiliar with the protocol. 

As such, the motivation of this RFC is to standardize the naming convention for various concepts into a unified glossary that can be used in documentation, user-facing copy, and marketing channels. The expected outcome is unified language when communicating to the public and in developing Coda related products. This can then lead to more clarity and easier onboarding.

## Detailed design

[detailed-design]: #detailed-design

The proposal contains the suggested term with it's associated concept it encapsulates, as well as alternative terms and the rationale for  the suggestion.

The terms proposed are below:

### Coda vs coda
**Concept:** "Coda" is the network / protocol. "coda" is the token.

**Rationale:** Aligns with other networks, and makes it easy to differentiate context based on casing.

**Downsides:** More things to remember.

**Usage:** The native token of the Coda network is coda.

**Alternatives:**
- Use "Coda" everywhere.

### Block Producer
**Concept:** A node that participates in a process to determine what blocks it is allowed to produce, and then produces blocks that can be broadcast to the network. 

**Rationale:** This term is used by other protocols, clearly describes the role duties, and is unambiguous.

**Downsides:** EOS is the most popular chain that uses "block producers" and there is a chance of confusion if people think Coda also has only 21 block producers - but this is a tail risk.

**Usage:** A block producer or block producing node stakes its coda and coda delegated to it in order to participate in consensus.

**Alternatives:**
- Validator - used by most other protocols, but not suitable for Coda, as every node can be a "verifier" or "validator" of SNARKs.
- Staker - tied to a specific consensus model, and doesn't explain what the node does for the network. It also has an edit distance of 2 from snarker, which can cause some confusion.
- Proposer - currently used in codebase, but unused by other protocols, and also sounds less firm / tied to generating blocks (relative to producer).
- Prover - currently used to describe the action of generating the block SNARK, but if this that job moves to snark workers, then this term is irrelevant.
- Miner, Baker, etc - not relevant to Coda's consensus mechanism.

### Block
**Concept:** A set of transactions and consensus information that extend the state of the network. Includes a proof that the current state of the network is fully valid.

**Rationale:** This term aligns with the rest of the industry, and it makes it easier to onboard other blockchain users.

**Downsides:** Perhaps it is not as technically accurate as a transition.

**Usage:** Blocks enable the Coda network's state to be updated. Blocks include transactions to be applied to the ledger as well as various pieces of consensus information that allow the network to eventually agree on what blocks will stay in the blockchain.

**Alternatives:**
- External transition - maybe this is more precise, but has the heavy lifting of having to explain a new term for a mostly similar concept. Additionally, the word transition is very similar to transaction, causing confusion at times.

### Snark worker
**Concept:** A Coda node that produces SNARKs to compress data in the network.

**Rationale:** The community likes SNARKs and it is a point of differentiation for Coda, so Snark worker is an engaging term.

**Downsides:** Gets invalidated if Coda switches to another type of zero-knowledge proof. NOTE - There is some concern about using the progressive tense of "snark" as a verb, eg. "snarking" - as this can be confused with staking. However, if the community enjoys "snarking", it  would make sense to  continue using it as a verb.

Additionally, the usage of "work" in snark worker can be misconstrued as a connection to Proof-of-Work, but this will addressed in documentation under the FAQ section.

**Usage:** 
- Anyone can join the coda network and become a snark worker.
- Snark workers help compress the blockchain by generating SNARKs.

**Alternatives:**
- Compressor - this term was considered initially, but given the community excitement about SNARKs, it makes sense to include the more specific term in the lexicon.
- Snarker - this term is used interchangeably with "snark worker", but it is suggested to converge on snark worker.

### Full node
**Concept:** A Coda node that is able to verify the state of the network - however it may need to request paths for its accounts from other nodes that have all the accounts state.

**Rationale:** By calling this type of node a full node, Coda distinguishes itself from other networks, as all nodes are technically full nodes if they can verify SNARKs - these nodes are not required to trust other nodes.

**Downsides:** Because these nodes still need to request state from other nodes, there is an argument to be made that they are not full nodes. Furthermore, Bitcoin classifies full nodes as nodes that "download every block and transaction and check them against Bitcoin's consensus rules." Therefore, there may be some community pushback against calling these nodes full nodes, even though they are trustless.

**Usage:** On the Coda network, even phones can run full nodes!

**Alternatives:**
- Fully verifying nodes - more accurate, but a mouthful, and have to create a new term.
- Trustless nodes - again, some lifting required.
- Light node / light client - has a negative connotation of not being able to validate chain state.

### User Transaction
**Concept:** A transaction issued by a user - currently a payment or a delegation change.

**Rationale:** This term clearly describes the concept, and leaves room for further types of user issued transactions.

**Downsides:** This is a subset of "Transactions", so it is a bit redundant.

**Usage:** There are three types of transactions in the Coda network currently - user transactions, fee transfers, and coinbases. User transactions allow users to manage accounts and send money.

**Alternatives:**
- User command - this term is confusing, especially in  docs, as it can be conflated with a CLI command that a user issues.

### Protocol Transaction
**Concept:** A transaction issued by the protocol - currently a fee transfer or coinbase (both are structurally identical).

**Rationale:** In discussions with parties that were not familiar with the protocol, fee transfers were misunderstood as representations of fees associated with a user transaction. As soon as it was explained that these were transactions programmatically issued by the protocol rather than a user, it became clear. As such, it is recommend to partition transactions into *user transactions* and *protocol transactions*.

**Downsides:** If there will ever be fee transfers issued by users, this will break the proposed structure. However, there currently doesn't seem to be any plans currently to do that.

**Usage:** Snark workers are compensated for their snark work by protocol transactions.

**Alternatives:**
- Fee transfers - current usage, confusing to unfamiliar users.

### Block Hash
**Concept:** A hash that serves as an identifier for a specific block in the blockchain.

**Rationale:** Most major cryptocurrency protocols use the term block hash, and it is helpful to align with existing terms when possible.

**Downsides:** This didn't make sense when blocks were referred to as external transitions. Now that blocks is the accepted terminology, it should follow that the updated name for the reference is block hash.

**Usage:** Each block contains a unique block hash that is used as an indentifier.

**Alternatives:**
- State hash - the previous term -- perhaps more accurate, but doesn't conform to broader industry terms.

## Drawbacks
[drawbacks]: #drawbacks

The drawback to aligning on language is that we lose some specificity that comes with each specific term, relative to the others. However, this concern is minor, and is superceded by the need for consistent language.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

See [design section](#detailed-design) for rationale and alternatives.

## Prior art
[prior-art]: #prior-art

- Previous RFC regarding nomenclature in code: https://github.com/CodaProtocol/coda/blob/develop/rfcs/0018-postake-naming-conventions.md

## Unresolved questions
[unresolved-questions]: #unresolved-questions

There will likely be other terms we will need to converge on.
