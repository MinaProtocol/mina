## Background

This library implements a SNARK worker. A SNARK worker is an abstraction of a running CPU thread, generating proofs as they poll works from the SNARK coordinator, and submitting the proofs back to coordinator so the coordinator could broadcast the resulting proofs to other Mina nodes, or include them in a block, etc. 

A SNARK coordinator, is a Mina node exposing an "server" endpoint accessible by SNARK workers, implemented all RPCs necessary. These endpoints are defined in function `setup_local_server` in `app/cli/src/init/mina_run.ml`.


## What is a work? 

The exact definition of a "work" differes before and after the Mesa HF. 

### Before Mesa HF

A SNARK work is one or two single work, where a single work is either requesting a proof for a command, or a proof that is a merge of 2 proofs. The snark worker should return one or two proofs corresponding to the single work.

### After Mesa HF

A SNARK work is anything that requires generating one proof, which is one of: a proof for a non-zkApp command, a proof for a zkApp segment, or a proof that merges 2 proofs. The snark worker should return one proof exactly.

With Mesa HF, we can utilize more parallelism on SNARK workers, hence the number of segments per zkApp command is less relevant for proof generation latency. 
