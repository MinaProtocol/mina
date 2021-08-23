#!/bin/bash

./node_modules/.bin/webpack --config webpack.prod.js 

cp chrome_test/plonk_init.js ./dist
cp chrome_test/plonk_wasm.js ./dist
cp chrome_test/plonk_wasm_bg.wasm ./dist
cp -r chrome_test/snippets ./dist

cp src/bindings/snarky2.d.ts ./dist