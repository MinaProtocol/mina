#!/bin/bash

# Archive automode component test.
#
# Runs the production archive against the checked-in fork-crossing database and
# walks it through the hand-over a hard fork requires, in the order a real one
# happens:
#
#   1. the pre-fork archive, stranded -- canonicalisation only advances when a
#      block arrives more than k above the highest canonical one, and the
#      pre-fork chain has stopped, so the last blocks stay pending for ever
#   2. the schema upgrade, which is where hardfork_state comes from
#   3. the archive running in automode
#   4. the fork configuration, sent over the archive RPC. The archive accepts
#      it here and records it: hardfork_state gets a row
#   5. no history is rewritten yet, though. Accepting the announcement and
#      acting on it are separate: the fork block is so far attested only by
#      that one message, and nothing has corroborated it. finalized_at stays
#      NULL while that is the case
#   6. the post-fork daemon feeds in its genesis block, whose parent hash is the
#      fork block's. That is the corroboration
#   7. now the repair runs, the boundary settles, and finalized_at is stamped
#
# The database is src/test/archive/sample_mesa_hf_db, the same dry-run fixture
# the replayer mesa hard fork test uses. Its fork block is at height 1748, slot
# 3059; its post-fork genesis is at 1749, slot 3120.

set -euo pipefail

ARCHIVE_APP=mina-archive
CLIENT_APP=mina
PG_CONN=postgres://postgres:postgres@localhost:5432/archive
FIXTURE=src/test/archive/sample_mesa_hf_db
ARCHIVE_PORT=3086

# The fork block, and the height it sits at. Both are properties of the
# fixture, not of the code under test.
FORK_HASH=3NLwkyj6moic1DsdANXVYeuWUWHuDJGDgfz2Q9nADJpA5mBCcmQn
FORK_HEIGHT=1748

# How many blocks must sit above the fork block before the archive settles.
#
# The shipped default is 20. This network cannot reach it: the fork block
# accumulates confirmations only between slot_tx_end and slot_chain_end, and
# stop-slot-config.json puts those 20 slots apart, which produced 14 blocks.
# The number is lowered here to suit the fixture, not to skip the check -- 14
# still has to clear 10 for the test to pass.
CONFIRMATIONS=10

while [[ "$#" -gt 0 ]]; do case $1 in
  -a|--app) ARCHIVE_APP="$2"; shift;;
  -c|--client) CLIENT_APP="$2"; shift;;
  -p|--pg) PG_CONN="$2"; shift;;
  *) echo "Unknown parameter passed: $1"; exit 1;;
esac; shift; done

