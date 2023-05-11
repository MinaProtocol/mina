#!/bin/bash

set -eo pipefail
source ~/.profile

echo "Building SnarkyJS.."
make snarkyjs

echo "Building mina-signer.."
make mina_signer

echo "Prepare SnarkyJS test module and pack into archive"
cd src/lib/snarky_js_bindings/test_module
npm i
cp $(which node) ./node
cd ../../../..
tar -chzf snarkyjs_test.tar.gz src/lib/snarky_js_bindings/test_module
chmod 777 snarkyjs_test.tar.gz
