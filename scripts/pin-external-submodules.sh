#!/bin/sh

# update and pin submodules, used by CI

SUBMODULES="ocaml-sodium rpc_parallel ocaml-extlib digestif ocaml-extlib ocaml-rocksdb ppx_optcomp async_kernel coda_base58 graphql_ppx"

git submodule sync && git submodule update --init --recursive

for submod in $SUBMODULES; do
    echo "Pinning submodule" $submod
    opam pin -y add src/external/$submod
done
