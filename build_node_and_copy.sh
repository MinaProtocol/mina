dune b src/lib/snarky_js_bindings/snarky_js_node.bc.js
rm -r ~/repos/snarkyjs/src/node_bindings/snippets
cp -r _build/default/src/lib/crypto/kimchi_bindings/js/node_js/snippets ~/repos/snarkyjs/src/node_bindings/snippets
cp _build/default/src/lib/crypto/kimchi_bindings/js/node_js/plonk_wasm* ~/repos/snarkyjs/src/node_bindings/
cp _build/default/src/lib/snarky_js_bindings/snarky_js_node*.js ~/repos/snarkyjs/src/node_bindings/

pushd ~/repos/snarkyjs/src/node_bindings
  wasm-opt --detect-features --enable-mutable-globals -O4 plonk_wasm_bg.wasm -o plonk_wasm_bg.wasm.opt
  mv plonk_wasm_bg.wasm.opt plonk_wasm_bg.wasm
popd
