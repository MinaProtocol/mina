#!/bin/bash

set -eo pipefail

eval `opam config env`
jbuilder runtest --verbose -j8

# TODO: Enable as soon as we fix full-test!!
# jbuilder exec cli -- full-test
jbuilder exec cli -- transaction-snark-profiler -check-only

