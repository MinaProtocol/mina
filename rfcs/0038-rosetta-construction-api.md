## Summary

[summary]: #summary

The [Rosetta Construction API](https://www.rosetta-api.org/docs/construction_api_introduction.html) is the write-half of the Rosetta API. This RFC discusses the different chunks of work that need to get done to make this half a reality. Note that discussion of the Data API is out-of-scope for this RFC (and is already fully implemented and partially tested).

## Motivation

[motivation]: #motivation

We wish to support Rosetta as it enables clients to build once and support multiple chains. Many vendors that wish to build on top of our protocol are asking for full Rosetta support. Not just the read-half (the Data API) but also the write-half.

The outcome is a full to-spec Construction API implementation.

## Detailed design

[detailed-design]: #detailed-design

The following flow chart is pulled from the Rosetta documentation, but useful for understanding the different pieces necessary for the implementation:

```
                               Caller (i.e. Coinbase)                + Construction API Implementation
                              +-------------------------------------------------------------------------------------------+
                                                                     |
                               Derive Address   +----------------------------> /construction/derive
                               from Public Key                       |
                                                                     |
                             X                                       |
                             X Create Metadata Request +---------------------> /construction/preprocess
                             X (array of operations)                 |                    +
    Get metadata needed      X                                       |                    |
    to construct transaction X            +-----------------------------------------------+
                             X            v                          |
                             X Fetch Online Metadata +-----------------------> /construction/metadata (online)
                             X                                       |
                                                                     |
                             X                                       |
                             X Construct Payloads to Sign +------------------> /construction/payloads
                             X (array of operations)                 |                   +
                             X                                       |                   |
 Create unsigned transaction X          +------------------------------------------------+
                             X          v                            |
                             X Parse Unsigned Transaction +------------------> /construction/parse
                             X to Confirm Correctness                |
                             X                                       |
                                                                     |
                             X                                       |
                             X Sign Payload(s) +-----------------------------> /construction/combine
                             X (using caller's own detached signer)  |                 +
                             X                                       |                 |
   Create signed transaction X         +-----------------------------------------------+
                             X         v                             |
                             X Parse Signed Transaction +--------------------> /construction/parse
                             X to Confirm Correctness                |
                             X                                       |
                                                                     |
                             X                                       |
                             X Get hash of signed transaction +--------------> /construction/hash
Broadcast Signed Transaction X to monitor status                     |
                             X                                       |
                             X Submit Transaction +--------------------------> /construction/submit (online)
                             X                                       |
                                                                     +
```

This flow chart will guide our explanation of what is needed to build a full to-spec implementation of the API. Afterwards, we'll list out each proposed piece of work with details of how it should be implemented. Upon mergin of this RFC, each work item will become an issue on GitHub.

### Flow chart

#### Before Derivation

Before the derivation step, we need to generate a keypair. We'll use the private key to sign the transaction and the public key to tell others who the sender of the transaction is.

#### Derivation

[derivation]: #derivation

Derivation demands that the public key expected as input be a hex-encoded byte-array value. So we'll [add functionality](#marshalkeys) to the [client-sdk](#marshalkeys), the [generate-keypair binary](#marshalkeys), and the offcial [Coda CLI](#marshalkeys) to marshall the `Fq.t * Fq.t` pair.

The [derivation endpoint](#derivation-endpoint) would be responsible for reading in the uncompressed public key bytes which [requires adjusting the Rosetta spec](#addcurves), compressing the public key, and base58-encoding it inline with how we currently represent public keys in serialized form.

#### Preprocess

[preprocess]: #preprocess

The [preprocess endpoint](#preprocess-endpoint) takes a proposed set of operations for which we'll need to [clearly specify examples for different transactions](#operations-docs). It assures they can be [converted into transactions](#inverted-operations-map) and it returns an input that is needed for the [metadata](#metadata) phase during which we can gather info on-chain. In our case, this is just the sender's public key.

#### Metadata

[metadata]: #metadata

The [metadata endpoint](#metadata-endpoint) takes the senders public key and finds what nonce to use for transaction construction.

#### Payloads

[payloads]: #payloads

The [payloads endpoint](#payloads-endpoint) takes the metadata and the operations and returns a [encoded unsigned transaction]. A [test] should be included that ensures that after such a transaction is signed and included in the mempool the operations returned are a superset of the ones provided. After it is in a block it is also a superset of the ones provided as input to the endpoint.

#### Parse

[parse]: #parse

The [parse endpoint](#parse-endpoint) takes a possibly signed transaction and parses it. The implementation will use the same logic as the Data API transaction -> operations logic and so we do not need an extra task to make this happen.

#### Combine

[combine]: #combine

The [combine endpoint](#combine-endpoint) takes an unsigned transaction and the signature and returns an [encoded signed transaction].

#### Hash

[hash]: #hash

The [hash endpoint](#hash-endpoint) takes the signed transaction and returns the hash.

#### Submit

[submit]: #submit

The [submit endpoint](#submit-endpoint) takes a signed transaction and broadcasts it over the network. Upon skimming our GraphQL implementation, it seems like it is already succeeding only if the transaction is successfully added to the mempool, but it important we more carefully [audit the implementation to ensure this is the case].

#### Testing

A [test] should be included that ensures:

1. The unsigned transaction output by payloads parses into the same operations provided
2. The signed transaction output by combine parses into the same operations provided
3. After the signed transaction is in the mempool, the result from the data api is a superset of the operations provided originally
4. After the signed transaction is in a block, the result from the data api is a superset of the operations provided orginally

### Work items

#### Marshal Keys

[marshalkeys]: #marshalkeys

Add support for creating/marshalling public keys ([via Derivation](#derivation))

**Format**

Public keys are reprsented as hex-encoded, little-endian, `Fq.t` pairs.

TODO: Find `x`, see unanswered questions below

```
|----- fst pk : Fq.t (32 bytes) ---------|----- snd pk : Fq.t (32 bytes) ------|
```

Example:

`(123123, 234234)`

is encoded as the string:

`000000000000000000000000000000000000000000000000000000000001E0F300000000000000000000000000000000000000000000000000000000000392FA`

(abbreviated as `...01E0F3...0392FA` for the purposes of this doc)

**Name**

We'll call this the "raw" format for our public keys. In most places, we can get away with just adding a `-raw` flag in some form to support this new kind of representation.

a. Change the Client-SDK

i. Add a `rawPublicKeyOfPrivateKey` method to the exposed `client_sdk.ml` module that returns `of_private_key_exn s` which is then marshalled to a string according to the above specification.

ii. Add a new `rawPublicKey : publickey -> string` function to `CodaSDK`.

iii. Add new documentation for this change.

b. Change the generate-keypair binary

i. Also print out the raw representation after generating the keypair on a new line:

`Raw public key: ...01E0F3...0392FA`

ii. Add a new subcommand `show-public-key` which takes the private key file as input and prints the same output as running the generate command.

c. Change coda cli

i. Add a new subcommand `show-public-key` as a subcommand to `coda accounts` (reuse the implementation in (b.ii)

#### Derivation endpoint

[derivation-endpoint]: #derivation-endpoint

[via Derivation](#derivation)

Read in the bytes, compress the public key, and base58-encoding it inline with how we currently represent public keys in serialized form. Adding errors apprioriately for malformed keys.

#### Add curves

[addcurves]: #addcurves

Add support for our curves and signature to Rosetta ([via Derivation](#derivation))

Follow the instructions on [this forum post](https://community.rosetta-api.org/t/add-secp256r1-to-curvetype/130/2) to add support for the [tweedle curves and schnorr signatures](https://github.com/CodaProtocol/signer-reference). This entails updating the rosetta specification with documentation about this curve, and changing the rosetta-sdk-go implementation to recognize the new curve and signature types. Do not worry about adding the implementation to the keys package of rosetta-cli for now.

#### Operations docs

[operations-docs]: #operations-docs

Add examples of each kind of transaction that one may want to construct as JSON files. Eventually we'd want one for each type of transaction, but for now it suffices to just include a payment.

For example: The following expressrion would be saved in `payment.json`

```json
[{
  "operation_identifier": ...,
  "amount": ...,
  "type": "Payment_source_dec"
},
{
  "operation_identifier": ...,
  "amount": ...,
  "type": "Payment_receiver_inc"
},
...
]
```

This is useful for manual testing purposes and sets us up for integration with the [construction-portion of rosetta-cli integration](https://community.rosetta-api.org/t/feedback-request-automated-construction-api-testing-improvements/146/4).

#### Inverted operations map

[inverted-operations-map]: #inverted-operations-map

[via Preprocess](#preprocess)

Write a function that recovers the transactions that are associated with some set of operations. We should create a test `forall (t : Transaction). op^-1(op(t)) ~= t` which enumerates all the kinds of transactions. For an initial release it suffices to test this for payments.

#### Preprocess Endpoint

[preprocess-endpoint]: #preprocess-endpoint

[via Preprocess](#preprocess)

First [invert the operations](#inverted-operations-map) into a transaction, we find the sender and include the public key in the response. The options type will be defined as follows:

```ocaml
module Options = struct
  type t =
    { sender : string (* base58-ecoded compressed public key *)
    }
    [@@deriving yojson]
end
```

## Drawbacks

[drawbacks]: #drawbacks

It's extra work, but we really wish to enable folks to build on our protocol in this way.

## Rationale and alternatives

[rationale-and-alternatives]: #rationale-and-alternatives

- Why is this design the best in the space of possible designs?
- What other designs have been considered and what is the rationale for not choosing them?
- What is the impact of not doing this?

In [1.c.](#marshallkeysdaemon), we could also change commands that accept public keys to also accept this new format. Additionally, we could change the GraphQL API to support this new format too. I think both of these changes are unnecessary to prioritize as the normal flows will still be fine and we'll still encourage folks to pass around the standard base58-encoded compressed public keys as they are shorter.

## Prior art

[prior-art]: #prior-art

Discuss prior art, both the good and the bad, in relation to this proposal.

## Unresolved questions

[unresolved-questions]: #unresolved-questions

- Is it necessary to precompute the next-token-id for creating new tokens during metadata?

If the transaction involves minting a new token we also lookup the next-token-id.

- What parts of the design do you expect to resolve through the RFC process before this gets merged?
- What parts of the design do you expect to resolve through the implementation of this feature before merge?
- What related issues do you consider out of scope for this RFC that could be addressed in the future independently of the solution that comes out of this RFC?
