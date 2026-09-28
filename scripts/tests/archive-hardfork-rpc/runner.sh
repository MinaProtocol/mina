#!/usr/bin/env bash
# ok() always succeeds, so `A && ok … || fail …` is an if-then-else here.
# shellcheck disable=SC2015
#
# The pre-fork side of the archive hand-over: a daemon announces the fork over
# the archive RPC, and the archive records it and, if asked, stops.
#
#   1. a 4.0.0 database, which has no hardfork_state: the announcement is
#      refused, and the refusal names upgrade.sql
#   2. upgrade.sql, run before the fork: the announcement is recorded, a
#      repeat is a no-op, and a different fork block is refused
#   3. --hardfork-handling exit: the archive stops once the fork is recorded
#   4. --hardfork-handling migrate-exit: it re-runs upgrade.sql, then stops
#
# Needs docker, psql on the PATH (migrate-exit shells out to it), and:
#   dune build src/app/archive/archive.exe src/app/cli/src/mina_testnet_signatures.exe
#
# Usage:
#   scripts/tests/archive-hardfork-rpc/runner.sh [--keep] [--pg-port PORT]
#
set -uo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${HERE}/../../.." && pwd)"

PG_PORT="${PG_PORT:-55441}"
PG_CONTAINER="${PG_CONTAINER:-archive-hardfork-rpc-test-pg}"
KEEP=0
ARCHIVE_BIN="${ARCHIVE_BIN:-${ROOT}/_build/default/src/app/archive/archive.exe}"
CLIENT_BIN="${CLIENT_BIN:-${ROOT}/_build/default/src/app/cli/src/mina_testnet_signatures.exe}"
ARCHIVE_PORT="${ARCHIVE_PORT:-3188}"
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

DB=archive_hardfork_rpc
CONN="postgresql://postgres:pw@127.0.0.1:${PG_PORT}/${DB}"

say()  { printf '\n=== %s\n' "$*"; }
fail() { printf 'FAIL: %s\n' "$*" >&2; FAILED=1; }
ok()   { printf '    ok  %s\n' "$*"; }
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
    exit 2
  fi
done
command -v psql >/dev/null || { echo "psql is required" >&2; exit 2; }

psql_() { docker exec -e PGPASSWORD=pw -i "$PG_CONTAINER" psql -qtAX -U postgres -d "$DB" "$@"; }

fork_config() {
  cat > "${WORK}/$1.json" <<JSON
{ "proof": { "fork": { "state_hash": "$2", "blockchain_length": $3, "global_slot_since_genesis": $3 } } }
JSON
}

start_archive() {
  local log="${WORK}/$1.log"; shift
  "$ARCHIVE_BIN" run --postgres-uri "$CONN" --server-port "$ARCHIVE_PORT" \
    --schema-upgrade-script "${ROOT}/src/app/archive/upgrade.sql" "$@" \
    > "$log" 2>&1 &
  ARCHIVE_PID=$!
  for _ in $(seq 1 60); do
    grep -q "Archive process ready" "$log" 2>/dev/null && return 0
    kill -0 "$ARCHIVE_PID" 2>/dev/null || break
    sleep 1
  done
  echo "archive did not become ready:"; tail -20 "$log"; exit 1
}

stop_archive() {
  kill "$ARCHIVE_PID" 2>/dev/null; wait "$ARCHIVE_PID" 2>/dev/null; ARCHIVE_PID=""
}

# Waits for the archive to exit by itself; sets CODE to its exit status.
wait_exit() {
  CODE="running"
  for _ in $(seq 1 30); do
    if ! kill -0 "$ARCHIVE_PID" 2>/dev/null; then
      wait "$ARCHIVE_PID"; CODE=$?; ARCHIVE_PID=""; return
    fi
    sleep 1
  done
}

send() {
  "$CLIENT_BIN" advanced send-hardfork-config "${WORK}/$1.json" \
    --archive-address "127.0.0.1:${ARCHIVE_PORT}" > "${WORK}/send-$1.out" 2>&1
}

recorded_hash() { psql_ -c "SELECT fork_state_hash FROM hardfork_state;"; }

say "starting postgres"
docker rm -f "$PG_CONTAINER" >/dev/null 2>&1
docker run -d --name "$PG_CONTAINER" -e POSTGRES_PASSWORD=pw \
  -p "${PG_PORT}:5432" postgres:14 >/dev/null || { echo "could not start postgres"; exit 1; }
