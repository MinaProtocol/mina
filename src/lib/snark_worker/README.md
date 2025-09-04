## Background

This is library implements a SNARK worker. A SNARK worker is an abstraction of a running CPU thread, generating proofs as they poll works from the SNARK coordinator, and submitting the proofs back to coordinator so the coordinator could broadcast them proofs to other daemons, or include them in a block, etc. 

While there's a clear abstraction for a SNARK worker, there isn't one for a SNARK coordinator. Instead, we have a daemon, which can act as a coordinator, or a block producer, etc. based on the configuration. The "server" endpoint of SNARK Worker RPCs defined in this folder could be found in function `setup_local_server` in `app/cli/src/init/mina_run.ml`.


## What is a work? 

The exact definition of a "work" differes before and after the Mesa HF. 

### Before Mesa HF

A SNARK work is one or two single work, where a single work is either requesting a proof for a command, or a proof that is a merge of 2 proofs. The snark worker should return one or two proofs corresponding to the single work.

### After Mesa HF

A SNARK work is anything that requires generating one proof, which is one of: a proof for a non-zkApp command, a proof for a zkApp segment, or a proof that merges 2 proofs. The snark worker should return one proof exactly.

With Mesa HF, we can utilize more parallelism on SNARK workers, hence the number of segments per zkApp command is less relevant for proof generation latency. 
