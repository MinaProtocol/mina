#!/bin/bash

set -eo pipefail
source ~/.profile

echo "Building SnarkyJS.."
make snarkyjs

echo "Prepare SnarkyJS test module and pack into archive"
npm pack src/lib/snarkyjs
mv snarkyjs-*.tgz snarkyjs.tgz
cd src/lib/snarkyjs/tests/integration
npm i ../../../../../snarkyjs.tgz
cp $(which node) ./node
cd ../../../../..
tar -chzf snarkyjs_test.tar.gz src/lib/snarkyjs/tests/integration
chmod 777 snarkyjs_test.tar.gz
