#!/bin/bash

set -eou pipefail

PK=B62qkV77S1iHryAAWRdRAp4HDBXfQhka3wYmMQSWhoHc8ftNpR44Zct

mkdir -p /tmp/s3_cache_dir/

mkdir -p /tmp/keys \
  && chmod go-rwx /tmp/keys \
  && echo '{"box_primitive":"xsalsa20poly1305","pw_primitive":"argon2i","nonce":"6kT7zxuBrqxvZh5wDYQTkEBzoGzkDCeyMtKT7yt","pwsalt":"8mnVVB1CnfBx7rT1KPLeugzcpbGZ","pwdiff":[134217728,6],"ciphertext":"BQndafcHzrmeV53H2LpwGTYohiKYco3heT746sn87agBgMyw6jNNcWyTv4fEH9wVS4e59y6mb"}' > /tmp/keys/demo-block-producer \
  && chmod go-rwx /tmp/keys/demo-block-producer \
  && rm -rf ~/.coda-config \
  && mkdir -p ~/.coda-config/wallets/store \
  && echo "$PK" >  ~/.coda-config/wallets/store/$PK.pub \
  && cp /tmp/keys/demo-block-producer ~/.coda-config/wallets/store/$PK \
  && rm -rf ~/.coda-config/genesis* \
  && echo '{"ledger":{"accounts":[{"pk":"'$PK'","balance":"66000","sk":null,"delegate":null}]}}' > /tmp/config.json \
  && ../../../_build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe --config-file /tmp/config.json
