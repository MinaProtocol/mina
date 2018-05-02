#!/bin/bash

set -eo pipefail

eval `opam config env`
jbuilder runtest --verbose

jbuilder exec cli -- full-test
jbuilder exec cli -- transaction-snark-profiler -check-only true

