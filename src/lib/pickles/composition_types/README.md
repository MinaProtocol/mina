# Pickles Composition Types

This library provides core data structures and types that are used in the
Pickles SNARK composition system. These types are essential for creating and
verifying recursive zero-knowledge proofs in the Mina protocol.

## Overview

The `composition_types` library defines fundamental data structures that
represent the various elements used in SNARK composition:

- Digests and challenge values
- Branch data for proof verification
- Bulletproof challenges
- Type specification system for SNARK circuit composition

These types act as the building blocks for the recursive SNARK system that
enables efficient verification of arbitrary computations on the Mina blockchain.

## Key Components

### Digest

The `Digest` module represents hash digests as vectors of 4 64-bit limbs (int64
values). It provides:

- Serialization to/from bits
- Conversion between Tick and Tock field representations
- Equality and comparison functions
- JSON and S-expression serialization

Digests are used throughout the system to represent hash outputs in a way that
can be efficiently manipulated both inside and outside of circuits.

Example:
```ocaml
(* Create a digest from limbs *)
let limbs = [0L; 1L; 2L; 3L]
let digest = Digest.Constant.A.of_list_exn limbs

(* Convert to bits representation *)
let bits = Digest.Constant.to_bits digest

(* Convert to field element *)
let field_element = Digest.Constant.to_tick_field digest
```

### Branch Data

The `Branch_data` module encodes information about the verification of proofs in
a recursive proof system. It contains:

- The number of proofs that have been verified
- Domain size information (as a logarithm)

This compact representation allows the proof system to track what has been
verified and what domain sizes were used, enabling the composition of multiple
proofs.

Example:
```ocaml
(* Create branch data *)
let domain_log2 = Branch_data.Domain_log2.of_int_exn 10  (* Domain size 2^10 *)
let proofs_verified = Pickles_base.Proofs_verified.N1    (* 1 proof verified *)
let branch_data = { Branch_data.proofs_verified; domain_log2 }

(* Extract domain information *)
let domain = Branch_data.domain branch_data
```

### Bulletproof Challenge

The `Bulletproof_challenge` module represents challenges used in the Bulletproof
protocol, which is a component of the Pickles proof system. It provides:

- A simple wrapper around challenge values
- Functions to pack/unpack challenges
- A mapping function for transformation
- Type representations for circuit integration

Example:
```ocaml
(* Pack and unpack operations *)
let challenge = some_challenge_value
let bulletproof_challenge = Bulletproof_challenge.unpack challenge
let original_challenge = Bulletproof_challenge.pack bulletproof_challenge

(* Map a challenge to a new form *)
let transformed = Bulletproof_challenge.map bulletproof_challenge ~f:(fun x -> transform x)
```

### Spec (Type Specification)

The `Spec` module provides a sophisticated type system for defining and
manipulating structured data in zero-knowledge circuits. It enables:

- Definition of basic and compound data types
- Automated conversion between in-circuit and out-of-circuit representations
- Support for complex data structures including vectors, arrays, and optional values

This type system is essential for handling the complex data structures used in
recursive proofs. Most of the types are defined using a GADT.
