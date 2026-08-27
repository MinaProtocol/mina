#!/usr/bin/env bash
#
# Drives the archive's hard fork hand-over end to end, without a fork.
#
# The archive learns about a fork from exactly one message: the runtime
# configuration a daemon generated for it. That makes the whole hand-over
# testable by sending the same message by hand -- which is what
# `mina advanced send-hardfork-config` exists for.
#
# The flow:
#
#   1. a database on the pre-fork schema, seeded with the boundary a fork
#      strands: a band of pending blocks the archive can no longer canonicalise
#   2. a running archive, in automode
#   3. the configuration, sent over the archive RPC
#   4. the archive records it and *declines* to repair: the hand-over begins
#      with the genesis block, and this seed gives it no ledger to build one
#   5. the post-fork genesis block arrives another way, which is enough -- the
#      hand-over needs the block to exist, not to have built it itself
#   6. now the band heals -- pending becomes canonical on the chain to the fork
#      block, and orphaned off it
#
# Usage:
#   scripts/tests/archive-automode/runner.sh [--keep] [--pg-port PORT]
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../.." && pwd)"

PG_PORT="${PG_PORT:-55440}"
PG_CONTAINER="${PG_CONTAINER:-archive-automode-test-pg}"
KEEP=0
ARCHIVE_BIN="${ARCHIVE_BIN:-${ROOT}/_build/default/src/app/archive/archive.exe}"
CLIENT_BIN="${CLIENT_BIN:-${ROOT}/_build/default/src/app/cli/src/mina_testnet_signatures.exe}"
ARCHIVE_PORT="${ARCHIVE_PORT:-3187}"
WORK="$(mktemp -d)"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --keep) KEEP=1; shift;;
    --pg-port) PG_PORT="$2"; shift 2;;
    --archive-bin) ARCHIVE_BIN="$2"; shift 2;;
    --client-bin) CLIENT_BIN="$2"; shift 2;;
    *) echo "unknown option: $1" >&2; exit 2;;
  esac
done

DB=archive_automode
CONN="postgresql://postgres:pw@127.0.0.1:${PG_PORT}/${DB}"

