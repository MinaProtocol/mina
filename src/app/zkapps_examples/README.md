# ZkApps Examples

The ZkApps Examples utility provides a library of common patterns and building blocks
for creating zero-knowledge applications (ZkApps) on the Mina protocol. It includes
various classes and functions that simplify working with account updates, signatures,
and proof verification within ZkApp development.

## Features

- Helper classes for constructing and managing account updates in ZkApps
- Functions for handling account update authorization types (proofs and signatures)
- Support for managing state updates, calls between ZkApps, events, and actions
- Utilities for account deployment and verification key registration
- Functions for inserting signatures into ZkApp commands
- Support for setting balance changes and authorization requirements

## Prerequisites

- OCaml development environment
- Mina codebase
- OPAM package dependencies for Mina
- Understanding of the Mina ZkApp architecture

## Compilation

To build the utility:

```
dune build src/app/zkapps_examples/zkapps_examples.exe
```

## Usage

The ZkApps Examples library is not intended to be run directly as an executable but 
rather to be imported and used as a dependency in ZkApp development. The main components
include:

### Account Update Construction

The `account_update` class provides a convenient interface for building account updates
within zero-knowledge circuits:

```ocaml
let my_update = new account_update ~public_key ~vk_hash ()

(* Modify account state *)
my_update#set_state 0 field_value

(* Add events or actions *)
my_update#add_events [event_data]
my_update#add_actions [action_data]

(* Set balance changes *)
my_update#set_balance_change balance_change

(* Control authorization *)
my_update#assert_state_proved
```

### Account Deployment Helpers

The `Deploy_account_update` module provides functions for creating account updates
specifically for deploying smart contracts:

```ocaml
let deploy_update = Deploy_account_update.full 
  ~balance_change:(Currency.Amount.Signed.of_int 1_000_000_000)
  ~access:Permissions.Auth_required.Proof
  public_key
  Token_id.default
  verification_key
```

### Signature Management

The library includes functions for adding signatures to ZkApp commands:

```ocaml
let signed_command = insert_signatures 
  public_key_compressed
  private_key
  zkapp_command
```

## Technical Notes

The ZkApps Examples library implements several key concepts for ZkApp development:

1. **Account Update Construction**: The `Account_update_under_construction` module and
   `account_update` class provide a convenient interface for building complex account
   updates within circuits, including state changes, calls to other ZkApps, and event
   emission.

2. **Authorization Types**: The library supports both proof-based and signature-based
   authorization for account updates, with functions to specify and verify these
   authorization requirements.

3. **ZkApp State Management**: Functions for setting individual state fields or the
   entire state of an account at once, with validation of state modification permissions.

4. **Cross-Contract Calls**: Support for registering calls between ZkApps, including
   nested call forests with proper authorization.

5. **Proof Compilation**: Helper functions that simplify the process of compiling 
   zero-knowledge circuits into proofs that can be used in ZkApp transactions.

This library is particularly useful for ZkApp developers looking for patterns and 
examples to implement more complex zero-knowledge applications with advanced features
like cross-contract calls and multi-account interactions.