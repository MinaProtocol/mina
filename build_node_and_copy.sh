dune b src/lib/snarky_js_bindings/snarky_js_node.bc.js
cp _build/default/src/lib/crypto/kimchi_bindings/js/node_js/plonk_wasm* ../snarkyjs/src/node_bindings/
cp _build/default/src/lib/snarky_js_bindings/snarky_js_node*.js ../snarkyjs/src/node_bindings/

pushd ../snarkyjs/src/node_bindings
  wasm-opt --detect-features --enable-mutable-globals -O4 plonk_wasm_bg.wasm -o plonk_wasm_bg.wasm.opt
  mv plonk_wasm_bg.wasm.opt plonk_wasm_bg.wasm
popd
