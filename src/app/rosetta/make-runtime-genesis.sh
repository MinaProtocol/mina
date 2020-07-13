#!/bin/bash

set -eou pipefail

PK=ZsMSUuKL9zLAF7sMn951oakTFRCCDw9rDfJgqJ55VMtPXaPa5vPwntQRFJzsHyeh8R8

mkdir -p /tmp/s3_cache_dir/

mkdir -p /tmp/keys \
  && chmod go-rwx /tmp/keys \
  && echo '{"box_primitive":"xsalsa20poly1305","pw_primitive":"argon2i","nonce":"7UMMcQYuXzDWx3zv4HyCxkk9JvUyiWrP6Rje12a","pwsalt":"Ac6n4NVqq2BvnqbmGfYzrZSSRFMe","pwdiff":[134217728,6],"ciphertext":"mzkgEY94mo27CycKXyMhJqAZTRniUiEAWEbj2PA1zDe5hmJqHic4zwdg5tavr9Mcdt6qisT64QMQux8P7ASG8"}' > /tmp/keys/demo-block-producer \
  && chmod go-rwx /tmp/keys/demo-block-producer \
  && rm -rf ~/.coda-config \
  && mkdir -p ~/.coda-config/wallets/store \
  && echo "$PK" >  ~/.coda-config/wallets/store/$PK.pub \
  && cp /tmp/keys/demo-block-producer ~/.coda-config/wallets/store/$PK \
  && rm -rf ~/.coda-config/genesis* \
  && echo '{"ledger":{"accounts":[{"pk":"'$PK'","balance":"66000","sk":null,"delegate":null}]}}' > /tmp/config.json \
  && ../../../_build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe --config-file /tmp/config.json
