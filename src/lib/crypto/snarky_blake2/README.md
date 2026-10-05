# Snarky Blake2

A SNARK-friendly implementation of the Blake2s hash function using Snarky, the
OCaml DSL for writing circuits for R1CS.

## Overview

This library provides an implementation of the Blake2s hash function that can be
used within circuits built with Snarky.

## Key Components

- `Snarky_blake2.Make`: A functor for creating a Blake2s implementation with any
  Snarky backend
- `blake2s`: The main implementation of the Blake2s hash function as a Snarky
  checked computation
- `digest_length_in_bits`: The fixed output length of Blake2s (256 bits)

## Implementation Details

The implementation follows the Blake2s specification while being optimized for
the constraint system environment:

- Uses `Uint32` for all arithmetic operations within the SNARK circuit
- Handles the compression function in a constraint-efficient manner
- Provides support for optional personalization parameters

## Testing

The library is tested using Alcotest, with tests focusing on:

1. **Constraint Count**: Ensuring the implementation stays within a reasonable
   constraint count (≤21278), which is crucial for performance in the Mina
   protocol.

2. **Correctness**: Verifying that the SNARK implementation produces the same
   hash outputs as a native Blake2s implementation across various inputs.

### Running Tests

To run the tests:

```bash
dune runtest lib/snarky_blake2/test
```

Or directly:

```bash
dune exec lib/snarky_blake2/test/test.exe
```
