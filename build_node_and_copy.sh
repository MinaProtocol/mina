dune b src/lib/snarky_js_bindings/snarky_js_node.bc.js
cp _build/default/src/lib/crypto/kimchi_bindings/js/node_js/plonk_wasm* ../snarkyjs/src/node_bindings/
cp _build/default/src/lib/snarky_js_bindings/snarky_js_node*.js ../snarkyjs/src/node_bindings/

# better error messages
sed -i 's/function failwith(s){throw \[0,Failure,s\]/function failwith(s){throw joo_global_object.Error(s.c)/' ../snarkyjs/src/node_bindings/snarky_js_node.bc.js
sed -i 's/function invalid_arg(s){throw \[0,Invalid_argument,s\]/function invalid_arg(s){throw joo_global_object.Error(s.c)/' ../snarkyjs/src/node_bindings/snarky_js_node.bc.js

# pushd ../snarkyjs/src/node_bindings
#   wasm-opt --detect-features --enable-mutable-globals -O4 plonk_wasm_bg.wasm -o plonk_wasm_bg.wasm.opt
#   mv plonk_wasm_bg.wasm.opt plonk_wasm_bg.wasm
# popd
