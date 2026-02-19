This package implements a unit test suitable for the auto hard fork daemon
docker packaging.

The test may be run with any `DUNE_PROFILE`, since it uses a pre-built docker
image to start the daemons.

```
dune exec src/test/auto_hardfork_restart_test/auto_hardfork_restart_test.exe -- \
    --docker-image mina-auto-hardfork-devnet-full:g4mwx9afcjy02g6aal94vk3jzhd9i4zp \
    --slot-tx-end 3 \
    --slot-chain-end 9 \
    --hard-fork-genesis-slot-delta 1 \
    --block-window-duration-ms 120000 \
    --proof-level none
```

The test will create two daemon config files. One contains the genesis config
and stop slots, which the test uses to override the installed config in
`/var/lib/coda/config_<GITHASH>.json` when it runs both daemons. The other
contains the modified consensus parameters (currently just the proof level and
slot time), which the test puts in `daemon.json` in the daemon's config
directory.

The test will start up a daemon using the provided docker image tag. It will
wait for the daemon to finish bootstrapping, then wait for it to generate its
auto hard fork config and shut down. Once it has validated the config, it will
start the daemon again with exactly the same config it was using before, wait
for it to bootstrap, then assert that the daemon's reported genesis timestamp is
the scheduled hard fork timestamp.

This test does not current send transactions to the daemon or validate other
specifics about the hard fork (e.g., that the `slot_tx_end` and `slot_chain_end`
were obeyed in block production).
