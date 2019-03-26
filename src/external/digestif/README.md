Digestif - Hash algorithms in C and OCaml
=========================================

[![Build Status](https://travis-ci.org/mirage/digestif.svg?branch=master)](https://travis-ci.org/mirage/digestif)

Digestif is a toolbox which implements hashes:

 * SHA1
 * SHA224
 * SHA256
 * SHA384
 * SHA512
 * BLAKE2B
 * BLAKE2S
 * RIPEMD160

Digestif uses a trick about linking and let the end-user to choose which
implementation he wants to use. We provide 2 implementations:

 * C implementation with `digestif.c`
 * OCaml implementation with `digestif.ocaml`

Both are well-tested. However, OCaml implementation is slower than the C
implementation.

Home page: http://din.osau.re/

Contact: Romain Calascibetta `<romain.calascibet ta@gmail.com>`

## API

For each hash, we implement the same API which is referentially transparent.
Then, on the top of these, we reflect functions (like `digesti` or `hmaci`) with
GADT - however, conversion from GADT to hash type is not possible (but you can
destruct GADT to a `string`).

## Build Requirements

 * OCaml >= 4.03.0 (may be less but need test)
 * `base-bytes` meta-package
 * Bigarray module (provided by the standard library of OCaml)
 * `dime` to build the project

If you want to compile the test program, you need:

 * `alcotest`

## Credits

This work is from the [nocrypto](https://github.com/mirleft/nocrypto) library
and the Vincent hanquez's work in
[ocaml-sha](https://github.com/vincenthz/ocaml-sha).

All credits appear in the begin of files and this library is motivated by two reasons:

  * delete the dependancy with `nocrypto` if you don't use the encryption (and common) part
  * aggregate all hashes functions in one library
