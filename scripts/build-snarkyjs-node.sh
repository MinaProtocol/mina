SNARKY_JS_PATH=$1
[ -z "$SNARKY_JS_PATH" ] && SNARKY_JS_PATH=src/lib/snarky_js_bindings/snarkyjs

pushd "$SNARKY_JS_PATH"
  [ -d node_modules ] || npm i
popd

dune b src/lib/crypto/kimchi_bindings/js/node_js \
&& dune b src/lib/snarky_js_bindings/snarky_js_node.bc.js \
&& dune b src/lib/snarky_js_bindings/snarkyjs/src/snarky/gen/js-layout.ts || exit 1

BINDINGS_PATH="$SNARKY_JS_PATH"/dist/server/node_bindings/
mkdir -p "$BINDINGS_PATH"
cp _build/default/src/lib/crypto/kimchi_bindings/js/node_js/plonk_wasm* "$BINDINGS_PATH"
cp _build/default/src/lib/snarky_js_bindings/snarky_js_node*.js "$BINDINGS_PATH"
chmod -R 777 "$BINDINGS_PATH"

# better error messages
# TODO: find a less hacky way to make adjustments to jsoo compiler output
# `s` is the jsoo representation of the error message string, and `s.c` is the actual JS string
sed -i 's/function failwith(s){throw \[0,Failure,s\]/function failwith(s){throw joo_global_object.Error(s.c)/' "$BINDINGS_PATH"/snarky_js_node.bc.js
sed -i 's/function invalid_arg(s){throw \[0,Invalid_argument,s\]/function invalid_arg(s){throw joo_global_object.Error(s.c)/' "$BINDINGS_PATH"/snarky_js_node.bc.js
sed -i 's/return \[0,Exn,t\]/return joo_global_object.Error(t.c)/' "$BINDINGS_PATH"/snarky_js_node.bc.js

npm run --prefix="$SNARKY_JS_PATH" build -- --bindings=./dist/server/node_bindings/
