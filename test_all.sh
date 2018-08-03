#!/bin/bash

set -eo pipefail

eval `opam config env`
jbuilder runtest --verbose -j8

# TODO: Enable as soon as we fix full-test!!
# jbuilder exec cli -- full-test

# TODO: Test crashes with "impossible" error
# jbuilder exec cli -- coda-sample-test
jbuilder exec app/integration-test/cli.exe all-test
jbuilder exec app/nanobit/src/cli.exe -- transaction-snark-profiler -check-only true

