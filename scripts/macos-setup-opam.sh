#!/bin/bash
set -x #echo on
set -eu

# Keep compile dirs to avoid recompiles
export OPAMKEEPBUILDDIR='true'
export OPAMREUSEBUILDDIR='true'
export OPAMYES=1

# Set term to xterm if not set
export TERM=${TERM:-xterm}

# ocaml downloading
opam init
eval $(opam config env)

opam update

SWITCH_LIST=$(opam switch list -s)
SWITCH='4.07.1+statistical-memprof'

# Check to see if we have switch
SWITCH_FOUND=false
for val in $SWITCH_LIST; do
  if [ $val == $SWITCH ]; then
    SWITCH_FOUND=true
  fi
done

if [ "$SWITCH_FOUND" = true ]; then
  opam switch set $SWITCH
else
  opam switch create $SWITCH || true
  opam switch $SWITCH
fi

# Test -- see if curent export is different from saved export
opam switch export opam.export.test
diff -U1 opam.export.test src/opam.export || true

# All our ocaml packages
opam switch import src/opam.export
eval $(opam config env)

# Extlib gets automatically installed, but we want our pin, so we should
# uninstall here
opam uninstall extlib

# Our pins
opam pin add src/external/ocaml-sodium
opam pin add src/external/rpc_parallel
opam pin add src/external/ocaml-extlib
opam pin add src/external/digestif
opam pin add src/external/async_kernel
opam pin add src/external/coda_base58
opam pin add src/external/graphql_ppx
eval $(opam config env)
