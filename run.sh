#!/bin/bash


#Test=coda-block-production-test
Test=coda-shared-prefix-test
#Test=full-test
#Test=coda-peers-test

#Filter='^"module-membership" = "true"'
#Filter='^"module-coda-peers-test" = "true"'
#Filter='(level=fatal && ^"module-host: 127.0.0.1:23002" = "true" && ^"module" = "ledger_builder_controller") || ^"module-coda-shared-prefix-test" = "true"'
Filter='(level=fatal && ^"module-host: 127.0.0.1:23002" = "true") || ^"module-coda-shared-prefix-test" = "true"'
#Filter='^"module-coda-shared-prefix-test" = "true"'
#Filter='^"module-coda-block-production-test" = "true"'
#Filter='^"module-coda-shared-prefix-test" = "true" || level=fatal'
#Filter='^"module-coda-shared-prefix-test" = "true" || ^"module-Gossip_net" = "true"'
#Filter='^"module-proposer" = "true" || ^"module-coda-block-production-test" = "true" || level=fatal'

# ============================================================================

set -e
source ~/.profile
ls app/kademlia-haskell/result/bin > /dev/null || make kademlia
dune build -j8 && dune exec cli -- $Test | dune exec logproc -- -c "$Filter"
