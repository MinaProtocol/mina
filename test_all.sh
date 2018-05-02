#!/bin/bash

eval `opam config env`
jbuilder run_test --verbose

jbuilder exec cli -- full_test
jbuilder exec cli -- transaction-snark-profiler -k 1 -dry-run true

