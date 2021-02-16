#!/bin/bash
export PATH=/home/opam/.cargo/bin:/usr/lib/go/bin:$PATH
export GO=/usr/lib/go/bin/go

make libp2p_helper
eval $(opam env)
./scripts/test.py run --non-interactive --collect-artifacts --yes "dev:coda-shared-state-test"
