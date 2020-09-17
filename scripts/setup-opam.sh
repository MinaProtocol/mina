#!/bin/bash
set -x # echo on
set -eu

# Keep compile dirs to avoid recompiles
export OPAMKEEPBUILDDIR='true'
export OPAMREUSEBUILDDIR='true'
export OPAMYES=1

# Set term to xterm if not set
export TERM=${TERM:-xterm}

SWITCH='4.07.1'

if [[ -d ~/.opam ]]; then
  # ocaml environment
  eval $(opam config env)

  # check for cache'd opam
  SWITCH_LIST=$(opam switch list -s)

  # Check to see if we have explicit switch version
  SWITCH_FOUND=false
  for val in $SWITCH_LIST; do
    if [ $val == $SWITCH ]; then
      SWITCH_FOUND=true
    fi
  done
else
  # if there is no opam switch initialized, start from scratch
  SWITCH_FOUND=false
fi

if [ "$SWITCH_FOUND" = true ]; then
  opam switch set $SWITCH
else
  # Build opam from scratch
  opam init
  opam update
  opam switch create $SWITCH || true
  opam switch $SWITCH
fi

# FIXME: Manually pin ocamlgraph while their hosting is down
opam install conf-autoconf
opam pin ocamlgraph https://github.com/backtracking/ocamlgraph/archive/v1.8.8.tar.gz

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

# workaround a permissions problem in rpc_parallel .git
sudo chmod -R u+rw ~/.opam

opam pin add src/external/async_kernel
opam pin add src/external/coda_base58
opam pin add src/external/graphql_ppx
eval $(opam config env)

# show switch list at end
echo "opam switch list"
opam switch list -s
