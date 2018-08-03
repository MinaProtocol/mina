#!/bin/bash

set -eo pipefail

eval `opam config env`
jbuilder runtest --verbose -j8

# TODO: Enable as soon as we fix full-test!!
# jbuilder exec cli -- full-test

# TODO: Test crashes with "impossible" error
# jbuilder exec cli -- coda-sample-test
jbuilder exec integration_test -- all-test
jbuilder exec cli -- transaction-snark-profiler -check-only true

