#!/bin/sh

# update and pin packages, used by CI

PACKAGES="ocaml-sodium coda_base58"

git submodule sync && git submodule update --init --recursive

for pkg in $PACKAGES; do
    echo "Pinning package" $pkg
    opam pin -y add src/external/$pkg
done

opam pin add -y https://github.com/tweag/check_opam_switch#d0aa49884e0f9fd4bbb2cd1a32b798a12
f84b603
