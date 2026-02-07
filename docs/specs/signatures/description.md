      Title: Mina Schnorr Signatures
      Author: Izaak Mecklker <izaak@o1labs.org>
      Status: Draft
      Type: Informational
      License: BSD-2-Clause

## Updates

    - December 2021, Joseph Spadavecchia <joseph@o1labs.org>
      Updated to latest curves and signing algorithm

## Introduction

This document proposes a standard for Mina Schnorr signatures over the elliptic
curve [Pallas Pasta](https://o1-labs.github.io/proof-systems/specs/pasta.html).
It is adapted from a
[BIP 340](https://github.com/bitcoin/bips/blob/master/bip-0340.mediawiki).

## Copyright

This document is licensed under the 2-clause BSD license.

## Description

We first build up the algebraic formulation of the signature scheme by going
through the design choices. Afterwards, we specify the exact encodings and
operations.

## Design

**Schnorr signature variant** Elliptic Curve Schnorr signatures for message
_`m`_ and public key _`P`_ generally involve a point _`R`_, integers _`e`_ and
_`s`_ picked by the signer, and generator _`G`_ which satisfy _`e = H(R || m)`_
and _`sG = R + eP`_. Two formulations exist, depending on whether the signer
reveals _`e`_ or _`R`_:

1.  Signatures are _`(e,s)`_ that satisfy _`e = H(sG - eP || m)`_. This avoids
    minor complexity introduced by the encoding of the point _`R`_ in the
    signature (see paragraphs “Encoding the sign of R” and “Implicit Y
    coordinate” further below in this subsection).
2.  Signatures are _`(R,s)`_ that satisfy _`sG = R + H(R || m)P`_. This supports
    batch verification, as there are no elliptic curve operations inside the
    hashes.

We choose the _`R`_-option to support batch verification.

**Key prefixing** When using the verification rule above directly, it is
possible for a third party to convert a signature _`(R,s)`_ for key _`P`_ into a
signature _`(R,s + aH(R || m))`_ for key _`P + aG`_ and the same message, for
any integer _`a`_. To combat this, we choose _key prefixed_[^2] Schnorr
signatures; changing the equation to _`sG = R + H(m1 || P || R || m2 )`_ where
_`m1`_ is the field elements of the message _`m`_ and _`m2`_ is the rest of the
message.

**Encoding the sign of R** As we chose the _`R`_-option above, we're required to
encode the point _`R`_ into the signature. Several possibilities exist:

1.  Encoding the full X and Y coordinates of _`R`_, resulting in a 96-byte
    signature.
2.  Encoding the full X coordinate, but only whether Y is even or odd (like
    compressed public keys). This would result in a 65-byte signature.
3.  Encoding only the X coordinate, leaving us with 64-byte signature.

Using the first option would be slightly more efficient for verification (around
5%), but we prioritize compactness, and therefore choose option 3.

**Implicit Y coordinate** In order to support batch verification, the Y
coordinate of _`R`_ cannot be ambiguous (every valid X coordinate has two
possible Y coordinates). We have a choice between several options for symmetry
breaking:

1.  Implicitly choosing the Y coordinate that is in the lower half.
2.  Implicitly choosing the Y coordinate that is even[^3].

We choose option 2 as it is a bit simpler to implement.

**Final scheme** As a result, our final scheme ends up using signatures
_`(r,s)`_ where _`r`_ is the X coordinate of a point _`R`_ on the curve whose Y
coordinate is even, and which satisfies _`sG = R + H(r || P || m)P`_.

## Specification

We first describe the verification algorithm, and then the signature algorithm.

The following convention is used, with constants as defined for Mina's version
of [Pasta Pallas](https://o1-labs.github.io/proof-systems/specs/pasta.html):

- Lowercase variables represent integers or byte arrays.
  - The constant _`p`_ refers to the field size,
    `28948022309329048855892746252171976963363056481941560715954676764349967630337`
  - The constant _`n`_ refers to the curve order,
    `28948022309329048855892746252171976963363056481941647379679742748393362948097`
  - The constant `a` refers to the first curve parameter which is `0`
  - The constant `b` refers to the other curve parameter which is `5`
- Uppercase variables refer to points on the curve with equation
  _`y^2 = x^3 + ax + b`_ over the integers modulo _`p`_.
  - _`infinite(P)`_ returns whether or not _`P`_ is the point at infinity
  - _`x(P)`_ and _`y(P)`_ refer to the X and Y coordinates of a point _`P`_
    (assuming it is not infinity)
  - The constant _`G`_ refers to the generator, for which _`x(G) = 1`_ and
    _`y(G) = 12418654782883325593414442427049395787963493412651469444558597405572177144507`_
  - Addition of points refers to the usual
    [elliptic curve group operation](https://en.wikipedia.org/wiki/Elliptic_curve#The_group_law).
  - [Multiplication of an integer and a point](https://en.wikipedia.org/wiki/Elliptic_curve_point_multiplication)
    refers to the repeated application of the group operation
  - Base field and scalar field elements are represented in little-endian order
- Functions and operations:
  - `||` refers to either array concatenation or bit string concatenation
  - _`[s]G`_ refers to elliptic curve scalar multiplication of _`s`_ with
    generator _`G`_
  - _`blake2b`_ - [Blake2b](https://www.blake2.net/) cryptographic hash function
    with 32-byte output size
  - _`poseidon_3w`_ -
    [Poseidon cryptographic hash function for Mina](https://github.com/o1-labs/cryptography-rfcs/blob/master/mina/001-poseidon-sponge.md)
  - _`scalar(r)`_ refers to the scalar field element obtained from random bytes
    _`r`_ by dropping two MSB bits
  - _`s(σ)`_ refers to scalar field component of signature _`σ`_
  - _`b(σ)`_ refers to base field component of signature _`σ`_
  - _`x(P)`_ refers to x-coordinate of point _`P`_
  - _`y(P)`_ refers to y-coordinate of point _`P`_
  - _`odd(e)`_ - true if base field element _`e`_ is odd, false otherwise
  - _`negate(s)`_ - negation of scalar field element _`s`_
  - _`fields(m)`_ - vector containing components of message _`m`_ that are base
    field elements
  - _`bits(m)`_ - all other parts of message _`m`_ that are not in _`fields(m)`_
  - _`pack(byte)`_ - convert _`byte`_ into 8 bits little-endian order
  - _`pack(e)`_ - convert base field element _`e`_ into 255 bits little-endian
    order
  - _`pack(E)`_ - convert vector of base field elements _`E = [e1, ..., en]`_
    into bit string _`pack(e1) || ... || pack(en)`_
  - _`pack(s)`_ - convert scalar field element _`s`_ into 255 bits little-endian
    order
  - _`unpack(bits)`_ - convert bit string _bits =
    b<sub>1</sub>b<sub>2</sub>...b<sub>255</sub>b<sub>256</sub>...b<sub>510</sub>..._
    into vector of base field elements _`[e1, e2, ..., en]`_ where _e1 =
    b<sub>1</sub>...b<sub>255</sub>0_, _e2 = b<sub>256</sub>...b<sub>510</sub>0_
    and so on, such that the last element is zero-padded to 255 bits if
    necessary.
  - _`iv(id) `_ - unique `poseidon_3w` initialization vector for blockchain
    instance identified with `id`:
    - Testnet (_`id = 0x00`_)
      ```rust
      [
          28132119227444686413214523693400847740858213284875453355294308721084881982354,
          24895072146662946646133617369498198544578131474807621989761680811592073367193,
          3216013753133880902260672769141972972810073620591719805178695684388949134646
      ]
      ```
    - Mainnet (_`id = 0x01`_)
      ```rust
      [
          25220214331362653986409717908235786107802222826119905443072293294098933388948,
          7563646774167489166725044360539949525624365058064455335567047240620397351731,
          171774671134240704318655896509797243441784148630375331692878460323037832932,
      ]
      ```

There following helper functions are required.

### **Nonce derivation**

- Input:
  - Secret key _`d`_: an integer in the range _`1..n-1`_
  - Public key _`P`_: a curve point
  - Message _`m`_: message to be signed
  - Network id _`id`_: blockchain instance identifier
- Definition: _`derive_nonce(d, P, m, id) = `_
  - Let
    _`bytes = pack(fields(m)) || pack(x(P)) || pack(y(P)) || pack(d) || pack(id)`_
  - Let _`digest = blake2b(bytes)`_
- Output: _`scalar(digest)`_

### **Message hash**

- Input:
  - Public key _`P`_: a curve point
  - Base field element _`rx`_: X coordinate of nonce point
  - Message _`m`_: message to be signed
  - Network id _`id`_: blockchain instance identifier
- Definition: _`message_hash(P, rx, m, id) = `_
  - Let _`fields = fields(m) || x(P) || y(P) || xr || unpack(bits(m))`_
  - Let _`b = poseidon_3w(iv(id), fields)`_
- Output: _`scalar(b)`_

The signing and verification algorithms are as follows.

### **Signature verification**

- Input:
  - Public key _`P`_: a curve point
  - Message _`m`_: message
  - Signature _`σ`_: signature on _`m`_
  - Network id _`id`_: blockchain instance identifier
- The signature is valid if and only if the algorithm below does not fail.
  - Let _`e = message_hash(P, b(σ), m, id)`_
  - Let _`R = [s(σ)]G - [e]P`_
  - Fail if _`infinite(R) OR odd(y(R)) OR x(R) != b(σ)`_

### **Signature generation**

- Input:
  - Secret key _`d`_: an integer in the range _`1..n-1`_
  - Public key _`P`_: a curve point
  - Message _`m`_: message to be signed
  - Network id _`id`_: blockchain instance identifier
- To sign _`m`_ for public key _`P = dG`_:
  - Let _`k = derive_nonce(d, P, m, id)`_
  - Let _`R = [k]G`_
  - If _`odd(y(R))` then `negate(k)`_
  - Let _`e = message_hash(P, x(R), m, id)`_
  - Let *`s = k + e*d`\*
- The signature _`σ = (x(R), s)`_

**Above deterministic derivation of _`R`_ is designed specifically for this
signing algorithm and may not be secure when used in other signature schemes.**
For example, using the same derivation in the MuSig multi-signature scheme leaks
the secret key (see the [MuSig paper](https://eprint.iacr.org/2018/068) for
details).

Note that this is not a _unique signature_ scheme: while this algorithm will
always produce the same signature for a given message and public key, _`k`_ (and
hence _`R`_) may be generated in other ways (such as by a CSPRNG) producing a
different, but still valid, signature.

## Optimizations

Many techniques are known for optimizing elliptic curve implementations. Several
of them apply here, but are out of scope for this document. Two are listed below
however, as they are relevant to the design decisions:

**Jacobi symbol** The function _`jacobi(x)`_ is defined as above, but can be
computed more efficiently using an
[extended GCD algorithm](https://en.wikipedia.org/wiki/Jacobi_symbol#Calculating_the_Jacobi_symbol).

**Jacobian coordinates** Elliptic Curve operations can be implemented more
efficiently by using
[Jacobian coordinates](https://en.wikibooks.org/wiki/Cryptography/Prime_Curve/Jacobian_Coordinates).
Elliptic Curve operations implemented this way avoid many intermediate modular
inverses (which are computationally expensive), and the scheme proposed in this
document is in fact designed to not need any inversions at all for verification.
When operating on a point _`P`_ with Jacobian coordinates _`(x,y,z)`_ which is
not the point at infinity and for which _`x(P)`_ is defined as _`x / z^2`_ and
_`y(P)`_ is defined as _`y / z^3`_:

- _`jacobi(y(P))`_ can be implemented as _`jacobi(yz mod p)`_.
- _`x(P) ≠ r`_ can be implemented as _`x ≠ z^2^r mod p`_.

## Applications

There are several interesting applications beyond simple signatures. While
recent academic papers claim that they are also possible with ECDSA, consensus
support for Schnorr signature verification would significantly simplify the
constructions.

## Multisignatures and Threshold Signatures

By means of an interactive scheme such as
[MuSig](https://eprint.iacr.org/2018/068), participants can produce a combined
public key which they can jointly sign for. This allows n-of-n multisignatures
which, from a verifier's perspective, are no different from ordinary signatures,
giving improved privacy and efficiency versus _CHECKMULTISIG_ or other means.

Further, by combining Schnorr signatures with
[Pedersen Secret Sharing](https://link.springer.com/content/pdf/10.1007/3-540-46766-1_9.pdf),
it is possible to obtain
[an interactive threshold signature scheme](https://cacr.uwaterloo.ca/techreports/2001/corr2001-13.ps)
that ensures that signatures can only be produced by arbitrary but predetermined
sets of signers. For example, k-of-n threshold signatures can be realized this
way. Furthermore, it is possible to replace the combination of participant keys
in this scheme with MuSig, though the security of that combination still needs
analysis.

## Adaptor Signatures

[Adaptor signatures](https://web.archive.org/web/20211123033324/https://download.wpsoftware.net/bitcoin/wizardry/mw-slides/2018-05-18-l2/slides.pdf)
can be produced by a signer by offsetting his public nonce with a known point
_`T = tG`_, but not offsetting his secret nonce. A correct signature (or partial
signature, as individual signers' contributions to a multisignature are called)
on the same message with same nonce will then be equal to the adaptor signature
offset by _`t`_, meaning that learning _`t`_ is equivalent to learning a correct
signature. This can be used to enable atomic swaps or even
[general payment channels](https://eprint.iacr.org/2018/472) in which the
atomicity of disjoint transactions is ensured using the signatures themselves,
rather than Bitcoin script support. The resulting transactions will appear to
verifiers to be no different from ordinary single-signer transactions, except
perhaps for the inclusion of locktime refund logic.

Adaptor signatures, beyond the efficiency and privacy benefits of encoding
script semantics into constant-sized signatures, have additional benefits over
traditional hash-based payment channels. Specifically, the secret values _`t`_
may be reblinded between hops, allowing long chains of transactions to be made
atomic while even the participants cannot identify which transactions are part
of the chain. Also, because the secret values are chosen at signing time, rather
than key generation time, existing outputs may be repurposed for different
applications without recourse to the blockchain, even multiple times.

## Blind Signatures

Schnorr signatures admit a very
[simple **blind signature** construction](https://publikationen.ub.uni-frankfurt.de/files/4292/schnorr.blind_sigs_attack.2001.pdf)
which is a signature that a signer produces at the behest of another party
without learning what he has signed. These can for example be used in
[Partially Blind Atomic Swaps](https://github.com/jonasnick/scriptless-scripts/blob/blind-swaps/md/partially-blind-swap.md),
a construction to enable transferring of coins, mediated by an untrusted escrow
agent, without connecting the transactors in the public blockchain transaction
graph.

While the traditional Schnorr blind signatures are vulnerable to
[Wagner's attack](https://www.iacr.org/archive/crypto2002/24420288/24420288.pdf),
there are
[a number of mitigations](https://web.archive.org/web/20211102002134/https://www.math.uni-frankfurt.de/~dmst/teaching/SS2012/Vorlesung/EBS5.pdf)
which allow them to be usable in practice without any known attacks.
Nevertheless, more analysis is required to be confident about the security of
the blind signature scheme.

## Reference Code

1. C -
   [Mina c-reference-signer](https://github.com/MinaProtocol/c-reference-signer)
2. OCaml -
   [Ocaml signer-reference](https://github.com/MinaProtocol/signer-reference)

## Implementations

1. Rust -
   [O(1) Labs proof-systems - mina-signer crate](https://github.com/o1-labs/proof-systems/tree/master/signer)
2. OCaml -
   [Mina Protocol - signature_lib module](https://github.com/MinaProtocol/mina/blob/develop/src/lib/signature_lib/schnorr.ml)
3. C -
   [Ledger hardware wallet - ledger-app-mina](https://github.com/jspada/ledger-app-mina)

## Acknowledgements

This document was adapted by Izaak Meckler from Peter Wiulle's BIP. The original
acknowledgements are included below.

<references />

## Footnotes

This document is the result of many discussions around Schnorr based signatures
over the years, and had input from Johnson Lau, Greg Maxwell, Jonas Nick, Andrew
Poelstra, Tim Ruffing, Rusty Russell, and Anthony Towns.

[^1]:
    More precisely they are '' **strongly** unforgeable under chosen message
    attacks '' (SUF-CMA), which informally means that without knowledge of the
    secret key but given a valid signature of a message, it is not possible to
    come up with a second valid signature for the same message. A security proof
    in the random oracle model can be found for example in
    [a paper by Kiltz, Masny and Pan](https://eprint.iacr.org/2016/191), which
    essentially restates
    [the original security proof of Schnorr signatures by Pointcheval and Stern](https://www.di.ens.fr/~pointche/Documents/Papers/2000_joc.pdf)
    more explicitly. These proofs are for the Schnorr signature variant using
    _(e,s)_ instead of _(R,s)_ (see Design above). Since we use a unique
    encoding of _R_, there is an efficiently computable bijection that maps _(R,
    s)_ to _(e, s)_, which allows to convert a successful SUF-CMA attacker for
    the _(e, s)_ variant to a successful SUF-CMA attacker for the _(r, s)_
    variant (and vice-versa). Furthermore, the aforementioned proofs consider a
    variant of Schnorr signatures without key prefixing (see Design above), but
    it can be verified that the proofs are also correct for the variant with key
    prefixing. As a result, the aforementioned security proofs apply to the
    variant of Schnorr signatures proposed in this document.

[^2]:
    A limitation of committing to the public key (rather than to a short hash of
    it, or not at all) is that it removes the ability for public key recovery or
    verifying signatures against a short public key hash. These constructions
    are generally incompatible with batch verification.

[^3]:
    Since _p_ is odd, negation modulo _p_ will map even numbers to odd numbers
    and the other way around. This means that for a valid X coordinate, one of
    the corresponding Y coordinates will be even, and the other will be odd.

[^4]:
    A product of two numbers is a quadratic residue when either both or none of
    the factors are quadratic residues. As _-1_ is not a quadratic residue, and
    the two Y coordinates corresponding to a given X coordinate are each other's
    negation, this means exactly one of the two must be a quadratic residue.

[^5]:
    This matches the _compressed_ encoding for elliptic curve points used in
    Bitcoin already, following section 2.3.3 of the
    [SEC 1](https://www.secg.org/sec1-v2.pdf) standard.

[^6]:
    Given an X coordinate _x(P)_, there exist either exactly two or exactly zero
    valid Y coordinates. The valid Y coordinates are the square roots of _c =
    (x(P))^3^ + 7 mod p_ and they can be computed as _y = ±c^(p+1)/4^ mod p_
    (see
    [Quadratic residue](https://en.wikipedia.org/wiki/Quadratic_residue#Prime_or_prime_power_modulus))
    if they exist, which can be checked by squaring and comparing with _c_. Due
    to [Euler's criterion](https://en.wikipedia.org/wiki/Euler%27s_criterion) it
    then holds that _c^(p-1)/2^ = 1 mod p_. The same criterion applied to _y_
    results in _y^(p-1)/2^ mod p= ±c^(p+1)/4^(p-1)/2^^ mod p = ±1 mod p_.
    Therefore _y = +c^(p+1)/4^ mod p_ is a quadratic residue and _-y mod p_ is
    not.

[^7]: For points _P_ on the secp256k1 curve it holds that _jacobi(y(P)) ≠ 0_.

[^8]:
    Note that in general, taking the output of a hash function modulo the curve
    order will produce an unacceptably biased result. However, for the secp256k1
    curve, the order is sufficiently close to _2^256^_ that this bias is not
    observable (_1 - n / 2^256^_ is around _1.27 \* 2^-128^_).
