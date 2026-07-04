#!/bin/bash
chmod -R +w _build/default/src/lib/marlin_plonk_bindings/js/test/web
cp -t _build/default/src/lib/marlin_plonk_bindings/js/test/web src/lib/marlin_plonk_bindings/js/test/web/{server.py,index.html}
(cd _build/default/src/lib/marlin_plonk_bindings/js/test/web/; ./server.py)
