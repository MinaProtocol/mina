# Snark Worker

## Background

This library implements a SNARK worker. A SNARK worker is an abstraction of a running process, generating proofs as it polls work from the SNARK coordinator, and submitting the proofs back to the coordinator so the coordinator can broadcast the resulting proofs to other Mina nodes, or include them in a block, etc.

A SNARK coordinator is a Mina node exposing a "server" endpoint accessible by SNARK workers, implementing all RPCs necessary. These endpoints are defined in function `setup_local_server` in `src/app/cli/src/init/mina_run.ml`. The RPCs include requesting work specs, submitting completed proofs, and reporting failures via `failed_to_generate_snark`.

## What is a work?

The exact definition of a "work" differs before and after the Mesa HF.

### Before Mesa HF

A SNARK work is one or two single works, where a single work is either requesting a proof for a transaction (command, fee transfer, or coinbase), or a proof that is a merge of 2 proofs. The snark worker should return one or two proofs corresponding to the single work.

### After Mesa HF

A SNARK work is anything that requires generating one proof, which is one of: a proof for a non-zkApp command, a proof for a zkApp segment, or a proof that merges 2 proofs. The snark worker should return one proof exactly.

With Mesa HF, we can utilize more parallelism on SNARK workers, hence the number of segments per zkApp command is less relevant for proof generation latency.
