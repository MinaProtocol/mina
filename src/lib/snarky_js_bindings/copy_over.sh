#!/bin/bash
chmod -R +w _build/default/src/lib/snarky_js_bindings
cp -t _build/default/src/lib/snarky_js_bindings _build/default/src/lib/marlin_plonk_bindings/js/node_js/plonk_wasm*
node --experimental-wasm-modules --experimental-modules --experimental-wasm-threads -i -r \
  ./_build/default/src/lib/snarky_js_bindings/snarky_js_bindings.bc.js \
  -e "var { Field, Bool } = require('./_build/default/src/lib/snarky_js_bindings/snarky_js_bindings.bc.js'); console.log('Bindings attached to global variable \\'bindings\\'')"
