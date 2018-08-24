#!/bin/bash

set -eo pipefail

eval `opam config env`

# FIXME: Linux specific
myprocs=`nproc --all`

date
dune runtest --verbose -j${myprocs}

date
dune exec cli -- full-test

date
dune exec cli -- coda-peers-test

date
dune exec cli -- coda-block-production-test

date
dune exec cli -- transaction-snark-profiler -check-only

date
