# Child processes

The Mina daemon spawns some child processes to do its work: a libp2p
helper, a prover, and a verifier. In the module `Termination`, there's
a table that maps processes to a `process_kind`, one of `Prover`,
`Verifier`, or `Libp2p_helper`, and a flag `termination_expected`,
indicating whether termination of the process is expected during the
lifetime of the daemon.  While restarts of the libp2p helper are
expected, the prover and verifier should stay running while the daemon
runs.

Periodically, the daemon checks whether these children are still
running.  If termination is not expected, there's an error log, and
the check raises an exception, which terminates the daemon itself.

The `Child_processes` module offers the function `start_custom`
function, to start child processes with facilities for handling output
and termination in flexible ways. That function is used to start the
libp2p helper, for instances. (The prover and verifier use the
process-creation facility from a fork of the Jane Street
`Rpc_parallel` library.)
