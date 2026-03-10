# Snarky Taylor

This library implements Taylor series approximations of functions for use in
zkSNARKs. It provides facilities for approximating functions like
exponentiation with arbitrary-precision fixed-point arithmetics.

## Overview

The library consists of two main components:

1. `Floating_point` - A module for representing and manipulating arbitrary
   precision rationals in the interval [0, 1).

2. `Exp` - A module for computing the function x → base^x where x is in the
   interval [0, 1).

## Usage

The library is designed to be used with the Snarky framework for constructing
zkSNARKs. It provides both checked (for use within SNARK circuits) and
unchecked (for regular computation) implementations of functions.

## Testing

The test suite includes:

1. `floating_point_test.ml` - Tests for the Floating_point module, including:
   - Testing of_quotient operation with various fractions

2. `snarky_taylor_test.ml` - Tests for the Snarky_taylor module, including:
   - Testing the instantiation of exponentiation functions

To run the tests:

```
dune exec src/lib/snarky_taylor/tests/floating_point_test.exe
dune exec src/lib/snarky_taylor/tests/snarky_taylor_test.exe
```

Or run all tests:

```
dune runtest src/lib/snarky_taylor/tests/
```
