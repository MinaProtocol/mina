#!/bin/bash
export PATH=/home/opam/.cargo/bin:/usr/lib/go/bin:$PATH
export GO=/usr/lib/go/bin/go

make libp2p_helper
./scripts/test.py run --no-build --non-interactive --collect-artifacts --yes "dev:coda-bootstrap-test"
