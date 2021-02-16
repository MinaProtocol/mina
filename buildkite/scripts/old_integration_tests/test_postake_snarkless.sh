#!/bin/bash
export PATH=/home/opam/.cargo/bin:/usr/lib/go/bin:$PATH
export GO=/usr/lib/go/bin/go

make libp2p_helper
eval $(opam env)
./scripts/test.py run --non-interactive --collect-artifacts --yes "test_postake_snarkless:full-test"
./scripts/test.py run --non-interactive --collect-artifacts --yes "test_postake_snarkless:transaction-snark-profiler -k 1"
