#!/usr/bin/env bash

set -e
TOTAL_BLOCKS=25

# go to root of mina repo
cd $(dirname -- "${BASH_SOURCE[0]}")/..

# Prepare the database
sudo -u postgres dropdb archive || true # fails when db doesn't exist which is fine
psql -U postgres -c 'CREATE DATABASE archive'
export DUNE_PROFILE=devnet
dune build src/app/cli/src/mina.exe src/app/archive/archive.exe src/app/zkapp_test_transaction/zkapp_test_transaction.exe src/app/logproc/logproc.exe
psql -U postgres archive < ./src/app/archive/create_schema.sql
psql -U postgres -c "ALTER USER postgres WITH PASSWORD 'postgres';"

# start mina-local-network
./scripts/mina-local-network/mina-local-network.sh -a -r \
    -pu postgres -ppw postgres \
    -tf 1 --override-slot-time 30000 \
    -zt -vt -lp &

trap "pkill -f mina-local-network" EXIT

# stop mina-local-network once enough blocks have been produced
while true; do
  sleep 10s
  # psql outputs "    " until there are blocks in the db, the +0 defaults that to 0
  BLOCKS="$(( $(psql -U postgres archive -t -c  "select MAX(global_slot_since_genesis) from blocks" 2> /dev/null) +0))"
  echo Generated $BLOCKS/$TOTAL_BLOCKS blocks
  if [ "$((BLOCKS+0))" -ge  $TOTAL_BLOCKS ] ; then
    pkill -f mina-local-network
    break
  fi
done

echo Converting canonical blocks
source ./src/test/archive/sample_db/convert_chain_to_canonical.sh postgres://postgres:postgres@localhost:5432/archive

echo Regenerateing precomputed_blocks.tar.xz
rm -rf precomputed_blocks || true
mkdir precomputed_blocks
find ~/.mina-network -name 'precomputed_blocks.log' | xargs -I ! ./scripts/mina-local-network/split_precomputed_log.sh ! precomputed_blocks
rm ./src/test/archive/sample_db/precomputed_blocks.tar.xz || true
tar cvf ./src/test/archive/sample_db/precomputed_blocks.tar.xz precomputed_blocks
rm -rf precomputed_blocks

echo Regenerateing archive_db.sql
pg_dump -U postgres -d archive > ./src/test/archive/sample_db/archive_db.sql


echo Regenerateing input file
cp ./scripts/mina-local-network/annotated_ledger.json _tmp.json
echo '{ "genesis_ledger": { "accounts": '$(cat _tmp.json | jq '.accounts')', "num_accounts": '$(cat _tmp.json | jq '.num_accounts')' }}' \
  | jq -c > ./src/test/archive/sample_db/replayer_input_file.json
rm _tmp.json

echo Regenerateing genesis_ledger
cat src/test/archive/sample_db/genesis.json | jq ".ledger=$(cat ~/.mina-network/mina-local-network-2-1-1/genesis_ledger.json | jq -c)"  > _tmp.json
mv _tmp.json src/test/archive/sample_db/genesis.json

echo finished regenerate testing replay

sudo -u postgres dropdb archive
psql -U postgres -c 'CREATE DATABASE archive'
psql -U postgres archive < ./src/test/archive/sample_db/archive_db.sql
dune exec src/app/replayer/replayer.exe -- --archive-uri postgres://postgres:postgres@localhost:5432/archive --input-file src/test/archive/sample_db/replayer_input_file.json --log-level Trace --log-json  | jq
