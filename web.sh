#!/bin/bash

set -e
pushd src

dune b app/lite/main.bc.js app/lite/verifier_main.bc.js --profile=release

cp _build/default/app/lite/main.bc.js app/website/static/
cp _build/default/app/lite/verifier_main.bc.js app/website/static/

pushd app/website
dune b && make
popd
popd
