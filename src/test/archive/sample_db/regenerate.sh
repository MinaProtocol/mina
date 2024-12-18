#!/usr/bin/env bash

# go to root of mina repo
cd $(dirname -- "${BASH_SOURCE[0]}")/../../../..

# Prepare the database
sudo -u postgres dropdb archive
psql -U postgres -c 'CREATE DATABASE archive'
DUNE_PROFILE=devnet dune build src/app/cli/src/mina.exe src/app/archive/archive.exe src/app/zkapp_test_transaction/zkapp_test_transaction.exe src/app/logproc/logproc.exe
psql -U postgres archive < ./src/app/archive/create_schema.sql
psql -U postgres -c "ALTER USER postgres WITH PASSWORD 'postgres';"

# start mina-local-network
DUNE_PROFILE=devnet ./scripts/mina-local-network/mina-local-network.sh -a -r -pu postgres -ppw postgres -zt -vt -lp &

PID=$!
rec_cleanup(){
  for p in $(pgrep -P $1);
  do
    rec_cleanup $p
  done
  kill $1
}
trap "rec_cleanup $PID" EXIT

# stop mina-local-network once enough blocks have been produced
while true; do
  sleep 10s
  # psql outputs "    " until there are blocks in the db, the +0 defaults that to 0
  BLOCKS="$(( $(psql -U postgres archive -t -c  "select MAX(global_slot_since_genesis) from blocks" 2> /dev/null) +0))"
  echo Generated $BLOCKS/25 blocks
  if [ "$((BLOCKS+0))" -ge  25 ] ; then
    rec_cleanup $PID
    break
  fi
done

# make the blocks canonical
./src/test/archive/sample_db/convert_chain_to_canonical.sh postgres://postgres:postgres@localhost:5432/archive

# regenerate precomputed_blocks.tar.xz
mkdir precomputed_blocks
find ~/.mina-network -name 'precomputed_blocks.log' | xargs -I ! ./scripts/mina-local-network/split_precomputed_log.sh ! precomputed_blocks
rm ./src/test/archive/sample_db/precomputed_blocks.tar.xz
tar cvf ./src/test/archive/sample_db/precomputed_blocks.tar.xz precomputed_blocks
rm -rf precomputed_blocks

# regenerate archive_db.sql
pg_dump -U postgres -d archive > ./src/test/archive/sample_db/archive_db.sql


# regenerate input file
cp ~/.mina-network/mina-local-network-2-1-1/genesis_ledger.json _tmp1.json
cat _tmp1.json | jq '.accounts' > _tmp2.json
echo '{ "genesis_ledger": { "accounts": '$(cat _tmp2.json)' } }' | jq > _tmp3.json
NEW_HASH=$(psql -U postgres archive -t -c  'SELECT state_hash from blocks where global_slot_since_genesis = (SELECT MAX(global_slot_since_genesis) from blocks)' | head -n1 | sed 's/^ *//')
cat _tmp3.json | jq -c '.+{"target_epoch_ledgers_state_hash": "'$NEW_HASH'"}' > ./src/test/archive/sample_db/replayer_input_file.json
rm _tmp*.json

# regenerate genesis_ledger
cat src/test/archive/sample_db/genesis.json | jq --arg ledger "$(cat ~/.mina-network/mina-local-network-2-1-1/genesis_ledger.json | jq -c)"  > _tmp.json
mv _tmp.json src/test/archive/sample_db/genesis.json
