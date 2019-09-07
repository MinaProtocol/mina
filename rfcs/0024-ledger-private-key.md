## Summary
[summary]: #summary

Ledger hardware wallets don't maintain any state/storage between use, and only give
limited access to the seed which is used to derive private keys. This means we
have to come up with a way to securely construct key pairs using private keys
corresponding to different cryptographic primitives as our building blocks.

## Motivation
[motivation]: #motivation

Why are we doing this? What use cases does it support? What is the expected
outcome?

We need to do this because private keys cannot be stored on the Ledger hardware wallet
(the Ledger hardware wallet doesn't retain any state except its seed), and the system 
calls created to derive private keys from the seed take a curve ID as a parameter, 
and our curve isn't included in the list of curves with curve IDs and implementations.

No state/no storage of private keys means that we cannot just generate random
bytes and use these to construct a private key, as then signing with the Ledger
device could only ever happen at the same time as key generation, making it
impossible to generate a key pair with which to receive a balance, and then
in the future spending that balance.

Limited interfacing with the seed means that we cannot just construct a keypair
that we can assume nice things about via system calls, as these take either
curves or other group objects as parameters, and our curve is not one of the
choices. So we need to construct one of our private keys using the tools available
to us, and make sure that this is secure.


## Detailed design
[detailed-design]: #detailed-design

Ledger uses:
- BIP 39 to generate and interpret the master seed, which produces the 24 words
  shown on the device at startup.
- BIP 32 for HD key derivation (using the child key derivation function)
- BIP 44 for HD account derivation (so e.g. btc and coda keys don't clash)

The normal flow for generating a keypair is then something like:

```
    unsigned int  bip32Path[5];
    unsigned char privateKeyData[32];

    // m/44'/49370'/0'/0/0
    bip32Path[0] = 0x8000002C;
    bip32Path[1] = 0x8000c0da;
    bip32Path[2] = 0x80000000;
    bip32Path[3] = 0x00000000;
    bip32Path[4] = 0x00000000;

    // curve, path, pathLength, privateKey, chain
    os_perso_derive_node_bip32(CX_CURVE_SECP256K1, bip32Path, 5, privateKeyData, NULL);
```

Then
```
cx_ecfp_public_key_t *publicKey;
cx_ecfp_private_key_t *privateKey;
// use bytes from above to get value of private key
cx_ecfp_init_private_key(CX_CURVE_256K1, privateKeyData, 32, privateKey);
// init public key
cx_ecfp_init_public_key(CX_CURVE_256K1, NULL, 0, publicKey);
// get value of public key -- 1 here means 'keepPrivate' as we already derived the
// private key
cx_ecfp_generate_pair(CX_CURVE_256K1, publicKey, privateKey, 1);
```

We need to construct functions that replace the normal use of
`cx_ecfp_init_public_key`, `cx_ecfp_init_private_key`
and `cx_ecfp_generate_pair` on the Ledger hardware wallet.

The opcodes that you can use on the ledger are listed here:
https://github.com/LedgerHQ/nanos-secure-sdk/blob/master/include/cx.h#L2063
and here:
https://github.com/LedgerHQ/nanos-secure-sdk/blob/master/include/os.h

Options include:
- doing the above, but instead of using `cx_ecfp_init_public_key` and
`cx_ecfp_generate_pair` as normal, we would take the privateKeyData bytes
(or the `init`ed private key) and somehow make it into a private key that is
suitable for our system. If we only need ~256 bits of randomness in order for
our keys to be secure, then we can just use, e.g., with `||` meaning concatenation:
```
sha256(privateKeyData || 0) || sha256(privateKeyData || 1) || sha256(privateKeyData || 2)
```
and then drop the 15 most significant bits (taking us from 768 to 753 bits),
and verify that the resulting number is below the group order.
- If we need ~753 bits of randomness, we would instead construct `privateKeyData0`,
`privateKeyData1` and `privateKeyData2`, then use `cx_ecfp_init_private_key` on
each of these, and then concatenate them, drop the 15 most significant bits,
checking if the resulting number is below the group order.

## Drawbacks [drawbacks]: #drawbacks
- This might lead to bias in the keys?

## Rationale and alternatives [rationale-and-alternatives]:
#rationale-and-alternatives
- All other option seem worse:
  - I'm not really sure about the flow of generating rsa key pairs, and
  as they can only be up to 512 bits, we would still have to deal with the
  above, while also considering the possible effects of the structure of RSA
  private keys (inverse of some `e`? coprime with `phi(N)`, how would we
  construct `N`, how would these things affect security wrt elliptic curves?
  - curve25519/friends have set bits and cofactor complications that we don't
    need to think about if we use secp256k1
- The impact of not doing this would be that we would not be able to sign
  meaningful transactions on a Ledger hardware wallet.

## Prior art
[prior-art]: #prior-art

It's quite easy to see that taking a number larger than the group order
modulo the group order and setting this to be the private key would lead to
biased private keys. For example, say the group order is `p = 7`, if you
generated a number `mod p + 3`, so `mod 10`, and then took
this number `mod 7` to be your private key, then `0`, `1`, and `2`, would be
twice as likely as `3`, `4`, `5`, `6` to be the private key (as `0 mod 10` and
`7 mod 10` -> `0 mod 7`, and similarly for `1` and `8`, and `2` and `9`).  This
extends similarly to differences other than `+ 3`, and so only multiples of
the group order are reasonable to use without introducing a bias in the private key.

## Unresolved questions
[unresolved-questions]: #unresolved-questions

Not sure. Can anyone think of anything more efficient? Should we have a proof 
that this isn't doing anything harmful?
