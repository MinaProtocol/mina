dune b src/lib/snarky_js_bindings/snarky_js_chrome.bc.js
cp _build/default/src/lib/crypto/kimchi_bindings/js/chrome/plonk_wasm* ../snarkyjs/src/chrome_bindings/
cp _build/default/src/lib/snarky_js_bindings/snarky_js_chrome*.js ../snarkyjs/src/chrome_bindings/

# pushd ../snarkyjs/src/chrome_bindings
#   wasm-opt --detect-features --enable-mutable-globals -O4 plonk_wasm_bg.wasm -o plonk_wasm_bg.wasm.opt
#   mv plonk_wasm_bg.wasm.opt plonk_wasm_bg.wasm
# popd
