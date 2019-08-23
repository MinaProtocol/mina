#!/bin/bash
set -x #echo on
set -eu

USAGE="$0 <download|compile|all>"

if [[ $# -eq 0 ]]; then
  echo $USAGE
  exit 1
fi

case $1 in
  "download")
    DOWNLOAD_THINGS=YES
    COMPILE_THINGS=NO ;;
  "compile")
    DOWNLOAD_THINGS=NO
    COMPILE_THINGS=YES ;;
  "all")
    DOWNLOAD_THINGS=YES
    COMPILE_THINGS=YES ;;
  *)
    echo $USAGE
    exit 1
esac

if [[ $DOWNLOAD_THINGS == "YES" ]]; then
  PACKAGES="gpatch opam cmake gmp pkg-config openssl libffi libsodium boost zlib libomp"

  # removing already installed packages from the list
  for p in $(env HOMEBREW_NO_AUTO_UPDATE=1 brew list); do
    PACKAGES=${PACKAGES//$p/}
  done;

  # only run if there's work to do
  if [[ $PACKAGES = *[![:space:]]* ]]; then
    yes | env HOMEBREW_NO_AUTO_UPDATE=1 brew install $PACKAGES
  else
    echo 'All brew packages have already been installed.'
  fi
else
  echo 'Not running download step'
fi


# Compile things
if [[ $COMPILE_THINGS == "YES" ]]; then

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

  opam switch list -s
  # Fixme, don't create if you already have?

  # This is dirty, keep the OCaml project version up to date!
  opam switch create 4.07.1+statistical-memprof || true
  opam switch 4.07.1+statistical-memprof

  # Test -- see if curent export is different from saved export
  opam switch export opam.export.test
  diff -U1 opam.export.test src/opam.export

  # All our ocaml packages
  opam switch -y import src/opam.export
  eval $(opam config env)

  # Extlib gets automatically installed, but we want our pin, so we should
  # uninstall here
  opam uninstall -y extlib

  # Our pins
  opam pin -y add src/external/ocaml-sodium
  opam pin -y add src/external/rpc_parallel
  opam pin -y add src/external/ocaml-extlib
  opam pin -y add src/external/digestif

  # workaround a permissions problem
  sudo chown -R distiller /Users/distiller/.opam
  sudo chmod -R u+rw /Users/distiller/.opam

  opam pin -y add src/external/async_kernel
  opam pin -y add src/external/coda_base58
  opam pin -y add src/external/graphql_ppx
  eval $(opam config env)

else
  echo 'Not running compile step.'
fi
