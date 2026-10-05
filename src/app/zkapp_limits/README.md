# ZkApp Limits Tool

The ZkApp Limits tool is a utility for examining and understanding the transaction 
cost limits and constraints for ZkApp (zero-knowledge applications) transactions in 
the Mina protocol. It helps developers understand the maximum number of operations 
and types of account updates that can be included in a valid transaction.

## Features

- Displays maximum field elements allowed for events per transaction
- Displays maximum field elements allowed for actions per transaction
- Calculates and displays all possible valid combinations of account updates
- Shows cost calculations for different transaction configurations

## Prerequisites

- OCaml development environment
- Mina codebase
- OPAM package dependencies for Mina

## Compilation

To build the utility:

```
dune build src/app/zkapp_limits/zkapp_limits.exe
```

## Usage

Run the executable to see the ZkApp transaction limits and valid update combinations:

```
_build/default/src/app/zkapp_limits/zkapp_limits.exe
```

The tool requires no command-line arguments and will output:

1. Maximum field elements for events per transaction
2. Maximum field elements for actions per transaction
3. A list of all valid combinations of account updates, showing:
   - Number of proof-authorized updates
   - Number of signature-authorized updates
   - Number of pairs of signature-authorized updates
   - Total account updates
   - Transaction cost

## Example Output

```
max field elements for events per transaction: 100
max field elements for actions per transaction: 100
All possible zkApp account update combinations:
Proofs updates=0  Signed/None updates=0  Pairs of Signed/None updates=0: Total account updates: 0 Cost: 0.000000 
Proofs updates=0  Signed/None updates=0  Pairs of Signed/None updates=1: Total account updates: 2 Cost: 2.000000 
Proofs updates=0  Signed/None updates=0  Pairs of Signed/None updates=2: Total account updates: 4 Cost: 4.000000 
...
Proofs updates=1  Signed/None updates=2  Pairs of Signed/None updates=1: Total account updates: 5 Cost: 7.000000 
...
```

## Technical Notes

The ZkApp Limits tool uses the Mina protocol's built-in cost calculation functions 
to determine valid transaction configurations. The tool considers three types of 
account updates:

1. **Proof-authorized updates**: Updates that require a zero-knowledge proof
2. **Signature-authorized updates**: Updates that require a signature
3. **Pairs of signature-authorized updates**: Two linked signature-authorized updates

Each type of update has a different cost impact on the transaction, and the total 
cost must stay below the protocol's transaction cost limit.

The cost calculation is based on the genesis constants defined in the Mina protocol, 
ensuring that the tool's output matches the actual constraints imposed by the 
network.

This tool is particularly useful for ZkApp developers who need to understand the 
transaction composition limits when designing complex multi-account interactions.