#!/usr/bin/env bash
#
# Rosetta, on both sides of a hard fork.
#
# Two behaviours, and they pull in opposite directions. Rosetta has to keep
# answering correctly about accounts the chain never touched -- which means
# reading the genesis ledger's accounts, not concluding they hold nothing. And
# it has to stop answering the moment the schema underneath it belongs to
# another era -- because every process that opens the archive is compiled
# against era-specific types, so a stale reader does not fail, it misreads.
#
#   1. an archive whose schema matches this binary, and a chain
#   2. an account untouched since genesis: Rosetta must report its balance,
#      not zero
#   3. the schema is still this binary's era: Rosetta must carry on
#   4. the schema moves to another era: Rosetta must stand down, cleanly
#   5. the dispatcher then picks the runtime that matches
#
# No daemon. Rosetta wants one only to validate the network identifier, so a
# stub answers that and the test stays about the archive.
#
# Needs docker, python3, curl, and a built rosetta and archive_dispatch.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$ROOT" || exit 1

CT=${CT:-rosetta-automode-test}
PGPORT=${PGPORT:-55460}
GQLPORT=${GQLPORT:-3099}
RPORT=${RPORT:-3098}
ROSETTA=${ROSETTA:-$ROOT/_build/default/src/app/rosetta/rosetta_testnet_signatures.exe}
DISPATCH=${DISPATCH:-$ROOT/_build/default/src/app/archive_dispatch/archive_dispatch.exe}
CONN="postgres://postgres:postgres@127.0.0.1:${PGPORT}/archive"
WORK=$(mktemp -d)
FAILURES=0

# An account the chain never touches, and the balance only the genesis knows.
UNTOUCHED=B62qkamwHMkTvY3t9wu4Aw4LJTDJY4m6Sk48pJ2kSMtV1fxKP2SSzWq
# The default MINA token as Rosetta stringifies it. The genesis_accounts row has
# to carry this, not the tokens table's row id: the query matches the value
# Rosetta asks with.
MINA_TOKEN=wSHV2S4qX9jFsLjQo8r1BsMLH2ZRKsZx6EJd1sbozGPieEC4Jf
GENESIS_BALANCE=4242000000000

RPID=""; GPID=""
cleanup() {
  [[ -n "$RPID" ]] && kill "$RPID" 2>/dev/null
  [[ -n "$GPID" ]] && kill "$GPID" 2>/dev/null
  docker rm -f "$CT" >/dev/null 2>&1
  rm -rf "$WORK"
}
trap cleanup EXIT

fail() { echo "  FAIL: $*"; FAILURES=$((FAILURES + 1)); }

for exe in "$ROSETTA" "$DISPATCH"; do
  [[ -x "$exe" ]] || { echo "missing $exe -- build it first"; exit 1; }
done

echo "=== an archive with a chain, and one account the chain never touched"
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
  < src/app/archive/create_schema.sql >/dev/null 2>&1
docker exec -e PGPASSWORD=postgres -i "$CT" psql -q -U postgres -d archive \
  < "$HERE/seed.sql" >/dev/null 2>&1

# create_schema.sql does not create migration_history; only the upgrade does.
# Make it, so the era can be moved about later.
q "CREATE TABLE IF NOT EXISTS migration_history (
     protocol_version text, migration_version text, description text,
     status text, commit_start_at timestamptz DEFAULT now());" >/dev/null

q "INSERT INTO genesis_accounts (genesis_height, public_key, token, balance, nonce)
   VALUES (1, '$UNTOUCHED', '$MINA_TOKEN', $GENESIS_BALANCE, 0);" >/dev/null

