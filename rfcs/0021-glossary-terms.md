## Summary
[summary]: #summary

This RFC proposes standardized glossary terms for various concepts in the Coda Protocol and how they are communicated to the external world in documentation, logging, user interfaces, and public communications. This is not intended to cover the existing codebase in scope, as it may be too cumbersome at this point to rename everything to fit these proposed conventions. 

However, it is advisable that over time the codebase also migrates to this shared terminology so that future community members can on-board seamlessly from high level documentation to contributing code.

## Motivation

[motivation]: #motivation

<!-- Why are we doing this? What use cases does it support? What is the expected outcome? -->

Currently, multiple terms exist for several concepts in the Coda protocol, and they are used interchangeably when communicating to the world. This has some downsides as there is a lack of clarity on which terms to use, and could potentially cause confusion for people unfamiliar with the protocol. 

As such, the motivation of this RFC is to standardize the naming convention for various concepts into a unified glossary that can be used in documentation, user-facing copy, and marketing channels. The expected outcome is unified language when communicating to the public and in developing Coda related products. This can then lead to more clarity and easier onboarding.

## Detailed design

[detailed-design]: #detailed-design

<!-- This is the technical portion of the RFC. Explain the design in sufficient detail that:

* Its interaction with other features is clear.
* It is reasonably clear how the feature would be implemented.
* Corner cases are dissected by example. -->

The proposal contains the suggested term with it's associated concept it encapsulates, as well as alternative terms and the rationale for  the suggestion.

The terms proposed are below:

### Block Producer
Concept: A consensus node in the network that is selected for a slot, and generates a block.

Rationale: This term is used by other protocols, clearly describes the role duties, and is unambiguous.

Downsides: EOS is the most popular chain that uses "block producers" and there is a chance of confusion if people think Coda also has only 21 block producers - but this is a tail risk.

Usage: A block producer or block producing node stakes coda to participate in consensus.
Alternatives:
- Validator - used by most other protocols, but not suitable for Coda, as every node can be a "verifier" or "validator" of SNARKs.
- Staker - tied to a specific consensus model, and doesn't explain what the node does for the network. It also has an edit distance of 2 from snarker, which can cause some confusion.
- Proposer - currently used in codebase, but unused by other protocols, and also sounds less firm / tied to generating blocks (relative to producer).
- Prover - currently used to describe the action of generating the block SNARK, but if this that job moves to snark workers, then this term is irrelevant.
- Miner, Baker, etc - not relevant to Coda's consensus mechanism.

### Block
Concept: a set of transactions that represent a state transition.

ationale: This term aligns with the rest of the industry, and it makes it easier to onboard other blockchain users.
Downsides: Perhaps it is not as technically accurate as a transition.

Usage: In the Coda network, transactions get added to blocks.

Alternatives:
- External transition - maybe this is more precise, but has the heavy lifting of having to explain a new term for a mostly similar concept. Additionally, the word transition is very similar to transaction, causing confusion at times.

### User Transaction
Concept: A transaction issued by a user - currently a payment or a delegation change

Rationale: This term clearly describes the concept, and leaves room for further types of user issued transactions.

Downsides: This is a subset of "Transactions", so it is a bit redundant.

Usage: There are three types of transactions in the Coda network currently - user transactions, fee transfers, and coinbases.

Alternatives:
- User command - this term is confusing, especially in  docs, as it can be conflated with a CLI command that a user issues.

### Snark worker / Snarker
Concept: A Coda node that produces SNARKs to compress transactions (and in the future, blocks) in the network.

Rationale: The community likes SNARKs and it is a point of differentiation for Coda, so snarker is an engaging term.

Downsides: Get's invalidated if Coda switches to another type of zero-knowledge proof. NOTE - There is some concern about using the progressive tense of "snark" as a verb, eg. "snarking" - as this can be confused with staking. However, if the community enjoys "snarking", it  would make sense to  continue using it as a verb.

Usage: 
- Anyone can join the coda network and become a snark worker.
- Snark workers help compress the blockchain by generating SNARKs.

Alternatives:
- Compressor - this term was considered initially, but given the community excitement about SNARKs, it makes sense to include the more specific term in the lexicon.

### Full node
Concept: A Coda node that is able to verify the state of the network - however it may need to request paths for its accounts from other nodes that have all the accounts state.

Rationale: By calling this type of node a full node, Coda distinguishes itself from other networks, as all nodes are technically full nodes if they can verify SNARKs - these nodes are not required to trust other nodes.

Downsides: Because these nodes still need to request state from other nodes, there is an argument to be made that they are not full nodes. Furthermore, Bitcoin classifies full nodes as nodes that "download every block and transaction and check them against Bitcoin's consensus rules." Therefore, there may be some community pushback against calling these nodes full nodes, even though they are trustless.

Usage: On the Coda network, even phones can run full nodes!

Alternatives:
- Fully verifying nodes - more accurate, but a mouthful, and have to create a new term.
- Trustless nodes - again, some lifting required.


### Coda vs coda vs CODA
Concept: "Coda" is the network / protocol. "coda" is the token. "CODA" is the ticker symbol.

Rationale: Aligns with other networks, and makes it easy to differentiate context based on casing.

Downsides: More things to remember.

Usage: The native token of the Coda network is coda.

Alternatives:
- Use "Coda" everywhere.


## Drawbacks
[drawbacks]: #drawbacks

<!-- Why should we *not* do this? -->

The drawback to aligning on language is that we lose some specificity that comes with each specific term, relative to the others. However, this concern is minor, and is superceded by the need for consistent language.

## Rationale and alternatives
[rationale-and-alternatives]: #rationale-and-alternatives

<!-- * Why is this design the best in the space of possible designs? -->
<!-- * What other designs have been considered and what is the rationale for not choosing them? -->
<!-- * What is the impact of not doing this? -->
See [design section](#detailed-design) for rationale and alternatives.

## Prior art
[prior-art]: #prior-art

<!-- Discuss prior art, both the good and the bad, in relation to this proposal. -->

- Previous RFC regarding nomenclature in code: https://github.com/CodaProtocol/coda/blob/develop/rfcs/0018-postake-naming-conventions.md

## Unresolved questions
[unresolved-questions]: #unresolved-questions

<!-- * What parts of the design do you expect to resolve through the RFC process before this gets merged? -->
<!-- * What parts of the design do you expect to resolve through the implementation of this feature before merge? -->
<!-- * What related issues do you consider out of scope for this RFC that could be addressed in the future independently of the solution that comes out of this RFC? -->

There will likely be other terms we will need to converge on.