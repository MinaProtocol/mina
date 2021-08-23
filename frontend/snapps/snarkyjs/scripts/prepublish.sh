#!/bin/bash

./node_modules/.bin/webpack --config webpack.prod.js 

cp src/chrome_bindings/plonk_init.js ./dist
cp src/chrome_bindings/plonk_wasm.js ./dist
cp src/chrome_bindings/plonk_wasm_bg.wasm ./dist
cp -r src/chrome_bindings/snippets ./dist

cp src/snarky.d.ts ./dist