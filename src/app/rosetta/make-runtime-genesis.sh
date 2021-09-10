#!/bin/bash

set -eou pipefail

PK=B62qmnkbvNpNvxJ9FkSkBy5W6VkquHbgN2MDHh1P8mRVX3FQ1eWtcxV
SNARK_PK=B62qjnkjj3zDxhEfxbn1qZhUawVeLsUr2GCzEz8m1MDztiBouNsiMUL
TIMELOCKED_PK=B62qpJDprqj1zjNLf4wSpFC6dqmLzyokMy6KtMLSvkU8wfdL1midEb4

mkdir -p /tmp/s3_cache_dir/

mkdir -p /tmp/keys \
  && chmod go-rwx /tmp/keys \
  && echo '{"box_primitive":"xsalsa20poly1305","pw_primitive":"argon2i","nonce":"8jGuTAxw3zxtWasVqcD1H6rEojHLS1yJmG3aHHd","pwsalt":"AiUCrMJ6243h3TBmZ2rqt3Voim1Y","pwdiff":[134217728,6],"ciphertext":"DbAy736GqEKWe9NQWT4yaejiZUo9dJ6rsK7cpS43APuEf5AH1Qw6xb1s35z8D2akyLJBrUr6m"}' > /tmp/keys/demo-block-producer \
  && chmod go-rwx /tmp/keys/demo-block-producer \
  && rm -rf ~/.mina-config \
  && mkdir -p ~/.mina-config/wallets/store \
  && echo "$PK" >  ~/.mina-config/wallets/store/$PK.pub \
  && cp /tmp/keys/demo-block-producer ~/.mina-config/wallets/store/$PK \
  && rm -rf ~/.mina-config/genesis* \
  && echo '{"ledger":{"accounts":[{"pk":"'$PK'","balance":"66000","sk":null,"delegate":null}, {"pk":"'$SNARK_PK'","balance":"0.000000001","sk":null,"delegate":null}, {"pk":"'$TIMELOCKED_PK'","balance":"10000","sk":null,"delegate":null,"timing":{"initial_minimum_balance":"5000","cliff_time":"20","cliff_amount":"2000","vesting_period":"5","vesting_increment":"10"}}], "add_genesis_winner":true}}' > /tmp/config.json \
  && ../../../_build/default/src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe --config-file /tmp/config.json
