#!/bin/bash

./node_modules/.bin/webpack --config webpack.dev.js --stats-error-details

cp chrome_test/server.py ./dist
cp chrome_test/index.html ./dist

cp chrome_test/plonk_init.js ./dist
cp chrome_test/plonk_wasm.js ./dist
cp chrome_test/plonk_wasm_bg.wasm ./dist
cp -r chrome_test/snippets ./dist