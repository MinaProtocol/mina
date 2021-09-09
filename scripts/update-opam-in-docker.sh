#!/bin/bash

# update OPAM packages, including pinned ones

if [ ! -f /.dockerenv ]; then
    echo `basename $0` "can run only inside Coda Docker image"
    exit 1
fi

# fail if any command fails

set -e

# update not-pinned OPAM packages

opam update

opam switch import src/opam.export

# update pinned packages

git submodule update --init --recursive

# don't save or reuse sources when repinning
declare -x OPAMKEEPBUILDDIR=false
declare -x OPAMREUSEBUILDDIR=false

# in Docker, pinned packages are at root directory
# adding a pin at src/external will rebuild it
function repin () {
    echo "Updating OPAM package $1"
    opam pin -y add src/external/$1
}

function uptodate () {
    echo "OPAM package $1 is up-to-date"
}

# submodules
for pkg in async_kernel graphql_ppx ocaml-extlib rpc_parallel ; do
    CURRENT_COMMIT=$(git submodule status src/external/$pkg | awk '{print $1}')
    DOCKER_COMMIT=$(cat ~opam/opam-repository/$pkg.commit)
    if [ $CURRENT_COMMIT != $DOCKER_COMMIT ] ; then
        repin $pkg
    else
      uptodate $pkg
    fi
done

# not submodules
for pkg in ocaml-sodium coda_base58 ; do
    CURRENT_COMMIT=$(git log --format=oneline -n 1 src/external/$pkg | awk '{print $1}')
    DOCKER_COMMIT=$(cat ~opam/opam-repository/$pkg.commit)
    if [ $CURRENT_COMMIT != $DOCKER_COMMIT ] ; then
        repin $pkg
    else
      uptodate $pkg
    fi
done
