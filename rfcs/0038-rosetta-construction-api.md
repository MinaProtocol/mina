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

**Before Derivation**

[prederivation]: #prederivation

Before the derivation step, we need to generate a keypair. We'll use the private key to sign the transaction and the public key to tell others who the sender of the transaction is.

**Derivation**

[derivation]: #derivation

Derivation demands that the public key expected as input be a hex-encoded byte-array value. So we'll [add functionality](#marshallkeys) to the [client-sdk](#marshallkeyssdk), the [generate-keypair binary](#marshallkeysbin), and the offcial [Coda CLI](#marshallkeysdaemon) to marshall the `Fq.t * Fq.t` pair.

The [derivation endpoint](#derivationendpoint) would be responsible for reading in the uncompressed public key bytes which [requires adjusting the Rosetta spec](#addcurves), compressing the public key, and base58-encoding it inline with how we currently represent public keys in serialized form.

**Preprocess**

[preprocess]: #preprocess

The [preprocess endpoint](#preprocessendpoint) takes a proposed set of operations for which we'll need to [clearly specify examples for different transactions]. It returns an input that is needed for the [metadata](#metadata) phase during which we can gather info on-chain.

**Metadata**

[metadata]: #metadata

### Work items

1. Add support for creating/marshalling public keys ([via Derivation](#derivation))

[marshallkeys]: #marshallkeys

**Format**

Public keys are reprsented as hex-encoded, little-endian, byte-padded `Fq.t` pairs.

TODO: Find `x`, see unanswered questions below

```
|----- fst Fq.t (x bytes) ---------|----- snd Fq.t (x bytes) ------|
```

Example:

`(123123, 234234)`

is encoded as the string:

`0001E0F3000392FA`

**Name**

We'll call this the "raw" format for our public keys. In most places, we can get away with just adding a `-raw` flag in some form to support this new kind of representation.

a. Change the Client-SDK

[marshallkeyssdk]: #marshallkeyssdk

i. Add a `rawPublicKeyOfPrivateKey` method to the exposed `client_sdk.ml` module that returns `of_private_key_exn s` which is then marshalled to a string according to the above specification.

ii. Add a new `rawPublicKey : publickey -> string` function to `CodaSDK`.

iii. Add new documentation for this change.

b. Change the generate-keypair binary

[marshallkeysbin]: #marshallkeysbin

i. Also print out the raw representation after generating the keypair on a new line:

`Raw public key: 0001E0F3000392FA`

ii. Add a new subcommand `show-public-key` which takes the private key file as input and prints the same output as running the generate command.

c. Change coda cli

[marshallkeysdaemon]: #marshallkeysdaemon

i. Add a new subcommand `show-public-key` as a subcommand to `coda accounts` (reuse the implementation in (b.ii)

2. Derivation endpoint ([via Derivation](#derivation))

Read in the bytes, compress the public key, and base58-encoding it inline with how we currently represent public keys in serialized form. Adding errors apprioriately for malformed keys.

3. Add support for our curves and signature to Rosetta ([via Derivation](#derivation))

[addcurves]: #addcurves

Follow the instructions on [this forum post](https://community.rosetta-api.org/t/add-secp256r1-to-curvetype/130/2) to add support for the [tweedle curves and schnorr signatures](https://github.com/CodaProtocol/signer-reference). This entails updating the rosetta specification with documentation about this curve, and changing the rosetta-sdk-go implementation to recognize the new curve and signature types. Do not worry about adding the implementation to the keys package of rosetta-cli for now.

4.

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

- How many bits long is `Snarky_bn382.Tweedle.Fq.t`?

It's not immediately obvious from reading through the header in the snarky_bn382 lib. I'd like to know to better fully specify the serialization format.

- What parts of the design do you expect to resolve through the RFC process before this gets merged?
- What parts of the design do you expect to resolve through the implementation of this feature before merge?
- What related issues do you consider out of scope for this RFC that could be addressed in the future independently of the solution that comes out of this RFC?
