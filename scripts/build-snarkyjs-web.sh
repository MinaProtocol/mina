SNARKY_JS_PATH=$1
[ -z "$SNARKY_JS_PATH" ] && SNARKY_JS_PATH=src/lib/snarky_js_bindings/snarkyjs

dune b src/lib/snarky_js_bindings/snarky_js_chrome.bc.js
cp _build/default/src/lib/crypto/kimchi_bindings/js/chrome/plonk_wasm* "$SNARKY_JS_PATH"/src/chrome_bindings/
cp _build/default/src/lib/snarky_js_bindings/snarky_js_chrome*.js "$SNARKY_JS_PATH"/src/chrome_bindings/

# better error messages
# `s` is the jsoo representation of the error message string, and `s.c` is the actual JS string
sed -i 's/function failwith(s){throw \[0,Failure,s\]/function failwith(s){throw joo_global_object.Error(s.c)/' "$SNARKY_JS_PATH"/src/chrome_bindings/snarky_js_chrome.bc.js
sed -i 's/function invalid_arg(s){throw \[0,Invalid_argument,s\]/function invalid_arg(s){throw joo_global_object.Error(s.c)/' "$SNARKY_JS_PATH"/src/chrome_bindings/snarky_js_chrome.bc.js
sed -i 's/return \[0,Exn,t\]/return joo_global_object.Error(t.c)/' "$SNARKY_JS_PATH"/src/chrome_bindings/snarky_js_chrome.bc.js
sed -i 's/function raise(t){throw caml_call1(to_exn$0,t)}/function raise(t){throw Error(t?.[1]?.c ?? "some error")}/' "$SNARKY_JS_PATH"/src/chrome_bindings/snarky_js_chrome.bc.js

pushd "$SNARKY_JS_PATH"/src/chrome_bindings
  wasm-opt --detect-features --enable-mutable-globals -O4 plonk_wasm_bg.wasm -o plonk_wasm_bg.wasm.opt
  mv plonk_wasm_bg.wasm.opt plonk_wasm_bg.wasm
popd

npm run build:web --prefix="$SNARKY_JS_PATH"
