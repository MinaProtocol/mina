#!/bin/bash

./node_modules/.bin/webpack --config webpack.dev.js --stats-error-details

cp src/chrome_bindings/server.py ./dist
cp src/chrome_bindings/index.html ./dist

cp src/chrome_bindings/plonk_init.js ./dist
cp src/chrome_bindings/plonk_wasm.js ./dist
cp src/chrome_bindings/plonk_wasm_bg.wasm ./dist
cp -r src/chrome_bindings/snippets ./dist