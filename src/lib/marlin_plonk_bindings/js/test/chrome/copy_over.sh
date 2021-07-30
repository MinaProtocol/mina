#!/bin/bash
chmod -R +w _build/default/src/lib/marlin_plonk_bindings/js/test/chrome
cp -r -t _build/default/src/lib/marlin_plonk_bindings/js/test/chrome _build/default/src/lib/marlin_plonk_bindings/js/chrome/plonk_wasm* _build/default/src/lib/marlin_plonk_bindings/js/chrome/snippets
cp -t _build/default/src/lib/marlin_plonk_bindings/js/test/chrome src/lib/marlin_plonk_bindings/js/test/chrome/{server.py,index.html}
(cd _build/default/src/lib/marlin_plonk_bindings/js/test/chrome/; ./server.py)