q "SELECT '  ' || chain_status || ' ' || count(*) FROM blocks GROUP BY chain_status ORDER BY 1;"
touched=$(q "SELECT count(*) FROM accounts_accessed aa
             JOIN account_identifiers ai ON ai.id = aa.account_identifier_id
             JOIN public_keys pk ON pk.id = ai.public_key_id
             WHERE pk.value = '$UNTOUCHED';")
echo "  that account appears in $touched blocks"
[[ "$touched" == "0" ]] || fail "the account is not untouched; the test would prove nothing"

python3 "$HERE/gql-network-stub.py" "$GQLPORT" "mina:devnet" &
GPID=$!
sleep 1

start_rosetta() {  # $1 = log, $2... = extra args
  local log=$1; shift
  MINA_ROSETTA_MAX_DB_POOL_SIZE=16 \
  "$ROSETTA" --archive-uri "$CONN" \
    --graphql-uri "http://127.0.0.1:${GQLPORT}/graphql" \
    --port "$RPORT" "$@" > "$log" 2>&1 &
  RPID=$!
  for _ in $(seq 1 60); do
    curl -s -o /dev/null "http://127.0.0.1:${RPORT}/" && return 0
    kill -0 "$RPID" 2>/dev/null || { echo "  rosetta exited during startup:"; tail -10 "$log"; return 1; }
    sleep 1
  done
  return 1
}

balance_of() {
  local req
  req=$(printf '{"network_identifier":{"blockchain":"mina","network":"devnet"},"account_identifier":{"address":"%s"},"block_identifier":{"index":5}}' "$UNTOUCHED")
  curl -s -X POST "http://127.0.0.1:${RPORT}/account/balance" \
    -H 'content-type: application/json' -d "$req" \
    | python3 -c 'import json,sys
try:
    r = json.load(sys.stdin)
    print(r["balances"][0]["value"])
except Exception:
    print("no-answer")'
}

echo
echo "=== an account untouched since genesis"
start_rosetta "$WORK/a.log" || { echo "=== FAIL"; exit 1; }
got=$(balance_of)
echo "  rosetta answers: $got"
if [[ "$got" == "$GENESIS_BALANCE" ]]; then
  echo "  ok: the genesis ledger's balance, not zero"
else
  fail "expected $GENESIS_BALANCE, got $got"
fi
kill "$RPID" 2>/dev/null; wait "$RPID" 2>/dev/null; RPID=""

echo
echo "=== the schema is this binary's era: carry on"
q "DELETE FROM migration_history;" >/dev/null
q "INSERT INTO migration_history (protocol_version, migration_version, description, status)
   VALUES ('4.0.0', '0.0.6', 'test', 'applied');" >/dev/null
start_rosetta "$WORK/b.log" --watch-schema-era || { echo "=== FAIL"; exit 1; }
sleep 25
if kill -0 "$RPID" 2>/dev/null; then
  echo "  ok: still serving"
else
  fail "rosetta stood down against a schema of its own era"
fi
kill "$RPID" 2>/dev/null; wait "$RPID" 2>/dev/null; RPID=""

echo
echo "=== the schema moves to another era: stand down"
q "DELETE FROM migration_history;" >/dev/null
q "INSERT INTO migration_history (protocol_version, migration_version, description, status)
   VALUES ('3.0.0', '0.0.1', 'test', 'applied');" >/dev/null
start_rosetta "$WORK/c.log" --watch-schema-era || { echo "=== FAIL"; exit 1; }
gone=no
for _ in $(seq 1 40); do
  kill -0 "$RPID" 2>/dev/null || { gone=yes; break; }
  sleep 1
done
if [[ "$gone" == yes ]]; then
  wait "$RPID" 2>/dev/null; rc=$?
  echo "  rosetta exited, code $rc"
  [[ "$rc" == "0" ]] || fail "expected a clean exit, got $rc"
  if grep -q "Standing down" "$WORK/c.log"; then
    grep -o "Standing down.*" "$WORK/c.log" | tail -1 | cut -c1-150 | sed 's/^/  /'
  else
    fail "it stopped without saying why"
  fi
else
  fail "rosetta kept serving a schema from another era"
  kill "$RPID" 2>/dev/null
fi
RPID=""

echo
echo "=== and the dispatcher picks the runtime that matches"
mkdir -p "$WORK/runtimes/prefork" "$WORK/runtimes/postfork"
for r in prefork postfork; do
  printf '#!/bin/sh\nexit 0\n' > "$WORK/runtimes/$r/mina-rosetta"
  chmod +x "$WORK/runtimes/$r/mina-rosetta"
done
cat > "$WORK/settings" <<EOF
RUNTIMES_BASE_PATH=$WORK/runtimes
PREFORK_RUNTIME=prefork
POSTFORK_RUNTIME=postfork
PREFORK_PROTOCOL_VERSION=3.0.0
POSTFORK_PROTOCOL_VERSION=4.0.0
PGCONN=$CONN
EOF
chose=$(MINA_ARCHIVE_DISPATCH_CONFIG="$WORK/settings" MINA_ARCHIVE_DISPATCH_DRYRUN=1 \
        "$DISPATCH" mina-rosetta --explain 2>&1 \
        | grep -oE "chose *: [a-z]+" | sed -E 's/ *: */=/')
echo "  $chose"
# A fork is recorded nowhere, so the chain has not forked and the pre-fork
# runtime is right even though this schema says 3.0.0.
[[ "$chose" == "chose=prefork" ]] || fail "expected chose=prefork, got ${chose:-nothing}"

echo
if [[ "$FAILURES" -eq 0 ]]; then
  echo "=== PASS"
else
  echo "=== FAIL ($FAILURES)"
fi
exit "$FAILURES"
