#!/usr/bin/env bash
#
# Does the fork genesis insert adopt a child that arrived before it?
#
# The post-fork chain's second block reaches the archive over the ordinary block
# path within minutes of the fork, while the genesis insert waits on a ledger.
# So the usual order is child first, and a block whose parent is absent is
# stored with parent_id NULL. The ordinary path repairs that for itself; this
# insert does not go through it, so it has to do the same by hand -- otherwise
# the boundary stays severed however long the block sits there.
#
# Two passes. The first lets the archive build and insert the genesis, which is
# how the test learns its state hash. The second puts a child in front of it --
# parent_hash pointing at the genesis, parent_id NULL, exactly what the ordinary
# path leaves behind -- removes the genesis, and lets the archive insert it
# again. The child's parent_id must end up as the genesis's id.
#
# Hermetic: the configuration carries its ledger as inline accounts, so nothing
# is fetched. Needs docker and a built archive.exe.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$ROOT" || exit 1

CT=${CT:-archive-automode-relink}
PORT=${PORT:-55452}
ARCHIVE=${ARCHIVE:-$ROOT/_build/default/src/app/archive/archive.exe}
CONF="$HERE/inline-ledger-fork-config.json"
FORK_HASH=3NLwkyj6moic1DsdANXVYeuWUWHuDJGDgfz2Q9nADJpA5mBCcmQn
CONN="postgresql://postgres:postgres@127.0.0.1:${PORT}/archive"
WORK=$(mktemp -d)
APID=""

cleanup() {
  [[ -n "$APID" ]] && kill "$APID" 2>/dev/null
  docker rm -f "$CT" >/dev/null 2>&1
  rm -rf "$WORK"
}
trap cleanup EXIT

[[ -x "$ARCHIVE" ]] || {
  echo "no archive at $ARCHIVE -- build it first:"
  echo "  dune build src/app/archive/archive.exe"
  exit 1
}

echo "=== postgres"
docker rm -f "$CT" >/dev/null 2>&1
docker run -d --name "$CT" -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=archive \
  -p "$PORT:5432" postgres:12-alpine >/dev/null || exit 1
# The image runs initdb against a temporary server and then restarts, so the
# first connection that succeeds does not mean the real server is up.
ready=0
for _ in $(seq 1 120); do
  if docker exec -e PGPASSWORD=postgres "$CT" psql -U postgres -d archive -c 'SELECT 1' >/dev/null 2>&1; then
    sleep 1
    docker exec -e PGPASSWORD=postgres "$CT" psql -U postgres -d archive -c 'SELECT 1' >/dev/null 2>&1 \
      && { ready=1; break; }
  fi
  sleep 1
done
[[ "$ready" -eq 1 ]] || { echo "postgres never came up"; exit 1; }

q() { docker exec -e PGPASSWORD=postgres "$CT" psql -qtAX -U postgres -d archive -c "$1" 2>&1; }

docker exec -e PGPASSWORD=postgres -i "$CT" psql -q -U postgres -d archive \
  < src/app/archive/create_schema.sql >/dev/null 2>&1

# The fork, as a daemon would have left it. Dollar-quoted: the configuration is
# JSON, and hand-escaping it into a single-quoted literal silently inserts
# nothing.
{
  printf '%s' "INSERT INTO hardfork_state (id, fork_state_hash, fork_blockchain_length, fork_global_slot, config_json, source) VALUES (1, '$FORK_HASH', 1748, 3059, \$cfg\$"
  cat "$CONF"
  printf '%s\n' "\$cfg\$, 'daemon_config');"
} > "$WORK/fork.sql"
docker exec -e PGPASSWORD=postgres -i "$CT" psql -q -v ON_ERROR_STOP=1 -U postgres -d archive \
  < "$WORK/fork.sql" || { echo "could not record the fork"; exit 1; }

start_archive() {
  "$ARCHIVE" run --postgres-uri "$CONN" --server-port "$1" > "$2" 2>&1 &
  APID=$!
  for _ in $(seq 1 120); do
    grep -q "Archive process ready" "$2" 2>/dev/null && break
    kill -0 "$APID" 2>/dev/null || { echo "the archive exited during startup:"; tail -20 "$2"; exit 1; }
    sleep 1
  done
}

wait_for_genesis() {
  local found=""
  for _ in $(seq 1 40); do
    found=$(q "SELECT state_hash FROM blocks WHERE global_slot_since_hard_fork = 0 AND height > 1;")
    [[ -n "$found" ]] && break
    sleep 3
  done
  echo "$found"
}

echo
echo "=== pass 1: the archive builds and inserts the genesis"
start_archive 3111 "$WORK/a.log"
GEN=$(wait_for_genesis)
kill "$APID" 2>/dev/null; wait "$APID" 2>/dev/null; APID=""

if [[ -z "$GEN" ]]; then
  echo "  it never inserted one. Why:"
  grep -oE "Cannot insert the fork genesis block yet.*|Still cannot insert.*" "$WORK/a.log" \
    | tail -1 | sed 's/^/    /'
  echo "=== FAIL"
  exit 1
fi
echo "  inserted $GEN"

echo
echo "=== pass 2: a child arrives first, then the genesis"
# A block that points at the genesis by hash and has no parent_id: what the
# ordinary block path leaves when the parent is not there yet.
q "INSERT INTO blocks (id, state_hash, parent_id, parent_hash, creator_id, block_winner_id,
     last_vrf_output, snarked_ledger_hash_id, staking_epoch_data_id, next_epoch_data_id,
     min_window_density, sub_window_densities, total_currency, ledger_hash, height,
     global_slot_since_hard_fork, global_slot_since_genesis, protocol_version_id,
     timestamp, chain_status)
   SELECT 99000123, 'ORPHANED_CHILD_OF_THE_GENESIS', NULL, state_hash, creator_id,
     block_winner_id, last_vrf_output, snarked_ledger_hash_id, staking_epoch_data_id,
     next_epoch_data_id, min_window_density, sub_window_densities, total_currency,
     ledger_hash, height + 1, global_slot_since_hard_fork + 1,
     global_slot_since_genesis + 1, protocol_version_id, timestamp, 'pending'
   FROM blocks WHERE state_hash = '$GEN';" >/dev/null
q "DELETE FROM blocks WHERE state_hash = '$GEN';" >/dev/null

BEFORE=$(q "SELECT coalesce(parent_id::text,'NULL') FROM blocks WHERE state_hash='ORPHANED_CHILD_OF_THE_GENESIS';")
echo "  child's parent_id before: $BEFORE"
[[ "$BEFORE" == "NULL" ]] || { echo "=== FAIL: the child was not left unlinked"; exit 1; }

start_archive 3112 "$WORK/b.log"
LINKED=NULL
for _ in $(seq 1 40); do
  LINKED=$(q "SELECT coalesce(parent_id::text,'NULL') FROM blocks WHERE state_hash='ORPHANED_CHILD_OF_THE_GENESIS';")
  [[ "$LINKED" != "NULL" ]] && break
  sleep 3
done
kill "$APID" 2>/dev/null; APID=""

GENID=$(q "SELECT id FROM blocks WHERE state_hash='$GEN';")
echo "  child's parent_id after:  $LINKED"
echo "  the genesis's block id:   ${GENID:-absent}"

echo
if [[ -n "$GENID" && "$LINKED" == "$GENID" ]]; then
  echo "=== PASS: the genesis adopted the child"
else
  echo "=== FAIL: the child's parent_id is $LINKED, the genesis is ${GENID:-absent}"
  exit 1
fi
