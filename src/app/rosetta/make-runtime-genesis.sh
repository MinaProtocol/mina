#!/bin/bash

set -eou pipefail

PK=B62qrPN5Y5yq8kGE3FbVKbGTdTAJNdtNtB5sNVpxyRwWGcDEhpMzc8g
SNARK_PK=B62qiWSQiF5Q9CsAHgjMHoEEyR2kJnnCvN9fxRps2NXULU15EeXbzPf

mkdir -p /tmp/s3_cache_dir/

mkdir -p /tmp/keys \
  && chmod go-rwx /tmp/keys \
  && echo '{"box_primitive":"xsalsa20poly1305","pw_primitive":"argon2i","nonce":"8jGuTAxw3zxtWasVqcD1H6rEojHLS1yJmG3aHHd","pwsalt":"AiUCrMJ6243h3TBmZ2rqt3Voim1Y","pwdiff":[134217728,6],"ciphertext":"DbAy736GqEKWe9NQWT4yaejiZUo9dJ6rsK7cpS43APuEf5AH1Qw6xb1s35z8D2akyLJBrUr6m"}' > /tmp/keys/demo-block-producer \
  && chmod go-rwx /tmp/keys/demo-block-producer \
  && rm -rf ~/.coda-config \
  && mkdir -p ~/.coda-config/wallets/store \
  && echo "$PK" >  ~/.coda-config/wallets/store/$PK.pub \
  && cp /tmp/keys/demo-block-producer ~/.coda-config/wallets/store/$PK \
  && rm -rf ~/.coda-config/genesis* \
  && echo '{"ledger":{"accounts":[{"pk":"'$PK'","balance":"66000","sk":null,"delegate":null}, {"pk":"'$SNARK_PK'","balance":"0.000000001","sk":null,"delegate":null}]}}' > /tmp/config.json \
  && ../../../_build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe --config-file /tmp/config.json