WORK=$(mktemp -d)
ARCHIVE_PID=""
cleanup() {
  if [[ -n "$ARCHIVE_PID" ]]; then
    kill "$ARCHIVE_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

q() { psql -qtAX "$PG_CONN" -c "$1"; }
fail() {
  echo "FAILED: $*"
  echo "--- archive log, last 40 lines"
  tail -40 "$WORK/archive.log" || true
  exit 1
}

echo "=== 1. the pre-fork archive"
psql -q -v ON_ERROR_STOP=1 "$PG_CONN" -f "$FIXTURE/prefork-state.sql"
q "SELECT '  ' || chain_status || ' ' || count(*) FROM blocks GROUP BY chain_status ORDER BY 1;"

BEFORE_PENDING=$(q "SELECT count(*) FROM blocks WHERE chain_status='pending';")
[[ "$BEFORE_PENDING" -gt 0 ]] \
  || fail "the fixture left no stranded blocks, so there is nothing to repair"

FORK_STATUS=$(q "SELECT chain_status FROM blocks WHERE state_hash='$FORK_HASH';")
[[ "$FORK_STATUS" == "pending" ]] \
  || fail "the fork block is '$FORK_STATUS', expected pending"

echo
echo "=== 2. the schema upgrade"
# The upgrade prints a row per column it adds and a notice per column that is
# already there, which buries everything after it. ON_ERROR_STOP still aborts on
# a real failure, and the output is kept for when that happens.
psql -q -v ON_ERROR_STOP=1 "$PG_CONN" \
  -f src/app/archive/upgrade_to_mesa.sql > "$WORK/upgrade.log" 2>&1 \
  || { echo "the schema upgrade failed:"; tail -20 "$WORK/upgrade.log"; exit 1; }
HAVE_TABLE=$(q "SELECT to_regclass('hardfork_state') IS NOT NULL;")
[[ "$HAVE_TABLE" == "t" ]] \
  || fail "the upgrade did not create hardfork_state"
echo "  migration_history: $(q "SELECT protocol_version || ' ' || migration_version || ' ' || status FROM migration_history;")"

echo
echo "=== 3. the archive, in automode"
$ARCHIVE_APP run \
  --postgres-uri "$PG_CONN" \
  --server-port "$ARCHIVE_PORT" \
  --hardfork-confirmations "$CONFIRMATIONS" \
  > "$WORK/archive.log" 2>&1 &
ARCHIVE_PID=$!
for _ in $(seq 1 120); do
  grep -q "Archive process ready" "$WORK/archive.log" 2>/dev/null && break
  kill -0 "$ARCHIVE_PID" 2>/dev/null || fail "the archive exited during startup"
  sleep 1
done
grep -q "Archive process ready" "$WORK/archive.log" \
  || fail "the archive never became ready"

echo
echo "=== 4. the fork configuration, over the archive RPC -- accepted here"
$CLIENT_APP advanced send-hardfork-config \
  "$FIXTURE/hardfork-config.json" \
  --archive-address "127.0.0.1:${ARCHIVE_PORT}"

echo
echo "=== 5. recorded, but no history rewritten yet"
# The repair runs on its own loop, once a minute, and decides each pass whether
# it is safe to proceed. Waiting out several passes makes this a settled
# position rather than a race with the first one.
sleep 75

# The row is the acceptance: the archive has the fork on its books and keeps it
# across restarts. finalized_at is what step 7 stamps, and means the repair ran
# as well.
RECORDED=$(q "SELECT count(*) FROM hardfork_state WHERE id=1;")
[[ "$RECORDED" == "1" ]] \
  || fail "the archive did not record the fork it was sent"
echo "  accepted:  hardfork_state has the fork on record"

SETTLED_AT=$(q "SELECT coalesce(finalized_at::text,'') FROM hardfork_state WHERE id=1;")
[[ -z "$SETTLED_AT" ]] \
  || fail "the boundary was settled at ${SETTLED_AT}, before the post-fork genesis arrived"

STILL_PENDING=$(q "SELECT count(*) FROM blocks WHERE chain_status='pending';")
[[ "$STILL_PENDING" == "$BEFORE_PENDING" ]] \
  || fail "the archive rewrote history before the post-fork genesis arrived (${BEFORE_PENDING} pending, now ${STILL_PENDING})"
echo "  unchanged: $STILL_PENDING blocks still pending, as before"

grep -q "post-fork chain's genesis block has not arrived" "$WORK/archive.log" \
  || fail "the archive did not say it was waiting for the post-fork genesis"
echo "  waiting because:"
grep -o "Not settling the fork boundary yet.*" "$WORK/archive.log" | tail -1 | sed 's/^/    /'

echo
echo "=== 6. the post-fork daemon feeds in its genesis block"
psql -q -v ON_ERROR_STOP=1 "$PG_CONN" -c "INSERT INTO blocks SELECT * FROM saved_fork_genesis;"

echo
echo "=== 7. now the repair runs and the boundary settles"
for _ in $(seq 1 60); do
  SETTLED_AT=$(q "SELECT coalesce(finalized_at::text,'') FROM hardfork_state WHERE id=1;")
  [[ -n "$SETTLED_AT" ]] && break
  sleep 5
done
[[ -n "$SETTLED_AT" ]] \
  || fail "the boundary never settled; finalized_at is still NULL"
echo "  settled at $SETTLED_AT"

q "SELECT '  ' || chain_status || ' ' || count(*) FROM blocks GROUP BY chain_status ORDER BY 1;"

# The band is gone: nothing at or below the fork is still pending, and the
# canonical chain runs unbroken from height 1 to the fork block.
LEFT_PENDING=$(q "SELECT count(*) FROM blocks WHERE chain_status='pending' AND height <= $FORK_HEIGHT;")
[[ "$LEFT_PENDING" == "0" ]] \
  || fail "${LEFT_PENDING} blocks at or below the fork are still pending"

CANONICAL=$(q "SELECT count(*) FROM blocks WHERE chain_status='canonical' AND height <= $FORK_HEIGHT;")
[[ "$CANONICAL" == "$FORK_HEIGHT" ]] \
  || fail "expected ${FORK_HEIGHT} canonical blocks up to the fork, got ${CANONICAL}"

FORK_STATUS=$(q "SELECT chain_status FROM blocks WHERE state_hash='$FORK_HASH';")
[[ "$FORK_STATUS" == "canonical" ]] \
  || fail "the fork block is '$FORK_STATUS', expected canonical"

# The post-fork genesis must survive the repair. It sits above the fork block,
# and without the boundary slot the repair takes from it, the orphaning has no
# upper bound and sweeps up the new chain's own first block.
#
# The blocks the pre-fork chain produced above the fork block are the window
# between slot_tx_end and slot_chain_end. The new chain does not build on them,
# so they belong off the canonical chain and stay there.
ABOVE_CANONICAL=$(q "SELECT count(*) FROM blocks WHERE height > $FORK_HEIGHT AND chain_status='canonical';")
[[ "$ABOVE_CANONICAL" == "1" ]] \
  || fail "expected only the post-fork genesis to be canonical above the fork, got ${ABOVE_CANONICAL}"

ABOVE_PENDING=$(q "SELECT count(*) FROM blocks WHERE height > $FORK_HEIGHT AND chain_status='pending';")
[[ "$ABOVE_PENDING" == "0" ]] \
  || fail "${ABOVE_PENDING} abandoned pre-fork blocks above the fork are still pending"

echo
grep -o "Settled the fork boundary.*" "$WORK/archive.log" | tail -1 | sed 's/^/  /'
echo
echo "SUCCEEDED"
