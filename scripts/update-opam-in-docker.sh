#!/bin/bash

# update OPAM packages, including pinned ones

if [ -z $CODA_DOCKER ] ; then
    echo `basename $0` "can run only inside Coda Docker image"
    exit 1
fi

# update not-pinned OPAM packages

opam update

opam switch import src/opam.export

# update pinned packages

git submodule update --init --recursive

# reinstalls of pinned packages should not use saved sources
declare -x OPAMKEEPBUILDDIR=false
declare -x OPAMREUSEBUILDDIR=false

function reinstall () {
    echo "Updating OPAM package $1"
    opam reinstall -y $1
}

function uptodate () {
    echo "OPAM package $1 is up-to-date"
}

# submodules
for pkg in async_kernel digestif graphql_ppx ocaml-extlib ppx_optcomp rpc_parallel ; do
    CURRENT_COMMIT=$(git submodule status src/external/$pkg | awk '{print $1}')
    DOCKER_COMMIT=$(cat ~opam/opam-repository/$pkg.commit)
    if [ $CURRENT_COMMIT != $DOCKER_COMMIT ] ; then
        reinstall $pkg
    else
	uptodate $pkg
    fi
done

# not submodules
for pkg in ocaml-sodium ocaml-rocksdb coda_base58 ; do
    CURRENT_COMMIT=$(git log --format=oneline -n 1 src/external/$pkg | awk '{print $1}')
    DOCKER_COMMIT=$(cat ~opam/opam-repository/$pkg.commit)
    if [ $CURRENT_COMMIT != $DOCKER_COMMIT ] ; then
        reinstall $pkg
    else
	uptodate $pkg
    fi
done
