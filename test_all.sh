#!/bin/bash

set -eo pipefail

eval `opam config env`
dune runtest --verbose -j8

dune exec cli -- full-test

dune exec cli -- coda-peers-test
dune exec cli -- coda-block-production-test
dune exec cli -- transaction-snark-profiler -check-only