say()  { printf '\n=== %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; FAILED=1; }
FAILED=0

cleanup() {
  [[ -n "${ARCHIVE_PID:-}" ]] && kill "$ARCHIVE_PID" 2>/dev/null
  if [[ "$KEEP" -eq 0 ]]; then
    docker rm -f "$PG_CONTAINER" >/dev/null 2>&1
    rm -rf "$WORK"
  else
    echo "kept: container ${PG_CONTAINER}, work dir ${WORK}"
  fi
}
trap cleanup EXIT

for bin in "$ARCHIVE_BIN" "$CLIENT_BIN"; do
  if [[ ! -x "$bin" ]]; then
    echo "missing binary: $bin" >&2
    echo "build with: dune build src/app/archive/archive.exe src/app/cli/src/mina_testnet_signatures.exe" >&2
    exit 2
  fi
done

psql_() { docker exec -e PGPASSWORD=pw -i "$PG_CONTAINER" psql -qtAX -U postgres -d "$DB" "$@"; }

# ---------------------------------------------------------------- 1. database
say "starting postgres"
docker rm -f "$PG_CONTAINER" >/dev/null 2>&1
docker run -d --name "$PG_CONTAINER" -e POSTGRES_PASSWORD=pw \
  -p "${PG_PORT}:5432" postgres:14 >/dev/null || { echo "could not start postgres"; exit 1; }

# postgres:14 runs initdb against a temporary server and then restarts, so
# pg_isready answers before the server is really up. Retrying createdb is what
# proves it: it only succeeds once the final server is accepting connections.
CREATED=0
for _ in $(seq 1 90); do
  if docker exec -e PGPASSWORD=pw "$PG_CONTAINER" createdb -U postgres "$DB" >/dev/null 2>&1; then
    CREATED=1; break
  fi
  sleep 1
done
[[ "$CREATED" -eq 1 ]] || { echo "postgres never became usable" >&2; exit 1; }

say "creating the schema"
docker exec -e PGPASSWORD=pw -i "$PG_CONTAINER" psql -q -U postgres -d "$DB" \
  < "${ROOT}/src/app/archive/create_schema.sql" >/dev/null 2>&1 \
  || { echo "schema creation failed"; exit 1; }

say "seeding the boundary a fork strands"
docker exec -e PGPASSWORD=pw -i "$PG_CONTAINER" psql -q -U postgres -d "$DB" \
  < "${HERE}/seed.sql" >/dev/null || { echo "seed failed"; exit 1; }

echo "chain_status before:"
psql_ -c "SELECT chain_status, count(*) FROM blocks GROUP BY 1 ORDER BY 1;" | sed 's/^/    /'

BEFORE_PENDING=$(psql_ -c "SELECT count(*) FROM blocks WHERE chain_status='pending';")
[[ "$BEFORE_PENDING" == "7" ]] || fail "expected 7 pending blocks to start, got ${BEFORE_PENDING}"

# ---------------------------------------------------------------- 2. config
# Only the fork stanza matters for the repair. The ledger stanzas would matter
# for the genesis block and accounts, which need a real ledger and are out of
# scope here.
cat > "${WORK}/fork_config.json" <<'JSON'
{
  "proof": {
    "fork": {
      "state_hash": "B_010",
      "blockchain_length": 10,
      "global_slot_since_genesis": 10
    }
  }
}
JSON

# ---------------------------------------------------------------- 3. archive
say "starting the archive in automode"
# --hardfork-confirmations 0: the seeded chain stops at the fork block, so it has
# no confirmations above it. A real fork accumulates them during the empty-block
# window; here the point is the repair, not the threshold.
"$ARCHIVE_BIN" run \
  --postgres-uri "$CONN" \
  --server-port "$ARCHIVE_PORT" \
  --hardfork-confirmations 0 \
  > "${WORK}/archive.log" 2>&1 &
ARCHIVE_PID=$!

for _ in $(seq 1 60); do
  grep -q "Archive process ready" "${WORK}/archive.log" 2>/dev/null && break
  kill -0 "$ARCHIVE_PID" 2>/dev/null || { echo "archive died:"; tail -20 "${WORK}/archive.log"; exit 1; }
  sleep 1
done
grep -q "Archive process ready" "${WORK}/archive.log" || {
  echo "archive did not become ready:"; tail -20 "${WORK}/archive.log"; exit 1; }
echo "    ready (pid ${ARCHIVE_PID})"

# ---------------------------------------------------------------- 4. the message
say "sending the fork configuration, as a daemon would"
"$CLIENT_BIN" advanced send-hardfork-config \
  "${WORK}/fork_config.json" \
  --archive-address "127.0.0.1:${ARCHIVE_PORT}" 2>&1 | sed 's/^/    /'

# ------------------------------------------------- 5. it must decline, for now
say "the archive should record the fork but decline to repair it"
# Long enough for several passes of the finaliser's 60s loop, so this is a
# settled refusal rather than a race.
sleep 75

# The fork is on the books -- a row exists -- but the repair has not run, so
# finalized_at is still NULL.
RECORDED=$(psql_ -c "SELECT count(*) FROM hardfork_state WHERE id=1;" 2>/dev/null)
[[ "$RECORDED" == "1" ]] \
  || fail "the archive did not record the fork it was sent"

SETTLED_AT=$(psql_ -c "SELECT coalesce(finalized_at::text,'') FROM hardfork_state WHERE id=1;" 2>/dev/null)
[[ -z "$SETTLED_AT" ]] \
  || fail "the boundary was settled at ${SETTLED_AT}, before the post-fork genesis arrived"

STILL_PENDING=$(psql_ -c "SELECT count(*) FROM blocks WHERE chain_status='pending';")
[[ "$STILL_PENDING" == "7" ]] \
  || fail "the archive repaired before the post-fork genesis arrived (${STILL_PENDING} pending)"

# The hand-over stops at its first step, which is the genesis block, and that
# step needs a ledger this seed does not provide. So the refusal names the
# ledger rather than the block: the archive is not waiting for someone to
# deliver a genesis, it is waiting for the means to build one.
if grep -q "waiting on the genesis ledger" "${WORK}/archive.log"; then
  echo "    declined, and said why:"
  grep -o "The hand-over is waiting on the genesis ledger.*" "${WORK}/archive.log" \
    | tail -1 | cut -c1-140 | sed 's/^/      /'
else
  fail "the archive did not say it was waiting for the genesis ledger"
fi

# ------------------------------------------------- 6. the genesis block arrives
say "the post-fork genesis block arrives, corroborating the fork block"
docker exec -e PGPASSWORD=pw -i "$PG_CONTAINER" psql -q -U postgres -d "$DB" \
  < "${HERE}/fork_genesis.sql" >/dev/null || { echo "genesis insert failed"; exit 1; }

say "watching the boundary settle"
SETTLED=0
for _ in $(seq 1 40); do
  SETTLED_AT=$(psql_ -c "SELECT coalesce(finalized_at::text,'') FROM hardfork_state WHERE id=1;" 2>/dev/null)
  if [[ -n "$SETTLED_AT" ]]; then SETTLED=1; break; fi
  sleep 2
done

echo "hardfork_state:"
psql_ -c "SELECT source, fork_state_hash, fork_blockchain_length, finalized_at FROM hardfork_state;" | sed 's/^/    /'
echo "chain_status after:"
psql_ -c "SELECT chain_status, count(*) FROM blocks GROUP BY 1 ORDER BY 1;" | sed 's/^/    /'
echo "per block:"
psql_ -c "SELECT height, state_hash, chain_status FROM blocks ORDER BY height, state_hash;" | sed 's/^/    /'

[[ "$SETTLED" -eq 1 ]] || fail "the boundary never settled (hardfork_state.finalized_at is still NULL)"

# The chain up to the fork block is canonical.
for h in 6 7 8 9 10; do
  ST=$(psql_ -c "SELECT chain_status FROM blocks WHERE state_hash='B_$(printf '%03d' $h)';")
  [[ "$ST" == "canonical" ]] || fail "B_$(printf '%03d' $h) is '${ST}', expected canonical"
done

# The blocks off it are orphaned, not left pending and not made canonical.
for sh in ORPHAN_007 ORPHAN_009; do
  ST=$(psql_ -c "SELECT chain_status FROM blocks WHERE state_hash='${sh}';")
  [[ "$ST" == "orphaned" ]] || fail "${sh} is '${ST}', expected orphaned"
done

AFTER_PENDING=$(psql_ -c "SELECT count(*) FROM blocks WHERE chain_status='pending';")
[[ "$AFTER_PENDING" == "0" ]] || fail "${AFTER_PENDING} blocks still pending after the repair"

# The post-fork genesis is the new chain, not something to sweep up. It carries
# a different protocol version, and the boundary slot taken from it is what
# keeps the orphaning below the fork.
GEN=$(psql_ -c "SELECT chain_status FROM blocks WHERE state_hash='FORK_GENESIS';")
[[ "$GEN" == "canonical" ]] || fail "the post-fork genesis is '${GEN}', expected canonical"

say "archive log, hard fork lines"
grep -iE "hard fork|fork boundary|settl|canonical" "${WORK}/archive.log" | tail -12 | sed 's/^/    /'

if [[ "$FAILED" -eq 0 ]]; then
  say "PASS"
else
  say "FAILURES ABOVE"
fi
exit "$FAILED"
