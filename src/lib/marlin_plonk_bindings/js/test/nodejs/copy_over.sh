#!/bin/bash
chmod -R +w _build/default/src/lib/marlin_plonk_bindings/js/test/nodejs
cp -t _build/default/src/lib/marlin_plonk_bindings/js/test/nodejs _build/default/src/lib/marlin_plonk_bindings/js/node_js/plonk_wasm*
nodejs --experimental-wasm-modules --experimental-modules --experimental-wasm-threads -i -r ./_build/default/src/lib/marlin_plonk_bindings/js/test/nodejs/nodejs_test.bc.js -e "var bindings = require('./_build/default/src/lib/marlin_plonk_bindings/js/test/nodejs/nodejs_test.bc.js'); console.log('Bindings attached to global variable \\'bindings\\'')"
