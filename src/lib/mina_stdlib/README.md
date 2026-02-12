# Mina Standard Library

A collection of reusable utility modules and data structures that can be used
independently of the Mina blockchain protocol. This library provides
fundamental building blocks that are useful across various OCaml projects.
The library should be platform independent, i.e. it should not depend on UNIX
related packages and should be compilable into JavaScript.
It is recommended to move UNIX related modules into the UNIX version of Mina
standard library, `mina_stdlib_unix`.

## Overview

The Mina Standard Library (`mina_stdlib`) is designed to be a standalone OPAM
package with minimal dependencies, containing only standard OCaml libraries and
common utilities. It does not depend on any Mina-specific libraries, making it
suitable for reuse in other projects.

The library should also only depend on `Base` and `Core_kernel` as these
libraries are platform independent, `Core` being the UNIX dependent library.

## Building

```bash
dune build src/lib/mina_stdlib
```

## Testing

```bash
dune runtest src/lib/mina_stdlib
```
