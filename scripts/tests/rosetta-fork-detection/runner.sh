#!/usr/bin/env bash
#
# Rosetta --watch-schema-era: when does the pre-fork Rosetta stand down?
#
#   a. a 4.0.0 database with neither table: serve
#   b. upgrade.sql run early, no fork recorded: serve
#   c. fork recorded, schema still 4.0.0: serve
#   d. fork recorded, schema moved to 5.0.0: exit 0
#
# Rosetta asks a daemon only for the network id on this path, so a stub
# answers that.
#
# Needs docker, python3, curl, and:
#   dune build src/app/rosetta/rosetta_testnet_signatures.exe

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"

CT=${CT:-rosetta-fork-detection-test}
PGPORT=${PGPORT:-55461}
GQLPORT=${GQLPORT:-3097}
RPORT=${RPORT:-3096}
ROSETTA=${ROSETTA:-$ROOT/_build/default/src/app/rosetta/rosetta_testnet_signatures.exe}
CONN="postgres://postgres:postgres@127.0.0.1:${PGPORT}/archive"
WORK=$(mktemp -d)
FAILURES=0

# Longer than two passes of the watcher's 10s interval.
SETTLE=25

RPID=""; GPID=""
cleanup() {
  [[ -n "$RPID" ]] && kill "$RPID" 2>/dev/null
  [[ -n "$GPID" ]] && kill "$GPID" 2>/dev/null
  docker rm -f "$CT" >/dev/null 2>&1
  [[ -n "${KEEP_LOG:-}" ]] && cp "$WORK/rosetta.log" "$KEEP_LOG"; rm -rf "$WORK"
}
trap cleanup EXIT

fail() { echo "  FAIL: $*"; FAILURES=$((FAILURES + 1)); }
ok()   { echo "  ok    $*"; }

[[ -x "$ROSETTA" ]] || { echo "missing $ROSETTA -- build it first"; exit 1; }

docker rm -f "$CT" >/dev/null 2>&1
docker run -d --name "$CT" -e POSTGRES_PASSWORD=postgres -e POSTGRES_DB=archive \
  -p "$PGPORT:5432" postgres:12-alpine >/dev/null || exit 1
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
  < "$ROOT/src/app/archive/create_schema.sql" >/dev/null 2>&1
# A 4.0.0 database predates both tables.
q "DROP TABLE IF EXISTS hardfork_state; DROP TYPE IF EXISTS hardfork_source;
   DROP TABLE IF EXISTS migration_history;" >/dev/null

python3 "$HERE/gql-network-stub.py" "$GQLPORT" "mina:devnet" &
GPID=$!
sleep 1

LOG="$WORK/rosetta.log"
MINA_ROSETTA_MAX_DB_POOL_SIZE=16 \
"$ROSETTA" --archive-uri "$CONN" \
  --graphql-uri "http://127.0.0.1:${GQLPORT}/graphql" \
  --port "$RPORT" --watch-schema-era > "$LOG" 2>&1 &
RPID=$!
for _ in $(seq 1 60); do
  curl -s -o /dev/null "http://127.0.0.1:${RPORT}/" && break
  kill -0 "$RPID" 2>/dev/null || { echo "rosetta exited during startup:"; tail -10 "$LOG"; exit 1; }
  sleep 1
done

expect_serving() {
  sleep "$SETTLE"
  if kill -0 "$RPID" 2>/dev/null; then ok "$1: still serving"
  else fail "$1: rosetta stopped"; tail -5 "$LOG"; exit 1; fi
}

echo "=== a. a 4.0.0 database with neither table"
expect_serving "no tables"

echo "=== b. upgrade.sql run early, no fork recorded"
q "CREATE TABLE migration_history (
     commit_start_at timestamptz NOT NULL DEFAULT now() PRIMARY KEY,
     protocol_version text NOT NULL, migration_version text NOT NULL,
     description text NOT NULL, status text NOT NULL);
   INSERT INTO migration_history (protocol_version, migration_version, description, status)
   VALUES ('5.0.0', '0.0.2', 'test', 'applied');" >/dev/null
expect_serving "schema 5.0.0, no fork"

echo "=== c. fork recorded, schema still 4.0.0"
q "DELETE FROM migration_history;
   INSERT INTO migration_history (protocol_version, migration_version, description, status)
   VALUES ('4.0.0', '0.0.6', 'test', 'applied');
   CREATE TYPE hardfork_source AS ENUM ('daemon_config', 'fork_genesis', 'operator');
   CREATE TABLE hardfork_state (
     id int PRIMARY KEY DEFAULT 1 CHECK (id = 1), fork_state_hash text NOT NULL,
     fork_blockchain_length bigint NOT NULL, fork_global_slot bigint NOT NULL,
     config_json text NOT NULL, source hardfork_source NOT NULL,
     announced_at timestamptz NOT NULL DEFAULT now(), finalized_at timestamptz);
   INSERT INTO hardfork_state (fork_state_hash, fork_blockchain_length, fork_global_slot, config_json, source)
   VALUES ('FORK', 10, 10, '{}', 'daemon_config');" >/dev/null
expect_serving "fork recorded, schema 4.0.0"

echo "=== d. fork recorded, schema moved to 5.0.0"
q "INSERT INTO migration_history (protocol_version, migration_version, description, status)
   VALUES ('5.0.0', '0.0.2', 'test', 'applied');" >/dev/null
code=running
for _ in $(seq 1 "$SETTLE"); do
  if ! kill -0 "$RPID" 2>/dev/null; then wait "$RPID"; code=$?; RPID=""; break; fi
  sleep 1
done
if [[ "$code" == "0" ]]; then ok "exited 0"; else fail "expected exit 0, got $code"; fi
if grep -q "Standing down" "$LOG"; then
  ok "$(grep -o 'Standing down[^"]*' "$LOG" | head -1 | cut -c1-110)"
else
  fail "no stand-down line in the log"
fi

echo
if [[ "$FAILURES" -eq 0 ]]; then echo "=== PASS"; else echo "=== FAIL ($FAILURES)"; exit 1; fi
