      Title: Mina Schnorr Signatures
      Author: Izaak Mecklker <izaak@o1labs.org>
      Status: Draft
      Type: Informational
      License: BSD-2-Clause

Updates
-------

    - December 2021, Joseph Spadavecchia <joseph@o1labs.org>
      Updated to latest curves and signing algorithm

Introduction
------------

This document proposes a standard for Mina Schnorr signatures over
the elliptic curve [Pallas Pasta](https://o1-labs.github.io/mina-book/specs/pasta_curves.html). It is adapted from a [BIP 340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki).

## Copyright

This document is licensed under the 2-clause BSD license.

Description
-----------

We first build up the algebraic formulation of the signature scheme by
going through the design choices. Afterwards, we specify the exact
encodings and operations.

## Design

**Schnorr signature variant** Elliptic Curve Schnorr signatures for
message *`m`* and public key *`P`* generally involve a point *`R`*, integers
*`e`* and *`s`* picked by the signer, and generator *`G`* which satisfy *`e =
H(R || m)`* and *`sG = R + eP`*. Two formulations exist, depending on
whether the signer reveals *`e`* or *`R`*:

1.  Signatures are *`(e,s)`* that satisfy *`e = H(sG - eP || m)`*. This
    avoids minor complexity introduced by the encoding of the point *`R`*
    in the signature (see paragraphs “Encoding the sign of R” and
    “Implicit Y coordinate” further below in this subsection).
2.  Signatures are *`(R,s)`* that satisfy *`sG = R + H(R || m)P`*. This
    supports batch verification, as there are no elliptic curve
    operations inside the hashes.

We choose the *`R`*-option to support batch verification.

**Key prefixing** When using the verification rule above directly, it is
possible for a third party to convert a signature *`(R,s)`* for key *`P`*
into a signature *`(R,s + aH(R || m))`* for key *`P + aG`* and the same
message, for any integer *`a`*.
To combat this, we choose *key prefixed*[^2]
Schnorr signatures; changing the equation to *`sG = R + H(m1 || P || R || m2 )`* where *`m1`* is the field elements of the message *`m`* and *`m2`* is the rest of the message.

**Encoding the sign of R** As we chose the *`R`*-option above, we're
required to encode the point *`R`* into the signature. Several
possibilities exist:

1.  Encoding the full X and Y coordinates of *`R`*, resulting in a 96-byte
    signature.
2.  Encoding the full X coordinate, but only whether Y is even or odd
    (like compressed public keys). This would result in a 65-byte
    signature.
3.  Encoding only the X coordinate, leaving us with 64-byte signature.

Using the first option would be slightly more efficient for verification
(around 5%), but we prioritize compactness, and therefore choose option
3.

**Implicit Y coordinate** In order to support batch verification, the
Y coordinate of *`R`* cannot be ambiguous (every valid X coordinate has two
possible Y coordinates). We have a choice between several options for
symmetry breaking:

1.  Implicitly choosing the Y coordinate that is in the lower half.
2.  Implicitly choosing the Y coordinate that is even[^3].

We choose option 2 as it is a bit simpler to implement.

**Final scheme** As a result, our final scheme ends up using signatures
*`(r,s)`* where *`r`* is the X coordinate of a point *`R`* on the curve whose
Y coordinate is even, and which satisfies *`sG = R + H(r || P || m)P`*.

## Specification

We first describe the verification algorithm, and then the signature
algorithm.

The following convention is used, with constants as defined for Mina's version of [Pasta Pallas](https://o1-labs.github.io/mina-book/specs/pasta_curves.html):

-   Lowercase variables represent integers or byte arrays.
    -   The constant *`p`* refers to the field size,
       `28948022309329048855892746252171976963363056481941560715954676764349967630337`
    -   The constant *`n`* refers to the curve order,
        `28948022309329048855892746252171976963363056481941647379679742748393362948097`
    -   The constant `a` refers to the first curve parameter which is `0`
    -   The constant `b` refers to the other curve parameter which is `5`
-   Uppercase variables refer to points on the curve with equation *`y^2 = x^3 + ax + b`* over the integers modulo *`p`*.
    -   *`infinite(P)`* returns whether or not *`P`* is the point at
        infinity
    -   *`x(P)`* and *`y(P)`* refer to the X and Y coordinates of a point
        *`P`* (assuming it is not infinity)
    -   The constant *`G`* refers to the generator, for which *`x(G) = 1`*
        and *`y(G) = 12418654782883325593414442427049395787963493412651469444558597405572177144507`*
    -   Addition of points refers to the usual [elliptic curve group
        operation](https://en.wikipedia.org/wiki/Elliptic_curve#The_group_law).
    -   [Multiplication of an integer and a
        point](https://en.wikipedia.org/wiki/Elliptic_curve_point_multiplication)
        refers to the repeated application of the group operation
    - Base field and scalar field elements are represented in little-endian order
-   Functions and operations:
    -   `||` refers to either array concatenation or bit string concatenation
    -   *`[s]G`* refers to elliptic curve scalar multiplication of *`s`* with generator *`G`*
    -   *`blake2b`* - [Blake2b](https://www.blake2.net/) cryptographic hash function with 32-byte output size
    -   *`poseidon_3w`* - [Poseidon cryptographic hash function for Mina](https://github.com/o1-labs/cryptography-rfcs/blob/master/mina/001-poseidon-sponge.md)
    -   *`scalar(r)`* refers to the scalar field element obtained from random bytes *`r`* by dropping two MSB bits
    -   *`s(σ)`* refers to scalar field component of signature *`σ`*
    -   *`x(σ)`* refers to base field component of signature *`σ`*
    -   *`odd(e)`* - true if base field element *`e`* is odd, false otherwise
    -   *`negate(s)`* - negation of scalar field element *`s`*
    -   *`fields(m)`* - vector containing components of message *`m`* that are base field elements
    -   *`bits(m)`* - all other parts of message *`m`* that are not in *`fields(m)`*
    -   *`pack(byte)`* - convert *`byte`* into 8 bits little-endian order
    -   *`pack(e)`* - convert base field element *`e`* into 255 bits little-endian order
    -   *`pack(E)`* - convert vector of base field elements *`E = [e1, ..., en]`* into bit string *`pack(e1) || ... || pack(en)`*
    -   *`pack(s)`* - convert scalar field element *`s`* into 255 bits little-endian order
    -   *`unpack(bits)`* - convert bit string *bits = b<sub>1</sub>b<sub>2</sub>...b<sub>255</sub>b<sub>256</sub>...b<sub>510</sub>...* into vector of base field elements *`[e1, e2, ..., en]`* where *e1 = b<sub>1</sub>...b<sub>255</sub>0*, *e2 = b<sub>256</sub>...b<sub>510</sub>0* and so on, such that the last element is zero-padded to 255 bits if necessary.
    -   *`iv(id) `* - unique `poseidon_3w` initialization vector for blockchain instance identified with `id`:
        -   Testnet (*`id = 0x00`*)
            ```rust
            [
                28132119227444686413214523693400847740858213284875453355294308721084881982354,
                24895072146662946646133617369498198544578131474807621989761680811592073367193,
                3216013753133880902260672769141972972810073620591719805178695684388949134646
            ]
            ```
        -   Mainnet (*`id = 0x01`*)
            ```rust
            [
                25220214331362653986409717908235786107802222826119905443072293294098933388948,
                7563646774167489166725044360539949525624365058064455335567047240620397351731,
                171774671134240704318655896509797243441784148630375331692878460323037832932,
            ]
            ```

There following helper functions are required.

### **Nonce derivation**

-   Input:
    -   Secret key *`d`*: an integer in the range *`1..n-1`*
    -   Public key *`P`*: a curve point
    -   Message *`m`*: message to be signed
    -   Network id *`id`*: blockchain instance identifier
-   Definition: *`derive_nonce(d, P, m, id) = `*
    -   Let *`bytes = pack(fields(m)) || pack(x(P)) || pack(y(P)) || pack(bits(m)) || pack(d) || pack(id)`*
    -   Let *`digest = blake2b(bytes)`*
-   Output: *`scalar(digest)`*

### **Message hash**

-   Input:
    -   Public key *`P`*: a curve point
    -   Base field element *`rx`*: X coordinate of nonce point
    -   Message *`m`*: message to be signed
    -   Network id *`id`*: blockchain instance identifier
-   Definition: *`message_hash(P, rx, m, id) = `*
    -   Let *`fields = fields(m) || x(P) || y(P) || xr || unpack(bits(m))`*
    -   Let *`b = poseidon_3w(iv(id), fields)`*
-   Output: *`scalar(b)`*

The signing and verification algorithms are as follows.

### **Signature verification**

- Input:
  - Public key *`P`*: a curve point
  - Message *`m`*: message
  - Signature *`σ`*: signature on *`m`*
  - Network id *`id`*: blockchain instance identifier
- The signature is valid if and only if the algorithm below does not fail.
  - Let *`e = message_hash(P, x(R), m, id)`*
  - Let *`R = [s(σ)]G - [e]P`*
  - Fail if *`infinite(R) OR odd(y(R)) OR x(R) != x(σ)`*

### **Signature generation**

- Input:
  - Secret key *`d`*: an integer in the range *`1..n-1`*
  - Public key *`P`*: a curve point
  - Message *`m`*: message to be signed
  - Network id *`id`*: blockchain instance identifier
- To sign *`m`* for public key *`P = dG`*:
  -   Let *`k = derive_nonce(d, P, m, id)`*
  -   Let *`R = [k]G`*
  -   If *`odd(y(R))` then `negate(k)`*
  -   Let *`e = message_hash(P, x(R), m, id)`*
  -   Let *`s = k + e*d`*
-   The signature *`σ = (x(R), s)`*

**Above deterministic derivation of *`R`* is designed specifically for
this signing algorithm and may not be secure when used in other
signature schemes.** For example, using the same derivation in the MuSig
multi-signature scheme leaks the secret key (see the [MuSig
paper](https://eprint.iacr.org/2018/068) for details).

Note that this is not a *unique signature* scheme: while this algorithm
will always produce the same signature for a given message and public
key, *`k`* (and hence *`R`*) may be generated in other ways (such as by a
CSPRNG) producing a different, but still valid, signature.

## Optimizations

Many techniques are known for optimizing elliptic curve implementations.
Several of them apply here, but are out of scope for this document. Two
are listed below however, as they are relevant to the design decisions:

**Jacobi symbol** The function *`jacobi(x)`* is defined as above, but can
be computed more efficiently using an [extended GCD
algorithm](https://en.wikipedia.org/wiki/Jacobi_symbol#Calculating_the_Jacobi_symbol).

**Jacobian coordinates** Elliptic Curve operations can be implemented
more efficiently by using [Jacobian
coordinates](https://en.wikibooks.org/wiki/Cryptography/Prime_Curve/Jacobian_Coordinates).
Elliptic Curve operations implemented this way avoid many intermediate
modular inverses (which are computationally expensive), and the scheme
proposed in this document is in fact designed to not need any inversions
at all for verification. When operating on a point *`P`* with Jacobian
coordinates *`(x,y,z)`* which is not the point at infinity and for which
*`x(P)`* is defined as *`x / z^2`* and *`y(P)`* is defined as *`y / z^3`*:

-   *`jacobi(y(P))`* can be implemented as *`jacobi(yz mod p)`*.
-   *`x(P) ≠ r`* can be implemented as *`x ≠ z^2^r mod p`*.

Applications
------------

There are several interesting applications beyond simple signatures.
While recent academic papers claim that they are also possible with
ECDSA, consensus support for Schnorr signature verification would
significantly simplify the constructions.

## Multisignatures and Threshold Signatures

By means of an interactive scheme such as
[MuSig](https://eprint.iacr.org/2018/068), participants can produce a
combined public key which they can jointly sign for. This allows n-of-n
multisignatures which, from a verifier's perspective, are no different
from ordinary signatures, giving improved privacy and efficiency versus
*CHECKMULTISIG* or other means.

Further, by combining Schnorr signatures with [Pedersen Secret
Sharing](https://link.springer.com/content/pdf/10.1007/3-540-46766-1_9.pdf),
it is possible to obtain [an interactive threshold signature
scheme](https://cacr.uwaterloo.ca/techreports/2001/corr2001-13.ps) that
ensures that signatures can only be produced by arbitrary but
predetermined sets of signers. For example, k-of-n threshold signatures
can be realized this way. Furthermore, it is possible to replace the
combination of participant keys in this scheme with MuSig, though the
security of that combination still needs analysis.

## Adaptor Signatures

[Adaptor signatures](https://web.archive.org/web/20211123033324/https://download.wpsoftware.net/bitcoin/wizardry/mw-slides/2018-05-18-l2/slides.pdf)
can be produced by a signer by offsetting his public nonce with a known
point *`T = tG`*, but not offsetting his secret nonce. A correct signature
(or partial signature, as individual signers' contributions to a
multisignature are called) on the same message with same nonce will then
be equal to the adaptor signature offset by *`t`*, meaning that learning
*`t`* is equivalent to learning a correct signature. This can be used to
enable atomic swaps or even [general payment
channels](https://eprint.iacr.org/2018/472) in which the atomicity of
disjoint transactions is ensured using the signatures themselves, rather
than Bitcoin script support. The resulting transactions will appear to
verifiers to be no different from ordinary single-signer transactions,
except perhaps for the inclusion of locktime refund logic.

Adaptor signatures, beyond the efficiency and privacy benefits of
encoding script semantics into constant-sized signatures, have
additional benefits over traditional hash-based payment channels.
Specifically, the secret values *`t`* may be reblinded between hops,
allowing long chains of transactions to be made atomic while even the
participants cannot identify which transactions are part of the chain.
Also, because the secret values are chosen at signing time, rather than
key generation time, existing outputs may be repurposed for different
applications without recourse to the blockchain, even multiple times.

## Blind Signatures

Schnorr signatures admit a very [simple **blind signature**
construction](https://publikationen.ub.uni-frankfurt.de/files/4292/schnorr.blind_sigs_attack.2001.pdf)
which is a signature that a signer produces at the behest of another
party without learning what he has signed. These can for example be used
in [Partially Blind Atomic
Swaps](https://github.com/jonasnick/scriptless-scripts/blob/blind-swaps/md/partially-blind-swap.md),
a construction to enable transferring of coins, mediated by an untrusted
escrow agent, without connecting the transactors in the public
blockchain transaction graph.

While the traditional Schnorr blind signatures are vulnerable to
[Wagner's
attack](https://www.iacr.org/archive/crypto2002/24420288/24420288.pdf),
there are [a number of
mitigations](https://web.archive.org/web/20211102002134/https://www.math.uni-frankfurt.de/~dmst/teaching/SS2012/Vorlesung/EBS5.pdf)
which allow them to be usable in practice without any known attacks.
Nevertheless, more analysis is required to be confident about the
security of the blind signature scheme.

Reference Code
--------------

1. C - [Mina c-reference-signer](https://github.com/MinaProtocol/c-reference-signer)
2. OCaml - [Ocaml signer-reference](https://github.com/MinaProtocol/signer-reference)

Implementations
---------------

1. Rust - [O(1) Labs proof-systems - mina-signer crate](https://github.com/o1-labs/proof-systems/tree/master/signer)
2. OCaml - [Mina Protocol - signature_lib module](https://github.com/MinaProtocol/mina/blob/develop/src/lib/signature_lib/schnorr.ml)
3. C - [Ledger hardware wallet - ledger-app-mina](https://github.com/jspada/ledger-app-mina)

Acknowledgements
----------------

This document was adapted by Izaak Meckler from Peter Wiulle's BIP.
The original acknowledgements are included below.

<references />

Footnotes
----------------

This document is the result of many discussions around Schnorr based
signatures over the years, and had input from Johnson Lau, Greg Maxwell,
Jonas Nick, Andrew Poelstra, Tim Ruffing, Rusty Russell, and Anthony
Towns.

[^1]: More precisely they are '' **strongly** unforgeable under chosen
    message attacks '' (SUF-CMA), which informally means that without
    knowledge of the secret key but given a valid signature of a
    message, it is not possible to come up with a second valid signature
    for the same message. A security proof in the random oracle model
    can be found for example in [a paper by Kiltz, Masny and
    Pan](https://eprint.iacr.org/2016/191), which essentially restates
    [the original security proof of Schnorr signatures by Pointcheval
    and
    Stern](https://www.di.ens.fr/~pointche/Documents/Papers/2000_joc.pdf)
    more explicitly. These proofs are for the Schnorr signature variant
    using *(e,s)* instead of *(R,s)* (see Design above). Since we use a
    unique encoding of *R*, there is an efficiently computable bijection
    that maps *(R, s)* to *(e, s)*, which allows to convert a successful
    SUF-CMA attacker for the *(e, s)* variant to a successful SUF-CMA
    attacker for the *(r, s)* variant (and vice-versa). Furthermore, the
    aforementioned proofs consider a variant of Schnorr signatures
    without key prefixing (see Design above), but it can be verified
    that the proofs are also correct for the variant with key prefixing.
    As a result, the aforementioned security proofs apply to the variant
    of Schnorr signatures proposed in this document.

[^2]: A limitation of committing to the public key (rather than to a
    short hash of it, or not at all) is that it removes the ability for
    public key recovery or verifying signatures against a short public
    key hash. These constructions are generally incompatible with batch
    verification.

[^3]: Since *p* is odd, negation modulo *p* will map even numbers to odd
    numbers and the other way around. This means that for a valid X
    coordinate, one of the corresponding Y coordinates will be even, and
    the other will be odd.

[^4]: A product of two numbers is a quadratic residue when either both
    or none of the factors are quadratic residues. As *-1* is not a
    quadratic residue, and the two Y coordinates corresponding to a
    given X coordinate are each other's negation, this means exactly one
    of the two must be a quadratic residue.

[^5]: This matches the *compressed* encoding for elliptic curve points
    used in Bitcoin already, following section 2.3.3 of the [SEC
    1](https://www.secg.org/sec1-v2.pdf) standard.

[^6]: Given an X coordinate *x(P)*, there exist either exactly two or
    exactly zero valid Y coordinates. The valid Y coordinates are the
    square roots of *c = (x(P))^3^ + 7 mod p* and they can be computed
    as *y = ±c^(p+1)/4^ mod p* (see [Quadratic
    residue](https://en.wikipedia.org/wiki/Quadratic_residue#Prime_or_prime_power_modulus))
    if they exist, which can be checked by squaring and comparing with
    *c*. Due to [Euler's
    criterion](https://en.wikipedia.org/wiki/Euler%27s_criterion) it
    then holds that *c^(p-1)/2^ = 1 mod p*. The same criterion applied
    to *y* results in *y^(p-1)/2^ mod p= ±c^(p+1)/4^(p-1)/2^^ mod p = ±1
    mod p*. Therefore *y = +c^(p+1)/4^ mod p* is a quadratic residue and
    *-y mod p* is not.

[^7]: For points *P* on the secp256k1 curve it holds that *jacobi(y(P))
    ≠ 0*.

[^8]: Note that in general, taking the output of a hash function modulo
    the curve order will produce an unacceptably biased result. However,
    for the secp256k1 curve, the order is sufficiently close to *2^256^*
    that this bias is not observable (*1 - n / 2^256^* is around *1.27
    \* 2^-128^*).
