# Standalone Snark Worker

This directory contains a standalone executable for running a Mina SNARK worker
outside of the main daemon process.

## Building

To build the standalone worker:

```bash
dune build src/lib/snark_worker/standalone/run_snark_worker.exe
```

## Running

Always use `dune exec` to run the binary:

```bash
dune exec src/lib/snark_worker/standalone/run_snark_worker.exe -- \
  --spec-json <JSON_STRING> [OPTIONS]
```

Note the `--` separator between the dune command and the arguments for the
executable.

A help option is always available using:
```
dune exec src/lib/snark_worker/standalone/run_snark_worker.exe -- --help
```

The documentation below might be outdated. If it is the case, update it
accordingly.

### Input Formats

The SNARK worker accepts work specifications in several formats (in order of
preference):

- `--spec-json "..."` - Direct JSON string containing the work specification
- `--spec-json-file "path/to/file.json"` - Path to a file containing the JSON
  work specification
- `--spec-sexp "..."` - Direct S-expression string containing the work
  specification

### Options

- `--proof-level <LEVEL>` - Set the proof level (Full, Check, or None, default:
  Full)
- `--snark-worker-fee <FEE>` - Fee to charge for generating a proof (in
  nanomina, default: 10)
- `--snark-worker-public-key <KEY>` - Public key to use for the worker (default:
  genesis winner key)
- `--graphql-uri <URI>` - GraphQL endpoint to submit proofs to after generation

### Examples

Generate a proof with default settings, reading the specification from a file:

```bash
dune exec src/lib/snark_worker/standalone/run_snark_worker.exe -- \
  --spec-json-file /path/to/spec.json
```

Generate a proof and submit it to a local Mina daemon:

```bash
dune exec src/lib/snark_worker/standalone/run_snark_worker.exe -- \
  --spec-json-file /path/to/spec.json \
  --graphql-uri http://localhost:3085/graphql
```

Use a specific key and fee:

```bash
dune exec src/lib/snark_worker/standalone/run_snark_worker.exe -- \
  --spec-json-file /path/to/spec.json \
  --snark-worker-fee 20 \
  --snark-worker-public-key B62qkaG5fMGRkcYKGgbyQmhZXJBUhhDfyWcHQQ7Qy7tqHKdUe1wmaK4
```

## Output

The worker will output the proof result to stdout. If successful and a GraphQL
endpoint is provided, it will submit the proof to the endpoint.

## Exit Codes

- `0` - Success
- `1` - Error (details will be printed to stdout)
