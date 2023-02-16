#!/bin/bash

set -e

SNARKY_JS_PATH=$1
[ -z "$SNARKY_JS_PATH" ] && SNARKY_JS_PATH=src/lib/snarky_js_bindings/snarkyjs

pushd "$SNARKY_JS_PATH"
  [ -d node_modules ] || npm i
popd

export DUNE_USE_DEFAULT_LINKER="y"

if [ -f _build/default/src/lib/snarky_js_bindings/snarky_js_node.bc.js ]; then
  echo "found snarky_js_node.bc.js"
  if [ -f _build/default/src/lib/snarky_js_bindings/snarky_js_node.bc.map ]; then
    echo "found snarky_js_node.bc.map, saving at a tmp location because dune will delete it"
    cp _build/default/src/lib/snarky_js_bindings/snarky_js_node.bc.map _build/snarky_js_node.bc.map ;
  else
    echo "did not find snarky_js_node.bc.map, deleting snarky_js_node.bc.js to force calling jsoo again"
    rm -f _build/default/src/lib/snarky_js_bindings/snarky_js_node.bc.js
  fi
fi

dune b src/lib/crypto/kimchi_bindings/js/node_js \
&& dune b src/lib/snarky_js_bindings/snarky_js_node.bc.js || exit 1

# update if new source map was built
if [ -f _build/default/src/lib/snarky_js_bindings/snarky_js_node.bc.map ]; then
  echo "new source map created";
  cp "_build/default/src/lib/snarky_js_bindings/snarky_js_node.bc.map" "_build/snarky_js_node.bc.map";
fi

dune b src/lib/snarky_js_bindings/snarkyjs/src/provable/gen/js-layout.ts \
&& dune b src/lib/snarky_js_bindings/snarkyjs/src/js_crypto/constants.ts \
  src/lib/snarky_js_bindings/snarkyjs/src/js_crypto/test_vectors/poseidonKimchi.ts \
|| exit 1

BINDINGS_PATH="$SNARKY_JS_PATH"/dist/node/_node_bindings/
mkdir -p "$BINDINGS_PATH"
chmod -R 777 "$BINDINGS_PATH"
cp _build/default/src/lib/crypto/kimchi_bindings/js/node_js/plonk_wasm* "$BINDINGS_PATH"
mv -f $BINDINGS_PATH/plonk_wasm.js $BINDINGS_PATH/plonk_wasm.cjs
cp _build/default/src/lib/snarky_js_bindings/snarky_js_node*.js "$BINDINGS_PATH"
cp "_build/snarky_js_node.bc.map" "$BINDINGS_PATH"/snarky_js_node.bc.map
mv -f $BINDINGS_PATH/snarky_js_node.bc.js $BINDINGS_PATH/snarky_js_node.bc.cjs
sed -i 's/plonk_wasm.js/plonk_wasm.cjs/' $BINDINGS_PATH/snarky_js_node.bc.cjs

# cleanup tmp source map
cp _build/snarky_js_node.bc.map _build/default/src/lib/snarky_js_bindings/snarky_js_node.bc.map
rm -f _build/snarky_js_node.bc.map

# better error messages
# TODO: find a less hacky way to make adjustments to jsoo compiler output
# `s` is the jsoo representation of the error message string, and `s.c` is the actual JS string
sed -i 's/function failwith(s){throw \[0,Failure,s\]/function failwith(s){throw joo_global_object.Error(s.c)/' "$BINDINGS_PATH"/snarky_js_node.bc.cjs
sed -i 's/function invalid_arg(s){throw \[0,Invalid_argument,s\]/function invalid_arg(s){throw joo_global_object.Error(s.c)/' "$BINDINGS_PATH"/snarky_js_node.bc.cjs
sed -i 's/return \[0,Exn,t\]/return joo_global_object.Error(t.c)/' "$BINDINGS_PATH"/snarky_js_node.bc.cjs
# TODO: this doesn't cover all cases, maybe should rewrite to_exn instead
sed -i 's/function raise(t){throw caml_call1(to_exn$0,t)}/function raise(t){throw Error(t?.[1]?.c ?? "Unknown error thrown by raise")}/' "$BINDINGS_PATH"/snarky_js_node.bc.cjs


npm run --prefix="$SNARKY_JS_PATH" dev
