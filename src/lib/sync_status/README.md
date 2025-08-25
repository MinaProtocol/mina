# Sync Status

A library for representing and managing the synchronization status of a Mina
protocol node. Sync status represents states while interacting with peers in the
network.

## Overview

The library provides a type that encodes the following synchronization states:

- `Connecting`: The node is starting up and attempting to connect to peers
- `Listening`: The node has connected to peers and is waiting for messages
- `Offline`: The node hasn't received messages in some time (see Mina_lib.offline_time)
- `Bootstrap`: The node is currently bootstrapping
- `Synced`: The node is receiving a constant flow of messages and is synchronized
- `Catchup`: The node is catching up with the rest of the network

The library includes functions for converting between the sync status type and
string/JSON representations, along with proper versioning support.

## Usage

### Interactive Usage with utop

You can explore the library interactively using OCaml's utop REPL with dune:

```bash
# From the project root
dune utop src/lib/sync_status

# Inside utop
utop# open Sync_status;;

# Convert a status to string
utop# to_string `Synced;;
- : string = "Synced"

# Parse a status from string
utop# of_string "offline";;
- : [ `Bootstrap | `Catchup | `Connecting | `Listening | `Offline | `Synced ] Core_kernel.Or_error.t =
Ok `Offline

# Convert a status to JSON
utop# to_yojson `Bootstrap;;
- : Yojson.Safe.t = `String "Bootstrap"

# Parse a status from JSON
utop# of_yojson (`String "Listening");;
- : ([ `Bootstrap | `Catchup | `Connecting | `Listening | `Offline | `Synced ], string) result =
Ok `Listening
```

### Library Usage

You can include sync_status in your project's dune file:

```lisp
(library
 (name my_project)
 (libraries
  sync_status
  ; other dependencies
 )
 (preprocess
  (pps ppx_jane))
)
```

Then you can use the library in your code:

```ocaml
open Core_kernel
open Sync_status

(* Get string representation *)
let status_str = to_string `Synced

(* Parse from string *)
let status =
  match of_string "offline" with
  | Ok status -> status
  | Error e ->
      failwithf "Failed to parse status: %s" (Error.to_string_hum e) ()

(* JSON conversion *)
let json_status = to_yojson `Bootstrap
let parsed_status =
  match of_yojson json_status with
  | Ok status -> status
  | Error msg -> failwith msg
```

## Versioning

This library is versioned using the `ppx_version` system, which ensures stable
serialization across different versions of the software. Currently, there is
only a V1 implementation.

## Testing

Tests for this library have been implemented using Alcotest. The test suite includes:

1. Conversion tests:
   - String round-trip conversion
   - JSON round-trip conversion
   - Individual string and JSON conversions for each status type

2. Error handling tests:
   - Proper error handling for invalid string input
   - Proper error handling for invalid JSON input

To run the tests:

```bash
dune exec src/lib/sync_status/tests/test_sync_status.exe
```

Or run all tests:

```bash
dune runtest src/lib/sync_status/tests/
```
