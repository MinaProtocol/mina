# Snark Keys Header

This library provides functionality for working with SNARK key file headers in
the Mina Protocol.

## Overview

The `snark_keys_header` library defines a format for headers that precede SNARK
key data in files, allowing metadata about the key to be stored with the key
itself. This is useful for identifying different types of keys and their
associated parameters.

## Key Components

### Header Format

The header consists of:
- A fixed prefix string to identify the file type
- A JSON-encoded metadata structure containing:
  - Version information
  - Key type and identifier
  - Constraint constants used to generate the key
  - Length and hash information

### Core Types

- `Kind.t`: Identifies the type and purpose of the SNARK key
- `Constraint_constants.t`: Records the constraint system parameters
- `t`: The complete header structure

## Usage Examples

### Reading a SNARK Key File with Header

```ocaml
open Snark_keys_header

(* Define how to read the data portion of the file *)
let read_data ~offset filename =
  (* Custom data reading logic *)
  ...

(* Read both the header and data *)
let header, data =
  read_with_header ~read_data "path/to/key.snark"
  |> Or_error.ok_exn
```

### Writing a SNARK Key File with Header

```ocaml
open Snark_keys_header

(* Create a header *)
let header = {
  header_version = 1;
  kind = { type_ = "proving_key"; identifier = "transaction_snark" };
  constraint_constants = { ... };
  length = 0; (* Will be updated automatically *)
  constraint_system_hash = "...";
  identifying_hash = "...";
}

(* Define how to append the key data *)
let append_data filename =
  (* Custom data writing logic *)
  ...

(* Write the header and data *)
write_with_header
  ~expected_max_size_log2:20
  ~append_data
  header
  "path/to/key.snark"
```

## Testing

This library uses Alcotest for tests. The tests verify header parsing under
various conditions, including:

- Standard parsing from a string buffer
- Parsing from an offset within a buffer
- Parsing with buffer refill operations

### Running Tests

To run the tests:

```bash
dune runtest src/lib/snark_keys_header/tests
```

Or from the `src` directory:

```bash
dune runtest lib/snark_keys_header/tests
```

To run specific test groups:

```bash
dune exec src/lib/snark_keys_header/tests/test_snark_keys_header.exe -- \
  test "Standard parsing tests"
```