CREATED=0
for _ in $(seq 1 90); do
  if docker exec -e PGPASSWORD=pw "$PG_CONTAINER" createdb -U postgres "$DB" >/dev/null 2>&1; then
    CREATED=1; break
  fi
  sleep 1
done
[[ "$CREATED" -eq 1 ]] || { echo "postgres never became usable" >&2; exit 1; }

# A production 4.0.0 database was created before hardfork_state existed.
docker exec -e PGPASSWORD=pw -i "$PG_CONTAINER" psql -q -U postgres -d "$DB" \
  < "${ROOT}/src/app/archive/create_schema.sql" >/dev/null 2>&1 \
  || { echo "schema creation failed"; exit 1; }
psql_ -c "DROP TABLE hardfork_state; DROP TYPE hardfork_source;" >/dev/null

fork_config fork_a FORK_A 10
fork_config fork_b FORK_B 11

# ------------------------------------------------------------------------- 1
say "1. a 4.0.0 database refuses the announcement, and says why"
start_archive keep1
if send fork_a; then
  fail "the send succeeded against a database with no hardfork_state"
elif grep -q "run upgrade.sql" "${WORK}/send-fork_a.out"; then
  ok "refused, naming upgrade.sql"
else
  fail "refused without naming upgrade.sql:"; sed 's/^/      /' "${WORK}/send-fork_a.out"
fi
kill -0 "$ARCHIVE_PID" 2>/dev/null && ok "archive still running" || fail "archive died"
stop_archive

# ------------------------------------------------------------------------- 2
say "2. after upgrade.sql the announcement is recorded"
psql "$CONN" -v ON_ERROR_STOP=1 -q -f "${ROOT}/src/app/archive/upgrade.sql" \
  > "${WORK}/upgrade.log" 2>&1 || { fail "upgrade.sql failed"; cat "${WORK}/upgrade.log"; }
MIGRATION=$(psql_ -c "SELECT protocol_version || ' ' || status FROM migration_history ORDER BY commit_start_at DESC LIMIT 1;")
[[ "$MIGRATION" == "5.0.0 applied" ]] && ok "migration_history: ${MIGRATION}" \
  || fail "expected migration_history '5.0.0 applied', got '${MIGRATION}'"

start_archive keep2
send fork_a && ok "sent" || { fail "send failed"; cat "${WORK}/send-fork_a.out"; }
[[ "$(recorded_hash)" == "FORK_A" ]] && ok "recorded FORK_A" || fail "hardfork_state holds '$(recorded_hash)'"

send fork_a && ok "a repeat is accepted" || fail "a repeat was refused"
[[ "$(psql_ -c 'SELECT count(*) FROM hardfork_state;')" == "1" ]] && ok "still one row" || fail "more than one row"

send fork_b
[[ "$(recorded_hash)" == "FORK_A" ]] && ok "a different fork block does not replace it" \
  || fail "FORK_B replaced FORK_A"
grep -q "already records a fork" "${WORK}/keep2.log" && ok "the disagreement is logged" \
  || fail "no log line for the disagreement"
kill -0 "$ARCHIVE_PID" 2>/dev/null && ok "keep-running keeps running" || fail "archive stopped"
stop_archive

# ------------------------------------------------------------------------- 3
say "3. --hardfork-handling exit stops once the fork is recorded"
start_archive exit --hardfork-handling exit
send fork_a || fail "send failed"
wait_exit
[[ "$CODE" == "0" ]] && ok "exited 0" || fail "expected exit 0, got ${CODE}"

# ------------------------------------------------------------------------- 4
say "4. --hardfork-handling migrate-exit runs upgrade.sql, then stops"
start_archive migrate --hardfork-handling migrate-exit
send fork_a || fail "send failed"
wait_exit
[[ "$CODE" == "0" ]] && ok "exited 0" || { fail "expected exit 0, got ${CODE}"; tail -20 "${WORK}/migrate.log"; }
grep -q "Upgraded the archive schema" "${WORK}/migrate.log" && ok "upgrade.sql ran" \
  || fail "no sign that upgrade.sql ran"

if [[ "$FAILED" -eq 0 ]]; then
  say "PASS"
else
  say "FAIL"
  exit 1
fi
