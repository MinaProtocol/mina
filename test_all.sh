#!/bin/bash

set -eo pipefail

eval `opam config env`
dune runtest --verbose -j8

dune exec cli -- full-test

dune exec cli -- coda-peers-test

# This test actually creates SNARKs (is slow)
dune exec cli -- transaction-snark-profiler -k 2
