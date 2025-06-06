# SNARK Work Debugger

The SNARK Work Debugger is a diagnostic tool for testing and debugging SNARK work
processing in the Mina protocol. It allows developers to run the SNARK worker on
a single work specification file, facilitating isolated testing and performance
analysis.

## Features

- Loads and executes a single SNARK work specification
- Uses the same worker code as the full Mina implementation
- Creates a controlled environment for debugging SNARK issues
- Helpful for diagnosing SNARK worker failures or performance problems

## Prerequisites

- OCaml development environment
- Mina codebase
- OPAM package dependencies for Mina
- A valid SNARK work specification file (typically extracted from a running node)

## Compilation

To build the utility:

```
dune build src/app/snark_work_debugger/snark_work_debugger.exe
```

## Usage

Run the executable with a path to a SNARK work specification file:

```
_build/default/src/app/snark_work_debugger/snark_work_debugger.exe --spec PATH_TO_SPEC_FILE
```

### Arguments:

- `--spec`: Path to a file containing a SNARK work specification in S-expression format

## Technical Notes

The SNARK Work Debugger operates by:

1. Loading a single SNARK work specification from a file containing an S-expression
2. Initializing the SNARK worker environment with the compiled constraint constants
3. Creating a dummy Sok message with a zero fee and a random prover key
4. Executing the SNARK worker's `perform_single` function on the specification

The work specification should be in the format of a 
`Snark_work_lib.Work.Single.Spec` S-expression, which typically contains:

- Transaction witness data
- Statement to be proven
- Previous work to build upon (if applicable)

This tool is particularly useful for:

- Isolating and debugging issues with specific SNARK proofs
- Testing changes to the SNARK worker implementation
- Performance profiling of SNARK proving operations
- Verifying correctness of SNARK work in a controlled environment

To capture a SNARK work specification from a running node, you can modify the
node to dump the specs to disk, or extract them from logs if detailed logging
is enabled for SNARK operations.