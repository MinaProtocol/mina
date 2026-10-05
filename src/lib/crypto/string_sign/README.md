# String Sign

A library for signing and verifying strings using Schnorr signatures in the Mina
protocol. This library simplifies the process of signing arbitrary strings and
verifying those signatures, with support for different network types.

## Overview

The library provides a simple interface for:

1. Converting strings to a format suitable for signing
2. Signing strings using Schnorr signatures
3. Verifying signatures for strings
4. Supporting different network types (mainnet, testnet, and other custom networks)

## Usage

The library is designed to be used with the Mina protocol's signature system.

### Interactive Usage with utop

You can explore the library interactively using OCaml's utop REPL with dune:

```bash
# From the project root
dune utop src/lib/string_sign

# Inside utop
utop# open String_sign;;
utop# open Signature_lib;;

# Create a keypair
utop# let keypair = Keypair.create ();;

# Sign a string
utop# let message = "Hello, Mina!";;
utop# let signature = sign keypair.private_key message;;

# Verify the signature
utop# verify signature keypair.public_key message;;
- : bool = true
```

### Library Usage

You can include string_sign in your project's dune file:

```lisp
(library
 (name my_project)
 (libraries
  string_sign
  signature_lib
  ; other dependencies
 )
 (preprocess
  (pps ppx_jane))
)
```

Then you can use the library in your code:

```ocaml
open String_sign
open Signature_lib

(* Create or load a keypair *)
let keypair = Keypair.create ()

(* Sign a message *)
let message = "This is a message to sign"
let signature = sign keypair.private_key message

(* Verify the signature *)
let is_valid = verify signature keypair.public_key message
```

### Network-specific Signing

The library supports different network types for signatures:

```ocaml
(* Sign with mainnet *)
let mainnet_signature =
  sign ~signature_kind:Mina_signature_kind.Mainnet
    keypair.private_key message

(* Sign with testnet *)
let testnet_signature =
  sign ~signature_kind:Mina_signature_kind.Testnet
    keypair.private_key message

(* Sign with a custom network *)
let custom_signature =
  sign ~signature_kind:(Mina_signature_kind.Other_network "MyNetwork")
    keypair.private_key message
```

Signatures are only valid for the network they were created for.

## Testing

Tests for this library have been implemented using Alcotest. The test suite includes:

1. Basic signing and verification tests:
   - Default network
   - Mainnet
   - Testnet
   - Custom networks
   - Legacy signature verification

2. Cross-network verification tests:
   - Ensuring that signatures from one network don't verify on other networks

To run the tests:

```bash
dune exec src/lib/string_sign/tests/test_string_sign.exe
```

Or run all tests:

```bash
dune runtest src/lib/string_sign/tests/
```
