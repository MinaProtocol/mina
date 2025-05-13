# Kimchi Checks Scalar Generator

This tool generates OCaml code for the verifier of Kimchi. It's an
essential component of the Pickles proving system.

## Overview

The `gen_scalars` executable produces the `scalars.ml` file in the parent
directory, which contains field-specific implementations of the PLONK
verification constraints. These constraints are essential for verifying
zero-knowledge proofs within the Mina blockchain protocol.

## Purpose

This generator serves several critical purposes:

1. **Performance Optimization**: By generating specialized code for both Tick
   and Tock fields, the constraint evaluation can be highly optimized.

2. **Maintainability**: Instead of hand-coding the complex polynomial
   expressions for PLONK constraints, this generator provides a way to generate
   them from a canonical source.

3. **Consistency**: Ensures that the Tick and Tock field implementations use
   identical constraint logic with only field-specific optimizations.

## How It Works

The generator:

1. Uses OCaml's foreign function interface (FFI) to access Rust-based bindings
   that provide the actual constraint polynomial expressions
2. Formats these expressions as OCaml code
3. Generates two modules (`Tick` and `Tock`) with field-specific implementations
4. Produces a consistent representation of the constraints for both field types

## File Generation Process

When executed, `gen_scalars` creates `scalars.ml` containing:

- Type definitions for gate types and column references
- An environment (`Env.t`) for evaluating expressions
- The `Tick` module with PLONK constraints for the Pasta Fp field
- The `Tock` module with PLONK constraints for the Pasta Fq field

Each module provides:
- `constant_term`: Constant polynomial term in the linearization
- `index_terms`: Table of column-indexed polynomial terms

## Usage

The generator is typically invoked through the build system:

```bash
dune build src/lib/pickles/kimchi_checks/gen_scalars/gen_scalars.exe
dune exec src/lib/pickles/kimchi_checks/gen_scalars/gen_scalars.exe -- path/to/output.ml
```

However, most users will never need to run this directly, as the build system
handles it through a dune rule:

```lisp
(rule
 (target scalars.ml)
 (mode promote)
 (deps (:< gen_scalars/gen_scalars.exe))
 (action
  (progn
   (run %{<} %{target})
   (run ocamlformat -i scalars.ml))))
```

## Dependencies

The generator relies on:
- `kimchi_bindings`: Provides access to the Rust implementations of PLONK
  constraint systems
- `pasta_bindings`: For the specific field arithmetic used in the Mina protocol
- `kimchi_types`: For the constraint system type definitions

## Development

When modifying the PLONK constraint system:

1. Update the Rust bindings in `kimchi_bindings` to reflect any changes to the
   constraints
2. The generated `scalars.ml` will be automatically updated during the next
   build
3. Use `git diff` to review the generated changes before committing

## Technical Details

The generated code implements what's known as a "linearization" of the PLONK
constraints. This is a representation of the verification equations as a linear
combination of polynomials, structured in a way that enables efficient
evaluation during proof verification.

The linearization is divided into a constant term and a series of indexed terms
that multiply with specific columns from the constraint system.
