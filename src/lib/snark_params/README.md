# Snark Parameters

This library contains parameters and utilities regarding the curves used in Mina
Protocol.

## Overview

The `snark_params` library provides the following functionalities:

- Finite field and curve parameter definitions for the SNARK system
- Group mapping operations for cryptographic operations
- Utility functions for working with SNARK constraints
- Support for nested SNARK composition using the "Tick" and "Tock" crypto systems

## Key Components

### Snark Parameters (`snark_params.ml`)

Contains the primary interface for working with SNARK parameters, including:

- `Tick` and `Tock` modules which define the two elliptic curve systems used in
  Mina
- Inner curve field elements and operations
- Group mapping functions

### Snark Utilities (`snark_util.ml`)

Provides utility functions for working with SNARK constraints:

- Bit packing and unpacking
- Boolean comparison operations
- Handling of decreasing bitstrings
- Utilities for calculating number of bits

## Testing

Tests for this module have been moved from inline tests to Alcotest. The tests
can be found in the `tests/` directory and can be run in several ways:

### Running Tests with Dune

From the repository root:

```bash
dune runtest src/lib/snark_params/tests
```

Or from within the `src` directory:

```bash
dune runtest lib/snark_params/tests
```

### Running Individual Tests

To run a specific test or test group:

```bash
dune exec src/lib/snark_params/tests/test_snark_params.exe -- test <test-name>
```

For example, to run only the group_map tests:

```bash
dune exec src/lib/snark_params/tests/test_snark_params.exe -- test group_map
```

### Interactive Testing in utop

You can also interactively test the library in utop:

```bash
dune utop src/lib/snark_params
```

Once in utop, you can load and test the library:

```ocaml
# #require "snark_params";;
# open Snark_params;;
# let field_element = Tick.Field.random ();;
# let (x, y) = Group_map.to_group field_element;;
```

This allows for interactive exploration of the library's functionality.

## Usage Examples

To use elliptic curve operations:

```ocaml
open Snark_params

(* Working with the Tick curve system *)
let field_element = Tick.Field.random ()
let curve_point = Tick.Inner_curve.random ()

(* Group map operations *)
let (x, y) = Group_map.to_group field_element
```

To use utility functions:

```ocaml
module Impl = Snark_params.Tick
module Util = Snark_params.Tick.Util

(* Calculate number of bits *)
let bits = Util.num_bits_int 42
```

For more advanced usage and integration with other Mina components, see the test
suite in the `tests/` directory.

## Printing Field Elements and Curve Points

### Printing Tick Field Elements

Tick field elements can be printed using serialization methods:

```ocaml
open Snark_params

(* Create a field element *)
let field_element = Tick.Field.random ()

(* Convert to string via JSON *)
let json_string = Tick.Field.to_yojson field_element |> Yojson.Safe.to_string

(* Convert to S-expression *)
let sexp_string = Tick.Field.sexp_of_t field_element |> Sexp.to_string
```

### Printing Curve Points

Inner curve points can be printed using S-expressions:

```ocaml
open Snark_params

(* Create a curve point *)
let curve_point = Tick.Inner_curve.random ()

(* Convert to S-expression *)
let sexp_string =
  Tick.Inner_curve.sexp_of_t curve_point |> Core_kernel.Sexp.to_string
```

These serialization methods are useful for debugging and logging purposes.
