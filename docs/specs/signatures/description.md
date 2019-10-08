      Title: MNT6-753 Schnorr Signatures in Coda
      Author: Izaak Mecklker <izaak@o1labs.org>
      Status: Draft
      Type: Informational
      License: BSD-2-Clause

Introduction
------------

### Abstract

This document proposes a standard for Schnorr signatures over
the elliptic curve *MNT4-753*. It is adapted from a [BIP](https://github.com/sipa/bips/blob/bip-schnorr/bip-schnorr.mediawiki).

### Copyright

This document is licensed under the 2-clause BSD license.

Description
-----------

We first build up the algebraic formulation of the signature scheme by
going through the design choices. Afterwards, we specify the exact
encodings and operations.

### Design

**Schnorr signature variant** Elliptic Curve Schnorr signatures for
message *m* and public key *P* generally involve a point *R*, integers
*e* and *s* picked by the signer, and generator *G* which satisfy *e =
H(R || m)* and *sG = R + eP*. Two formulations exist, depending on
whether the signer reveals *e* or *R*:

1.  Signatures are *(e,s)* that satisfy *e = H(sG - eP || m)*. This
    avoids minor complexity introduced by the encoding of the point *R*
    in the signature (see paragraphs “Encoding the sign of R” and
    “Implicit Y coordinate” further below in this subsection).
2.  Signatures are *(R,s)* that satisfy *sG = R + H(R || m)P*. This
    supports batch verification, as there are no elliptic curve
    operations inside the hashes.

We choose the *R*-option to support batch verification.

**Key prefixing** When using the verification rule above directly, it is
possible for a third party to convert a signature *(R,s)* for key *P*
into a signature *(R,s + aH(R || m))* for key *P + aG* and the same
message, for any integer *a*. 
To combat this, we choose *key prefixed*[^2]
Schnorr signatures; changing the equation to *sG = R + H(R || P || m)P*.

**Encoding the sign of R** As we chose the *R*-option above, we're
required to encode the point *R* into the signature. Several
possibilities exist:

1.  Encoding the full X and Y coordinate of R, resulting in a 285-byte
    signature.
2.  Encoding the full X coordinate, but only whether Y is even or odd
    (like compressed public keys). This would result in 191-byte
    signatures.
3.  Encoding only the X coordinate, leaving us with 190-byte signature.

Using the first option would be slightly more efficient for verification
(around 5%), but we prioritize compactness, and therefore choose option
3.

**Implicit Y coordinate** In order to support batch verification, the Y
coordinate of *R* cannot be ambiguous (every valid X coordinate has two
possible Y coordinates). We have a choice between several options for
symmetry breaking:

1.  Implicitly choosing the Y coordinate that is in the lower half.
2.  Implicitly choosing the Y coordinate that is even[^3].

We choose option 2 as it is a bit simpler to implement.

**Final scheme** As a result, our final scheme ends up using signatures
*(r,s)* where *r* is the X coordinate of a point *R* on the curve whose
Y coordinate is even, and which satisfies *sG = R + H(r
|| P || m)P*.

### Specification

We first describe the verification algorithm, and then the signature
algorithm.

The following convention is used, with constants as defined for
MNT6-753:

-   Lowercase variables represent integers or byte arrays.
    -   The constant *p* refers to the field size,
        *0x1C4C62D92C41110229022EEE2CDADB7F997505B8FAFED5EB7E8F96C97D87307FDB925E8A0ED8D99D124D9A15AF79DB26C5C28C859A99B3EEBCA9429212636B9DFF97634993AA4D6C381BC3F0057974EA099170FA13A4FD90776E240000001*.
    -   The constant *n* refers to the curve order,
        *0x1C4C62D92C41110229022EEE2CDADB7F997505B8FAFED5EB7E8F96C97D87307FDB925E8A0ED8D99D124D9A15AF79DB117E776F218059DB80F0DA5CB537E38685ACCE9767254A4638810719AC425F0E39D54522CDD119F5E9063DE245E8001*.
    -   The constant *a* refers to one of the curve parameters which is *11* or
        *0xB*.
    -   The constant *b* refers to the other curve parameter
        *0x7DA285E70863C79D56446237CE2E1468D14AE9BB64B2BB01B10E60A5D5DFE0A25714B7985993F62F03B22A9A3C737A1A1E0FCF2C43D7BF847957C34CCA1E3585F9A80A95F401867C4E80F4747FDE5ABA7505BA6FCF2485540B13DFC8468A*.
-   Uppercase variables refer to points on the curve with equation *y^2 = x^3 + ax + b* over the integers modulo *p*.
    -   *infinite(P)* returns whether or not *P* is the point at
        infinity.
    -   *x(P)* and *y(P)* refer to the X and Y coordinates of a point
        *P* (assuming it is not infinity).
    -   The constant *G* refers to the generator, for which *x(G) =
        0xB0D6E141836D261DBE17959758B33A19987126CB808DFA411854CF0A44C0F4962ECA2A213FFEAA770DAD44F59F260AC64C9FCB46DA65CBC9EEBE1CE9B83F91A64B685106D5F1E4A05DDFAE9B2E1A567E0E74C1B7FF94CC3F361FB1F064AA*
        and *y(G) =
        0x30BD0DCB53B85BD013043029438966FFEC9438150AD06F59B4CC8DDA8BFF0FE5D3F4F63E46AC91576D1B4A15076774FEB51BA730F83FC9EB56E9BCC9233E031577A744C336E1EDFF5513BF5C9A4D234BCC4AD6D9F1B3FDF00E16446A8268*.
    -   Addition of points refers to the usual [elliptic curve group
        operation](https://en.wikipedia.org/wiki/Elliptic_curve#The_group_law).
    -   [Multiplication of an integer and a
        point](https://en.wikipedia.org/wiki/Elliptic_curve_point_multiplication)
        refers to the repeated application of the group operation.
-   Functions and operations:
    -   The word *tryte* refers to a sequence of three bits.
    -   *||* refers to array concatenation.
    -   The function *x\[i:j\]*, where *x* is an array, returns a length
        *(j - i)* array with a copy of the *i*-th element (inclusive)
        to the *j*-th element (exclusive) of *x*.
    -   The function *bits(x)* where *x* is an integer, returns the
        753-bit encoding of *x*, least significant bit first.
    -   The function *pad(bs)*, where *bs* is an array of bits,
        returns the tryte array obtained by padding *bs* with zeroes until
        its length is a multiple of 3 and then grouping the bits into
        trytes.
    -   The function *trytes(x)*, where *x* is an integer, returns
        *pad(bits(x))*.
    -   The function *bytes(x)*, where *x* is an integer, returns the
        95-byte encoding of *x*, least significant byte first.
    -   The function *bytes(P)*, where *P* is a point, returns
        *bytes(0x02 + (y(P) & 1)) || bytes(x(P))*[^5].
    -   The function *int(x)*, where *x* is a 95-byte array, returns the
        760-bit unsigned integer whose most significant byte encoding is
        *x*.
    -   The function *point(x)*, where *x* is a 96-byte array, returns
        the point *P* for which *x(P) = int(x\[1:96\])* and *y(P) & 1 =
        int(x\[0:1\]) - 0x02)*, or fails if no such point exists[^6].
    -   We fix public random curve points *P_0, P_1 ...*. These are
        generated by using a simple randomized algorithm for sampling
        curve run with the randomness
        *SHA256("CodaPedersenParams0"),  SHA256("CodaPedersenParams1"), ...*
    -   If *t* is a tryte *(b_0, b_1, b_2)* then
        *trint(t)* is the integer *(1 - 2 b_2)(1 + b_0 + 2 b_1)*.
    -   The function *pedersen(T)*, where *T* is an array of trytes of length
        *n*, returns the curve point *trint(T[0]) P_0 + ... + trint(T[n-1]) P_{n-1}*.
    -   The function *hash(T)*, where *T* is a tryte array, returns a
        the 32-byte value *blake2s(bytes(x(pedersen(T))))*.
    -   The function *jacobi(x)*, where *x* is an integer, returns the
        [Jacobi symbol](https://en.wikipedia.org/wiki/Jacobi_symbol) of
        *x / p*. It is equal to *x^(p-1)/2^ mod p* ([Euler's
        criterion](https://en.wikipedia.org/wiki/Euler%27s_criterion))[^7]

#### Verification

Input:

-   The public key *pk*: a 96-byte array
-   The message *m*: an arbitrary length tryte array
-   A signature *sig*: a 190-byte array

The signature is valid if and only if the algorithm below does not fail.

-   Let *P = point(pk)*; fail if *point(pk)* fails.
-   Let *r = int(sig\[0:95\])*; fail if *r ≥ p*.
-   Let *s = int(sig\[95:190\])*; fail if *s ≥ n*.
-   Let *e = int(hash(trytes(r) || trytes(P) || m)) mod n*.
-   Let *R = sG - eP*.
-   Fail if *infinite(R)* or *y(R)* is not even or *x(R) ≠ r*.

#### Signing

Input:

-   The secret key *d*: an integer in the range *1..n-1*.
-   The message *m*: an arbitrary length tryte array.

To sign *m* for public key *dG*:

-   Let *k' = int(blake2s(bytes(d) || m)) mod n*[^8].
-   Fail if *k' = 0*.
-   Let *R = k'G*.
-   Let ''k = k' '' if *y(R) is even*, otherwise let ''k = n - k'
    ''.
-   Let *e = int(hash(trytes(x(R)) || trytes(dG) || m)) mod n*.
-   The signature is *bytes(x(R)) || bytes(k + ed mod n)*.

**Above deterministic derivation of *R* is designed specifically for
this signing algorithm and may not be secure when used in other
signature schemes.** For example, using the same derivation in the MuSig
multi-signature scheme leaks the secret key (see the [MuSig
paper](https://eprint.iacr.org/2018/068) for details).

Note that this is not a *unique signature* scheme: while this algorithm
will always produce the same signature for a given message and public
key, *k* (and hence *R*) may be generated in other ways (such as by a
CSPRNG) producing a different, but still valid, signature.

### Optimizations

Many techniques are known for optimizing elliptic curve implementations.
Several of them apply here, but are out of scope for this document. Two
are listed below however, as they are relevant to the design decisions:

**Jacobi symbol** The function *jacobi(x)* is defined as above, but can
be computed more efficiently using an [extended GCD
algorithm](https://en.wikipedia.org/wiki/Jacobi_symbol#Calculating_the_Jacobi_symbol).

**Jacobian coordinates** Elliptic Curve operations can be implemented
more efficiently by using [Jacobian
coordinates](https://en.wikibooks.org/wiki/Cryptography/Prime_Curve/Jacobian_Coordinates).
Elliptic Curve operations implemented this way avoid many intermediate
modular inverses (which are computationally expensive), and the scheme
proposed in this document is in fact designed to not need any inversions
at all for verification. When operating on a point *P* with Jacobian
coordinates *(x,y,z)* which is not the point at infinity and for which
*x(P)* is defined as *x / z^2^* and *y(P)* is defined as *y / z^3^*:

-   *jacobi(y(P))* can be implemented as *jacobi(yz mod p)*.
-   *x(P) ≠ r* can be implemented as *x ≠ z^2^r mod p*.

Applications
------------

There are several interesting applications beyond simple signatures.
While recent academic papers claim that they are also possible with
ECDSA, consensus support for Schnorr signature verification would
significantly simplify the constructions.

### Multisignatures and Threshold Signatures

By means of an interactive scheme such as
[MuSig](https://eprint.iacr.org/2018/068), participants can produce a
combined public key which they can jointly sign for. This allows n-of-n
multisignatures which, from a verifier's perspective, are no different
from ordinary signatures, giving improved privacy and efficiency versus
*CHECKMULTISIG* or other means.

Further, by combining Schnorr signatures with [Pedersen Secret
Sharing](https://link.springer.com/content/pdf/10.1007/3-540-46766-1_9.pdf),
it is possible to obtain [an interactive threshold signature
scheme](http://cacr.uwaterloo.ca/techreports/2001/corr2001-13.ps) that
ensures that signatures can only be produced by arbitrary but
predetermined sets of signers. For example, k-of-n threshold signatures
can be realized this way. Furthermore, it is possible to replace the
combination of participant keys in this scheme with MuSig, though the
security of that combination still needs analysis.

### Adaptor Signatures

[Adaptor
signatures](https://download.wpsoftware.net/bitcoin/wizardry/mw-slides/2018-05-18-l2/slides.pdf)
can be produced by a signer by offsetting his public nonce with a known
point *T = tG*, but not offsetting his secret nonce. A correct signature
(or partial signature, as individual signers' contributions to a
multisignature are called) on the same message with same nonce will then
be equal to the adaptor signature offset by *t*, meaning that learning
*t* is equivalent to learning a correct signature. This can be used to
enable atomic swaps or even [general payment
channels](https://eprint.iacr.org/2018/472) in which the atomicity of
disjoint transactions is ensured using the signatures themselves, rather
than Bitcoin script support. The resulting transactions will appear to
verifiers to be no different from ordinary single-signer transactions,
except perhaps for the inclusion of locktime refund logic.

Adaptor signatures, beyond the efficiency and privacy benefits of
encoding script semantics into constant-sized signatures, have
additional benefits over traditional hash-based payment channels.
Specifically, the secret values *t* may be reblinded between hops,
allowing long chains of transactions to be made atomic while even the
participants cannot identify which transactions are part of the chain.
Also, because the secret values are chosen at signing time, rather than
key generation time, existing outputs may be repurposed for different
applications without recourse to the blockchain, even multiple times.

### Blind Signatures

Schnorr signatures admit a very [simple **blind signature**
construction](https://www.math.uni-frankfurt.de/~dmst/research/papers/schnorr.blind_sigs_attack.2001.pdf)
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
mitigations](https://www.math.uni-frankfurt.de/~dmst/teaching/SS2012/Vorlesung/EBS5.pdf)
which allow them to be usable in practice without any known attacks.
Nevertheless, more analysis is required to be confident about the
security of the blind signature scheme.

Reference Code
-------------------------------

For development and testing purposes, we provide a
naive but highly inefficient and non-constant time [pure Python 3.7
reference implementation of the signing and verification
algorithm](./reference.py). The reference
implementation is for demonstration purposes only and not to be used in
production environments.

Footnotes
---------

<references />
Acknowledgements
----------------

This document was adapted by Izaak Meckler from Peter Wiulle's BIP.
The original acknowledgements are included below.

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
    1](http://www.secg.org/sec1-v2.pdf) standard.

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
