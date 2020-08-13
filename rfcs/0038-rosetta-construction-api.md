## Summary

[summary]: #summary

The [Rosetta Construction API](https://www.rosetta-api.org/docs/construction_api_introduction.html) is the write-half of the Rosetta API. This RFC discusses the different chunks of work that need to get done to make this half a reality. Note that discussion of the Data API is out-of-scope for this RFC (and is already fully implemented and partially tested).

## Motivation

[motivation]: #motivation

We wish to support Rosetta as it enables clients to build once and support multiple chains. Many vendors that wish to build on top of our protocol are asking for full Rosetta support. Not just the read-half (the Data API) but also the write-half.

The desired outcome is a full to-spec Construction API implementation.

## Detailed design

[detailed-design]: #detailed-design

The following flow chart is pulled from the [Rosetta documentation](https://www.rosetta-api.org/docs/construction_api_introduction.html), but useful for understanding the different pieces necessary for the implementation:

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

The initial version of the construction API will _only_ support payments. We can quickly follow with a version that will support delgation as well. This RFC will talk about all the tasks assuming both payments and delegations are supported. All token-specific transactions (and any future transactions) are not yet supported and out-of-scope for this RFC.

### Flow chart

#### Before Derivation

Before the derivation step, we need to generate a keypair. We'll use the private key to sign the payment and the public key to tell others who the sender is.

#### Derivation

[derivation]: #derivation

Derivation demands that the public key expected as input be a hex-encoded byte-array value. So we'll [add functionality](#marshalkeys) to the [client-sdk](#marshalkeys), the [generate-keypair binary](#marshalkeys), and the offcial [Coda CLI](#marshalkeys) to marshall the `Fq.t * Fq.t` pair (the native representation of an uncompressed public key).

The [derivation endpoint](#derivation-endpoint) would be responsible for reading in the uncompressed public key bytes which [requires adjusting the Rosetta spec](#addcurves), compressing the public key, and base58-encoding it inline with how we currently represent public keys in serialized form.

#### Preprocess

[preprocess]: #preprocess

The [preprocess endpoint](#preprocess-endpoint) takes a proposed set of operations for which we'll need to [clearly specify examples for different transactions](#operations-docs). It assures they can be [converted into transactions](#inverted-operations-map) and it returns an input that is needed for the [metadata](#metadata) phase during which we can gather info on-chain. In our case, this is just the sender's public key.

#### Metadata

[metadata]: #metadata

The [metadata endpoint](#metadata-endpoint) takes the senders public key and returns which nonce to use for transaction construction.

#### Payloads

[payloads]: #payloads

The [payloads endpoint](#payloads-endpoint) takes the metadata and the operations and returns an [encoded unsigned transaction](#encoded-unsigned-transaction).

#### After Payloads

[after-payloads]: #after-payloads

After the payloads endpoint, folks must sign the transaction. In the future, we should build support for this natively, but for now our client-sdk's signing mechanism suffices. As such, we don't need to do much here other than [encode the signed transaction properly](#encoded-signed-transaction).

#### Parse

[parse]: #parse

The [parse endpoint](#parse-endpoint) takes a possibly signed transaction and parses it into operations.

#### Combine

[combine]: #combine

The [combine endpoint](#combine-endpoint) takes an unsigned transaction and the signature and returns an [encoded signed transaction](#encoded-signed-transaction).

#### Hash

[hash]: #hash

The [hash endpoint](#hash-endpoint) takes the signed transaction and returns the hash.

#### Submit

[submit]: #submit

The [submit endpoint](#submit-endpoint) takes a signed transaction and broadcasts it over the network. We also should [audit broadcast behavior to ensure errors are returned when mempool add fails](#audit-transaction-broadcast).

#### Testing

We should [integrate the construction calls](#test-integrate-construction) into the existing `test-agent`. By doing this, we don't need to worry about getting this into CI since it is already there (or will be by the time this RFC lands, thanks @lk86 !).

We also will want to [integrate the official rosetta-cli](#test-rosetta-cli) to verify our implementation.

In addition, we'll manually test on subsequent QA and Testnets.

### Work items

Think of these as the tasks necessary to complete this project. Each item here will turn into a GitHub issue when this RFC lands.

#### Marshal Keys

[marshalkeys]: #marshalkeys

Add support for creating/marshalling public keys ([via Derivation](#derivation))

**Format**

Public keys are represented as hex-encoded, little-endian, `Fq.t` pairs.

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

Read in the bytes, compress the public key, and base58-encoding it inline with how we currently represent public keys in serialized form. Adding errors appropriately for malformed keys.

#### Add curves

[addcurves]: #addcurves

Add support for our curves and signature to Rosetta ([via Derivation](#derivation))

Follow the instructions on [this forum post](https://community.rosetta-api.org/t/add-secp256r1-to-curvetype/130/2) to add support for the [tweedle curves and schnorr signatures](https://github.com/CodaProtocol/signer-reference). This entails updating the rosetta specification with documentation about this curve, and changing the rosetta-sdk-go implementation to recognize the new curve and signature types. Do not worry about adding the implementation to the keys package of rosetta-cli for now.

#### Operations docs

[operations-docs]: #operations-docs

Add examples of each kind of transaction that one may want to construct as JSON files. Eventually we'd want one for each type of transaction, but for now it suffices to just include a payment.

For example: The following expressrion would be saved in `payment.json`

```
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

#### Metadata Endpoint

[preprocess-endpoint]: #preprocess-endpoint

[via Metadata](#metadata)

This is a simple GraphQL query. This endpoint should be easy to implement.

#### Unsigned transaction encoding

[encoded-unsigned-transaction]: #encoded-unsigned-transaction

[via Payloads](#payloads)

The Rosetta spec leaves the encoding of unsigned transactions implementation-defined. Since we'll default to using our client-sdk's signing mechanism our encoding will be precisely the JSON input (stringified) demanded by the "unsafe" method of the client-sdk API:

```reasonml
// Taken from Client-SDK code

type stakeDelegation = {
  [@bs.as "to"]
  to_: publicKey,
  from: publicKey,
  fee: uint64,
  nonce: uint32,
  memo: option(string),
  validUntil: option(uint32),
};

type payment = {
  [@bs.as "to"]
  to_: publicKey,
  from: publicKey,
  fee: uint64,
  amount: uint64,
  nonce: uint32,
  memo: option(string),
  validUntil: option(uint32),
};

type transaction = stakeDelegation | payment
```

Note that our client-sdk only has support for signing payments and delegation but this version of the construction API only supports those transactions types as well.

#### Payloads Endpoint

[payloads-endpoint]: #payloads-endpoint

[via Payloads](#payloads)

First [convert the operations](#inverted-operations-map) embedding the correct sender nonce from the metadata. Return an [encoded unsigned transaction](#encoded-unsigned-transaction) as described above.

#### Signed transaction encoding

[encoded-signed-transaction]: #encoded-signed-transaction

[via After Payloads](#after-payloads)

Since we'll later be broadcasting the signed transaction via GraphQL, our signed transaction encoding is precicesly the union of the format required for the sendPayment mutation and the sendDelegation mutation (stringified):

```
{
  signature: Signature, // defined in graphql
  sendPaymentInput: SendPaymentInput?, // defined in graphql
  sendDelegationInput: SendDelegationInput? // defined in graphql
}
```

#### Parse Endpoint

[parse-endpoint]: #parse-endpoint

[via Parse](#parse)

The parse endpoint takes the transaction and needs to return the operations. The implementation will use the same logic as the Data API transaction -> operations logic and so we do not need an extra task to make this happen.

#### Combine Endpoint

[combine-endpoint]: #combine-endpoint

[via Combine](#combine)

The combine endpoint [encodes the signed transaction](#encoded-signed-transaction) according to the schema defined above.

#### Hash Endpoint

[hash-endpoint]: #hash-endpoint

[via Hash](#hash)

The hash endpoint takes the signed transaction and returns the hash. This can be done by pulling in `Coda_base` into Rosetta and calling hash on the transaction.

#### Audit transaction broadcast

[audit-transaction-broadcast]: #audit-transaction-broadcast

[via Submit](#submit)

Upon skimming our GraphQL implementation, it seems like it is already succeeding only if the transaction is successfully added to the mempool, but it important we more carefully audit the implementation to ensure this is the case as it's an explicit requirement in the spec.

#### Submit

[submit-endpoint]: #submit-endpoint

[via Submit](#submit)

The submit endpoint takes a signed transaction and broadcasts it over the network. We can do this by calling the `sendPayment` or `sendDelegation` mutation depending on the state of the input.

#### Test integrate construction

[test-integrate-construction]: #test-integrate-construction

[via Testing](#testing)

The existing Rosetta test-agent tests our Data API implementation by running a demo instance of Coda and mutating its state with GraphQL mutations and then querying with the Data API to see if the data that comes out is equivalent to what we put in.

We can extend the test-agent to also send construction API requests. We should at least add behavior to send a payment and delegation constructed using this API. We can shell out to a subprocess to handle the "off-api" pieces of keypair generation and signing.

We also should include logic that verifies the following:

1. The unsigned transaction output by payloads parses into the same operations provided
2. The signed transaction output by combine parses into the same operations provided
3. After the signed transaction is in the mempool, the result from the data api is a superset of the operations provided originally
4. After the signed transaction is in a block, the result from the data api is a superset of the operations provided orginally

#### Test Rosetta CLI

[test-rosetta-cli]: #test-rosetta-cli

[via Testing](#testing)

The [rosetta-cli](https://github.com/coinbase/rosetta-cli) is used to verify correctness of implementations of the rosetta spec. This should be run in CI against our demo node and against live qa and testnets. We can release a version on a testnet before we've fully verified the implementation against rosetta-cli, but the project is not considered "done" until we've done this properly.

It's worth noting that the rosetta-cli is [about to get new features to be more flexible at testing other construction API scenarios](https://community.rosetta-api.org/t/feedback-request-automated-construction-api-testing-improvements/146/4). These changes will certainly support payments and delegations. We don't need to wait for the implementation of this new system to support payments today.

## Drawbacks

[drawbacks]: #drawbacks

It's extra work, but we really wish to enable folks to build on our protocol in this way.

## Rationale and alternatives

[rationale-and-alternatives]: #rationale-and-alternatives

Decisions were made here to limit scope where possible to enable shipping an MVP as soon as possible. This is why we are explicitly not supporting extra transactions on top of payments (initially) and payments+delegations (closely afterwards).

Luckily Rosetta has a very clear specification, so our designs are mostly constrained by the decisions made in that API.

In [marshal keys (c)](#marshalkeys), we could also change commands that accept public keys to also accept this new format. Additionally, we could change the GraphQL API to support this new format too. I think both of these changes are unnecessary to prioritize as the normal flows will still be fine and we'll still encourage folks to pass around the standard base58-encoded compressed public keys as they are shorter.

In the sections about [encoding unsigned transactions](#encoded-unsigned-transaction) and [encoding signed transactions](#encoded-signed-transaction), we make an explicit decision to pick a format that fits what our client-sdk expects. This was done to improve implementation velocity and because we did conciously choose that interface with usability in mind. Additionaly, using a readable JSON string makes it easy to audit, debug, and understand our implementation. This design does subsequently require extra processing for other signers (like a ledger hardware device or a native binary).

## Prior art

[prior-art]: #prior-art

The [spec](https://www.rosetta-api.org/docs/construction_api_introduction.html)

## Unresolved questions

[unresolved-questions]: #unresolved-questions

There are no unresolved questions at this time that I'd like to answer before merging this RFC.

As stated above, explicitly out-of-scope is any future changes to the Data API portion of Rosetta and Construction API support for transactions other than payments and delegations.
