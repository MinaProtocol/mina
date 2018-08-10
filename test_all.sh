#!/bin/bash

set -eo pipefail

eval `opam config env`
dune runtest --verbose -j8

# TODO: Enable as soon as we fix full-test!!
# jbuilder exec cli -- full-test

dune exec cli -- coda-sample-test
dune exec integration_test -- all-test
dune exec cli -- transaction-snark-profiler -check-only


