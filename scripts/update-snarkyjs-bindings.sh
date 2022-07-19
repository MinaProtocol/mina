SNARKY_JS_PATH=src/lib/snarky_js_bindings/snarkyjs

# 1. node build

dune b src/lib/crypto/kimchi_bindings/js/node_js \
&& dune b src/lib/snarky_js_bindings/snarky_js_node.bc.js || exit 1

mkdir -p "$SNARKY_JS_PATH"/dist/server/node_bindings
cp _build/default/src/lib/crypto/kimchi_bindings/js/node_js/plonk_wasm* "$SNARKY_JS_PATH"/src/node_bindings/
cp _build/default/src/lib/snarky_js_bindings/snarky_js_node*.js "$SNARKY_JS_PATH"/src/node_bindings/

# better error messages
# TODO: find a less hacky way to make adjustments to jsoo compiler output
# `s` is the jsoo representation of the error message string, and `s.c` is the actual JS string
sed -i 's/function failwith(s){throw \[0,Failure,s\]/function failwith(s){throw joo_global_object.Error(s.c)/' "$SNARKY_JS_PATH"/src/node_bindings/snarky_js_node.bc.js
sed -i 's/function invalid_arg(s){throw \[0,Invalid_argument,s\]/function invalid_arg(s){throw joo_global_object.Error(s.c)/' "$SNARKY_JS_PATH"/src/node_bindings/snarky_js_node.bc.js
sed -i 's/return \[0,Exn,t\]/return joo_global_object.Error(t.c)/' "$SNARKY_JS_PATH"/src/node_bindings/snarky_js_node.bc.js
sed -i 's/function raise(t){throw caml_call1(to_exn$0,t)}/function raise(t){throw Error(t?.[1]?.c ?? "some error")}/' "$SNARKY_JS_PATH"/src/node_bindings/snarky_js_node.bc.js

# optimize wasm / minify JS (we don't do this with jsoo to not break the error message fix above)
pushd "$SNARKY_JS_PATH"/src/node_bindings
  wasm-opt --detect-features --enable-mutable-globals -O4 plonk_wasm_bg.wasm -o plonk_wasm_bg.wasm.opt
  mv plonk_wasm_bg.wasm.opt plonk_wasm_bg.wasm
  npx esbuild --minify --log-level=error snarky_js_node.bc.js > snarky_js_node.bc.min.js
  mv snarky_js_node.bc.min.js snarky_js_node.bc.js
popd

npm run build --prefix="$SNARKY_JS_PATH"

# 2. web build

dune b src/lib/snarky_js_bindings/snarky_js_chrome.bc.js
cp _build/default/src/lib/crypto/kimchi_bindings/js/chrome/plonk_wasm* "$SNARKY_JS_PATH"/src/chrome_bindings/
cp _build/default/src/lib/snarky_js_bindings/snarky_js_chrome*.js "$SNARKY_JS_PATH"/src/chrome_bindings/

# better error messages
# `s` is the jsoo representation of the error message string, and `s.c` is the actual JS string
sed -i 's/function failwith(s){throw \[0,Failure,s\]/function failwith(s){throw joo_global_object.Error(s.c)/' "$SNARKY_JS_PATH"/src/chrome_bindings/snarky_js_chrome.bc.js
sed -i 's/function invalid_arg(s){throw \[0,Invalid_argument,s\]/function invalid_arg(s){throw joo_global_object.Error(s.c)/' "$SNARKY_JS_PATH"/src/chrome_bindings/snarky_js_chrome.bc.js
sed -i 's/return \[0,Exn,t\]/return joo_global_object.Error(t.c)/' "$SNARKY_JS_PATH"/src/chrome_bindings/snarky_js_chrome.bc.js
sed -i 's/function raise(t){throw caml_call1(to_exn$0,t)}/function raise(t){throw Error(t?.[1]?.c ?? "some error")}/' "$SNARKY_JS_PATH"/src/chrome_bindings/snarky_js_chrome.bc.js

# optimize wasm / minify JS (we don't do this with jsoo to not break the error message fix above)
pushd "$SNARKY_JS_PATH"/src/chrome_bindings
  wasm-opt --detect-features --enable-mutable-globals -O4 plonk_wasm_bg.wasm -o plonk_wasm_bg.wasm.opt
  mv plonk_wasm_bg.wasm.opt plonk_wasm_bg.wasm
  npx esbuild --minify --log-level=error snarky_js_chrome.bc.js > snarky_js_chrome.bc.min.js
  mv snarky_js_chrome.bc.min.js snarky_js_chrome.bc.js
popd

npm run build:web --prefix="$SNARKY_JS_PATH"

# 3. update MINA_COMMIT file in snarkyjs

echo "The mina commit used to generate the backends for node and chrome is
$(git rev-parse HEAD)" > "$SNARKY_JS_PATH/MINA_COMMIT"
