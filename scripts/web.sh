#!/bin/bash

set -e
pushd src

eval `opam config env`

dune b app/lite/main.bc.js app/lite/verifier_main.bc.js --profile=release

cp _build/default/src/app/lite/main.bc.js app/website/static/
cp _build/default/src/app/lite/verifier_main.bc.js app/website/static/

pushd app/website
dune b && make
popd
popd
