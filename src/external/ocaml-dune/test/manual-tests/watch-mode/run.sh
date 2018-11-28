#!/bin/sh

set -e

DUNE=../../../_build/default/bin/main_dune.exe

$DUNE build orchestrate.exe client.exe $DUNE
../../../_build/default/test/manual-tests/watch-mode/orchestrate.exe $DUNE
rm -f x
