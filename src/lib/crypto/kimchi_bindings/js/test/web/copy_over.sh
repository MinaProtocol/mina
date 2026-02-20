#!/bin/bash
chmod -R +w _build/default/src/lib/marlin_plonk_bindings/js/test/web
cp -r -t _build/default/src/lib/marlin_plonk_bindings/js/test/web _build/default/src/lib/marlin_plonk_bindings/js/web/plonk_wasm* _build/default/src/lib/marlin_plonk_bindings/js/web/snippets
cp -t _build/default/src/lib/marlin_plonk_bindings/js/test/web src/lib/marlin_plonk_bindings/js/test/web/{server.py,index.html}
(cd _build/default/src/lib/marlin_plonk_bindings/js/test/web/; ./server.py)
