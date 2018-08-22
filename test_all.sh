#!/bin/bash

set -eo pipefail

eval `opam config env`

dune runtest --verbose -j8 & p1=$!

integration () {
  dune exec cli -- full-test
  dune exec cli -- coda-peers-test
  dune exec cli -- transaction-snark-profiler -check-only
}

integration & p2=$!

wait $p1
wait $p2
