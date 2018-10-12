# ocaml-sodium

[Ctypes](https://github.com/ocamllabs/ocaml-ctypes) bindings to
[libsodium 1.0.9+](https://github.com/jedisct1/libsodium) which wraps
[NaCl](http://nacl.cr.yp.to/). GNU/Linux, FreeBSD, and OS X operating
systems are supported. OCaml 4.01.0 or later is required to build.

All original NaCl primitives are wrapped. `crypto_shorthash` is missing.

``` ocaml
open Sodium
let nonce = Box.random_nonce () in
let (sk, pk ) = Box.random_keypair () in
let (sk',pk') = Box.random_keypair () in
let c = Box.Bytes.box sk pk' "Hello, Spooky World!" nonce in
let m = Box.Bytes.box_open sk' pk c nonce in
print_endline (String.escaped c);
print_endline m
```

## Considerations

Originally described in [*The Security Impact of a New Cryptographic
Library*](http://cryptojedi.org/papers/coolnacl-20111201.pdf), NaCl is a
high-level, performant cryptography library exposing a straightforward
interface.

**This binding has not been thoroughly and independently audited so your
use case must be able to tolerate this uncertainty.**

Despite ocaml-sodium's thin interface on top of *libsodium*, it is still
important to be mindful of security invariants. In particular, you
should ensure that nonces used for cryptographic operations are
**never** repeated with the same key set.

## Tests

Internal consistency tests may be found in `lib_test`.

### Salt

*Salt is very important for the camel. It needs eight times as much salt
as do cattle and sheep. A camel needs 1 kg of salt a week and it is
advisable to leave salt with camels every week.*

-- [UN FAO Manual for Primary Animal Health Care Workers](http://www.fao.org/docrep/t0690e/t0690e09.htm#unit%2061:%20feeding%20and%20watering%20of%20camels)
