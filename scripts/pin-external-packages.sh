#!/bin/sh

# update and pin packages, used by CI

PACKAGES="ocaml-sodium capnp-ocaml rpc_parallel ocaml-extlib async_kernel async_unix coda_base58 graphql_ppx ppx_deriving_yojson"

git submodule sync && git submodule update --init --recursive

for pkg in $PACKAGES; do
    echo "Pinning package" $pkg
    opam pin -y add src/external/$pkg
done
