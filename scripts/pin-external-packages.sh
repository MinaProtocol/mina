#!/bin/sh

# update and pin packages, used by CI

PACKAGES="ocaml-sodium coda_base58"

git submodule sync && git submodule update --init --recursive

for pkg in $PACKAGES; do
    echo "Pinning package" $pkg
    opam pin -y add src/external/$pkg
done
