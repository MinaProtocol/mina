#!/bin/bash
set -o pipefail -x

TEST_NAME="$1"
MINA_IMAGE="gcr.io/o1labs-192920/mina-daemon:$MINA_DOCKER_TAG-devnet"
ARCHIVE_IMAGE="gcr.io/o1labs-192920/mina-archive:$MINA_DOCKER_TAG"

if [[ "${TEST_NAME:0:4}" == "opt-" ]] && [[ "$RUN_OPT_TESTS" == "" ]]; then
  echo "Skipping $TEST_NAME"
  exit 0
fi

if [[ "$TEST_NAME" == "snarkyjs" ]]; then
  echo "--- build JS dependencies"
  source ~/.profile
  # snarkyjs
  dune b src/lib/crypto/kimchi_bindings/js/node_js --profile=${DUNE_PROFILE} \
  && dune b src/lib/snarky_js_bindings/lib --profile=${DUNE_PROFILE} \
  && dune b src/lib/snarky_js_bindings/snarky_js_node.bc.js --profile=${DUNE_PROFILE} || exit 1
  BINDINGS_PATH=src/lib/snarky_js_bindings/snarkyjs/dist/server/node_bindings/
  mkdir -p "$BINDINGS_PATH"
  cp _build/default/src/lib/crypto/kimchi_bindings/js/node_js/plonk_wasm* "$BINDINGS_PATH"
  cp _build/default/src/lib/snarky_js_bindings/snarky_js_node*.js "$BINDINGS_PATH"
  chmod -R 777 "$BINDINGS_PATH"
  cd src/lib/snarky_js_bindings/snarkyjs
  npm i && npm run build -- --bindings=./dist/server/node_bindings/
  cd ../../../..
  # mina-signer
  dune b src/app/client_sdk/client_sdk.bc.js --profile=${DUNE_PROFILE} || exit 1
  cd frontend/mina-signer
  (npm i && npm run copy-jsoo && npm run copy-wasm && npm run build)
  cd ../..
fi

./test_executive.exe cloud "$TEST_NAME" \
  --mina-image "$MINA_IMAGE" \
  --archive-image "$ARCHIVE_IMAGE" \
  --mina-automation-location ./automation \
  | tee "$TEST_NAME.test.log" \
  | ./logproc.exe -i inline -f '!(.level in ["Debug", "Spam"])'
