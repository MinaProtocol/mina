#!/usr/bin/env bash

set -euo pipefail
TOTAL_BLOCKS=${TOTAL_BLOCKS:-25}

# PostgreSQL configuration
PG_USER=${PG_USER:-postgres}
PG_PW=${PG_PW:-postgres}
PG_DB=${PG_DB:-archive}
PG_HOST=${PG_HOST:-localhost}
PG_PORT=${PG_PORT:-5432}
PG_URI="postgresql://${PG_USER}:${PG_PW}@${PG_HOST}:${PG_PORT}/${PG_DB}"

# go to root of mina repo
cd "$(dirname -- "${BASH_SOURCE[0]}")"/..

# Prepare the database
PGPASSWORD="${PG_PW}" dropdb \
          -U "${PG_USER}" \
          -h "${PG_HOST}" \
          -p "${PG_PORT}" \
          "${PG_DB}" || true # fails when db doesn't exist which is fine
PGPASSWORD="${PG_PW}" createdb \
          -U "${PG_USER}" \
          -h "${PG_HOST}" \
          -p "${PG_PORT}" "${PG_DB}"
export DUNE_PROFILE=devnet
PGPASSWORD="${PG_PW}" psql \
          -U "${PG_USER}" \
          -h "${PG_HOST}" \
          -p "${PG_PORT}" \
          "${PG_DB}" < ./src/app/archive/create_schema.sql
dune build \
     src/app/cli/src/mina.exe \
     src/app/archive/archive.exe \
     src/app/zkapp_test_transaction/zkapp_test_transaction.exe \
     src/app/logproc/logproc.exe

# start mina-local-network
# NOTE: archive is enabled via -ap <port> (empty by default) and a fresh
# config/keypairs/ledger via -c reset. The older -a/-r/-tf flags no longer exist
# in mina-local-network.sh.
./scripts/mina-local-network/mina-local-network.sh -ap 3086 -c reset \
    -ph "${PG_HOST}" \
    -pp "${PG_PORT}" \
    -pu "${PG_USER}" \
    -pd "${PG_DB}" \
    -ppw "${PG_PW}" \
    --override-slot-time 30000 \
    -zt \
    -vt \
    -lp &

LOCAL_NETWORK_DATA_FOLDER="${HOME}"/.mina-network

trap "pkill -f mina-local-network" EXIT

# stop mina-local-network once enough blocks have been produced
while true; do
  sleep 10s
  # psql outputs "    " until there are blocks in the db, the +0 defaults that to 0
  BLOCKS="$((
    $(PGPASSWORD=\"${PG_PW}\" \
      psql -U "$PG_USER" -h "$PG_HOST" -p "$PG_PORT" "$PG_DB" \
      -t \
      -c "select MAX(height) from blocks" 2>/dev/null) + 0
  ))"
  echo "Generated ${BLOCKS}/${TOTAL_BLOCKS} blocks"
  if [ "${BLOCKS}" -ge "${TOTAL_BLOCKS}" ] ; then
    pkill -f mina-local-network
    break
  fi
done

echo "Converting canonical blocks"
source ./src/test/archive/sample_db/convert_chain_to_canonical.sh "$PG_URI"

echo "Regenerating precomputed_blocks.tar.xz"
rm -rf precomputed_blocks || true
mkdir precomputed_blocks
find ~/.mina-network -name 'precomputed_blocks.log' | xargs -I ! ./scripts/mina-local-network/split_precomputed_log.sh ! precomputed_blocks
rm ./src/test/archive/sample_db/precomputed_blocks.tar.xz || true
tar -C precomputed_blocks -cvf ./src/test/archive/sample_db/precomputed_blocks.tar.xz .
rm -rf precomputed_blocks

echo "Regenerating archive_db.sql"
PGPASSWORD="${PG_PW}" pg_dump \
          -U "${PG_USER}" \
          -h "${PG_HOST}" \
          -p "${PG_PORT}" \
          -d "${PG_DB}" > ./src/test/archive/sample_db/archive_db.sql


echo "Regenerating input file"
cp ./scripts/mina-local-network/annotated_ledger.json _tmp.json
echo '{ "genesis_ledger": { "accounts": '"$(cat _tmp.json | jq '.accounts')"', "num_accounts": '"$(cat _tmp.json | jq '.num_accounts')"' }}' \
  | jq -c > ./src/test/archive/sample_db/replayer_input_file.json
rm _tmp.json

echo "Regenerating genesis config"
# The archive node is started with this file as its config and recomputes the
# genesis block from it. It must therefore carry the SAME genesis ledger AND the
# SAME genesis/proof constants the network ran with (k, slots_per_epoch,
# grace_period_slots, block_window_duration_ms, transaction_capacity, ...),
# otherwise the recomputed genesis state hash won't match the produced blocks and
# the replayer can't find the genesis block. daemon.json is the network's full
# runtime config, so use it verbatim.
cp "$LOCAL_NETWORK_DATA_FOLDER/daemon.json" src/test/archive/sample_db/genesis.json

echo "Finished regenerate testing replay"

PGPASSWORD="${PG_PW}" dropdb \
          -U "${PG_USER}" \
          -h "${PG_HOST}" \
          -p "${PG_PORT}" \
          "${PG_DB}"
PGPASSWORD="${PG_PW}" createdb \
          -U "${PG_USER}" \
          -h "$PG_HOST" \
          -p "${PG_PORT}" \
          "${PG_DB}"
PGPASSWORD="${PG_PW}" psql \
          -U "${PG_USER}" \
          -h "${PG_HOST}" \
          -p "${PG_PORT}" \
          "${PG_DB}" < ./src/test/archive/sample_db/archive_db.sql
dune exec src/app/replayer/replayer.exe -- \
     --archive-uri "$PG_URI" \
     --input-file src/test/archive/sample_db/replayer_input_file.json \
     --log-level Trace \
     --log-json  | jq
