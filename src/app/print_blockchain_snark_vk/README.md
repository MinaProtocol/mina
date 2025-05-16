# Blockchain SNARK Verification Key Generator

The `print_blockchain_snark_vk` tool is a utility for generating and printing
the blockchain SNARK verification key in JSON format. This verification key is
essential for verifying blockchain state transitions in the Mina protocol.

## Features

- Generates the Transaction SNARK circuit
- Generates the Blockchain SNARK circuit
- Outputs the verification key in JSON format
- Provides timing information for circuit generation

## Prerequisites

- OCaml development environment
- Mina codebase
- OPAM package dependencies for Mina

## Compilation

To build the utility:

```
dune build src/app/print_blockchain_snark_vk/print_blockchain_snark_vk.exe
```

## Usage

Run the executable to generate and print the blockchain SNARK verification key:

```
_build/default/src/app/print_blockchain_snark_vk/print_blockchain_snark_vk.exe > blockchain_snark_vk.json
```

The tool will output the verification key to stdout, which can be redirected to a
file as shown above. During execution, it will print progress information to stderr.

## Technical Notes

The Blockchain SNARK verification key is a cryptographic key used to verify proofs
of state transitions in the Mina blockchain. This tool generates this key by:

1. Creating a Transaction SNARK circuit, which verifies the validity of individual
   transactions.
   
2. Building a Blockchain SNARK circuit, which uses the Transaction SNARK to
   verify the validity of entire blocks.
   
3. Extracting and serializing the verification key for the Blockchain SNARK
   circuit to JSON format.

The resulting verification key is a complex JSON structure containing elliptic
curve points and other cryptographic parameters that define the verification
algorithm for blockchain state transitions.

The repository includes a pre-generated verification key file
(`blockchain_snark_vk.json`) that can be used without running this tool. However,
if protocol parameters change, you may need to regenerate this key using this tool.

Note that generating the verification key is computationally intensive and may
take several minutes to complete, depending on your hardware. The tool will print
the generation time to stderr for reference.