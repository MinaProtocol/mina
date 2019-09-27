#!/bin/sh

PACKAGES="ocaml-sodium rpc_parallel ocaml-extlib digestif ocaml-extlib ocaml-rocksdb ppx_optcomp async_kernel coda_base58 graphql_ppx"

for pkg in $PACKAGES; do
    echo "Pinning package" $pkg
    opam pin -y add src/external/$pkg
done

    
    

      
