# ZkApp Test Transaction Tool - Developer Guide

The ZkApp Test Transaction tool is a utility for generating ZkApp transactions that can 
be sent to a Mina test network. It provides a way to create, update, and test
zero-knowledge smart contracts (ZkApps) without having to write SnarkyJS code directly.

## Features

- Generate ZkApp transaction GraphQL mutations ready to send to Mina nodes
- Deploy test smart contracts to ZkApp accounts
- Transfer funds between accounts using ZkApp transactions
- Update ZkApp state with different authorization methods
- Modify ZkApp account properties (verification key, URI, token symbol, permissions)
- Generate test genesis ledgers with pre-deployed verification keys
- Support for fee payer accounts separate from transaction signers

## Prerequisites

- OCaml development environment
- Mina codebase
- OPAM package dependencies for Mina
- A running Mina node for submitting generated transactions

## Compilation

To build the utility:

```
dune build src/app/zkapp_test_transaction/zkapp_test_transaction.exe
```

## Usage

The tool generates GraphQL `sendZkapp` mutations that can be sent to the GraphQL server 
that the Mina daemon starts by default at port 3085. You can use a GraphQL client or 
the GraphQL Playground at http://localhost:3085/graphql to submit these mutations.

```
zkapp_test_transaction SUBCOMMAND [ARGS]
```

### Available Subcommands:

- `create-zkapp-account`: Generate a transaction that creates a ZkApp account
- `upgrade-zkapp`: Update the verification key of a ZkApp
- `transfer-funds`: Make multiple transfers from one account
- `update-state`: Update ZkApp state with proof authorization
- `update-zkapp-uri`: Update the ZkApp URI
- `update-sequence-state`: Update ZkApp state sequentially
- `update-token-symbol`: Update token symbol
- `update-permissions`: Update the permissions of a ZkApp account
- `test-zkapp-with-genesis-ledger`: Generate a test genesis ledger with verification key

### Common Arguments:

- `--fee-payer-key KEYFILE`: Private key file for the fee payer
- `--fee FEE`: Amount willing to pay for transaction processing (default: 1 MINA)
- `--nonce NN`: Nonce of the fee payer account
- `--memo STRING`: Optional memo to include with the transaction
- `--debug`: Enable debug mode for generating transaction snarks

## Technical Notes

The tool provides a simplified interface for working with ZkApp transactions:

1. **Smart Contract Implementation**: The tool uses a test smart contract that accepts 
   any state update, designed specifically for testing and not for production use.

2. **GraphQL Integration**: All commands output GraphQL mutations that can be directly 
   copied and submitted to a Mina node's GraphQL endpoint.

3. **Genesis Ledger Creation**: For advanced testing, the tool can generate a complete 
   genesis ledger with pre-deployed verification keys, allowing developers to start a 
   test network with ZkApps already initialized.

4. **Multiple Authorization Methods**: The tool supports both signature-based and 
   proof-based authorization for account updates, demonstrating different ZkApp 
   authorization patterns.

5. **Transaction Structure**: The generated ZkApp transactions follow the structure 
   defined in the Mina protocol, consisting of a list of parties where each party 
   represents an update to an account. For example, a typical transaction includes:
   - A fee payer party that specifies who pays the transaction fees
   - Optional parties that perform specific account operations
   - Authorization information (signatures or proofs) for each party

For more information on ZkApps, checkout the official documentation at 
https://docs.minaprotocol.com/en/zkapps.