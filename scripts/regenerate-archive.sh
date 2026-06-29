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

# mina-archive server port for the local network (clear of whale/fish/node/snark ports)
ARCHIVE_PORT=${ARCHIVE_PORT:-3086}

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
     src/app/logproc/logproc.exe \
     src/app/mina_graphql_client/mina_graphql_client_app.exe

# mina-local-network uses mina-graphql-client to wait for sync and to submit
# zkApp/value-transfer txns. It defaults to a PATH binary that doesn't exist in
# a dune build, which silently stalls the sync wait so NO transactions are ever
# sent (coinbase-only blocks). Point it at the built executable.
export MINA_GRAPHQL_CLIENT_EXE=_build/default/src/app/mina_graphql_client/mina_graphql_client_app.exe

# start mina-local-network
#   -ap <port>  enable the archive node (replaces the removed boolean -a)
#   -c reset    generate fresh config/keypairs/ledgers (replaces the removed boolean -r)
#   -ti 1       run periodic transactions every second (replaces the removed -tf)
./scripts/mina-local-network/mina-local-network.sh -ap "${ARCHIVE_PORT}" -c reset \
    -pu "${PG_USER}" \
    -pd "${PG_DB}" \
    -ppw "${PG_PW}" \
    -ti 1 \
    --override-slot-time 30000 \
    -zt \
    -vt \
    -lp &

# The network now writes daemon.json / genesis_ledger.json directly under ROOT (~/.mina-network)
LOCAL_NETWORK_DATA_FOLDER="${HOME}"/.mina-network

trap "pkill -f mina-local-network" EXIT

# stop mina-local-network once enough blocks have been produced.
# Note: the network drops & recreates the archive DB on startup, so the
# `blocks` table may be briefly absent. Keep the query failure-tolerant
# (|| true) and strip any non-digits so a transient error / NULL -> 0
# instead of tripping `set -e`.
while true; do
  sleep 10s
  RAW_BLOCKS="$(PGPASSWORD="${PG_PW}" \
      psql -U "$PG_USER" -h "$PG_HOST" -p "$PG_PORT" "$PG_DB" \
      -t -A \
      -c "select coalesce(MAX(height), 0) from blocks" 2>/dev/null || true)"
  BLOCKS="${RAW_BLOCKS//[!0-9]/}"
  BLOCKS="${BLOCKS:-0}"
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

echo "Regenerating genesis_ledger"
# The archive's genesis state hash depends on the protocol constants (k,
# slots_per_epoch, block_window_duration_ms, proof level, ...). Carry the
# genesis & proof sections from the network's daemon.json verbatim so the
# archive-node-test reconstructs the SAME genesis block the chain was built
# on; otherwise block 2's parent (genesis) is missing and the replayer fails.
jq -s '{ genesis: .[0].genesis, proof: .[0].proof, ledger: .[1] }' \
   "$LOCAL_NETWORK_DATA_FOLDER/daemon.json" \
   "$LOCAL_NETWORK_DATA_FOLDER/genesis_ledger.json" \
   > src/test/archive/sample_db/genesis.json

echo "Regenerating keys"
# Persist the network's keypairs (block producers, snark coordinator, zkApp
# account, libp2p identities) alongside the fixture. Each `-c reset` run
# generates fresh keys, so these MUST be committed together with the data
# above to stay consistent; having them lets the sample_db be reused for
# demos or replayed/extended later. The default key passphrase is empty.
KEYS_DIR=src/test/archive/sample_db/keys
rm -rf "$KEYS_DIR"
mkdir -p "$KEYS_DIR"
for d in offline_whale_keys online_whale_keys offline_fish_keys \
         online_fish_keys snark_coordinator_keys zkapp_keys libp2p_keys; do
  if [ -d "$LOCAL_NETWORK_DATA_FOLDER/$d" ]; then
    cp -r "$LOCAL_NETWORK_DATA_FOLDER/$d" "$KEYS_DIR/"
  fi
done
# Private key files are written 0600; relax so they survive a fresh checkout.
chmod -R u+rw "$KEYS_DIR"

echo "Finished regenerate testing replay"

# The local-network daemons may still hold connections to ${PG_DB}; terminate
# them so the validation dropdb below doesn't fail with "database is being
# accessed by other users".
pkill -f mina-local-network 2>/dev/null || true
PGPASSWORD="${PG_PW}" psql -U "${PG_USER}" -h "${PG_HOST}" -p "${PG_PORT}" -d postgres -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '${PG_DB}' AND pid <> pg_backend_pid();" \
  >/dev/null 2>&1 || true

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
      --canonical-only \
      --log-level Trace \
      --log-json  | jq
