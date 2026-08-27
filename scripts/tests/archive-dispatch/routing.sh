#!/usr/bin/env bash
#
# Which archive does the dispatcher start?
#
# It answers from two facts in the database: whether a daemon has announced a
# hard fork, and which era the schema is in. Neither is enough alone.
#
# The case that forces both is the second one below. Operators upgrade the
# schema ahead of the fork -- devnet upgraded roughly six hours before its mesa
# fork -- and for that whole window the schema reads post-fork while the daemon
# is still pre-fork and still speaking the old wire format. A dispatcher that
# looked only at the schema would start the post-fork archive against it.
#
# Needs docker and a built archive_dispatch.exe.

set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
cd "$ROOT" || exit 1

CT=${CT:-archive-dispatch-routing}
PORT=${PORT:-55471}
DISPATCH=${DISPATCH:-$ROOT/_build/default/src/app/archive_dispatch/archive_dispatch.exe}
WORK=$(mktemp -d)
FAILURES=0

cleanup() { docker rm -f "$CT" >/dev/null 2>&1; rm -rf "$WORK"; }
trap cleanup EXIT

[[ -x "$DISPATCH" ]] || {
  echo "no dispatcher at $DISPATCH -- build it first:"
  echo "  dune build src/app/archive_dispatch/archive_dispatch.exe"
  exit 1
}

say() { echo; echo "=== $*"; }

say "postgres"
docker rm -f "$CT" >/dev/null 2>&1
docker run -d --name "$CT" -e POSTGRES_PASSWORD=postgres -p "$PORT:5432" \
  postgres:12-alpine >/dev/null || exit 1
for _ in $(seq 1 60); do
  docker exec -e PGPASSWORD=postgres "$CT" psql -U postgres -c 'SELECT 1' >/dev/null 2>&1 && break
  sleep 1
done

# Stand-ins for the two runtimes. The dispatcher looks for a binary named after
# however it was invoked, so both carry the name it will ask for.
mkdir -p "$WORK/runtimes/prefork" "$WORK/runtimes/postfork"
for r in prefork postfork; do
  printf '#!/bin/sh\nexit 0\n' > "$WORK/runtimes/$r/mina-archive"
  chmod +x "$WORK/runtimes/$r/mina-archive"
done

psql_() { docker exec -e PGPASSWORD=postgres "$CT" psql -q -U postgres -d "$1" -c "$2" >/dev/null 2>&1; }

# case <label> <db> <prefork|postfork|none> <fork announced: yes|no> <expected>
case_() {
  local label=$1 db=$2 schema=$3 fork=$4 expected=$5

  docker exec -e PGPASSWORD=postgres "$CT" psql -q -U postgres \
    -c "DROP DATABASE IF EXISTS $db;" >/dev/null 2>&1
  docker exec -e PGPASSWORD=postgres "$CT" createdb -U postgres "$db" >/dev/null 2>&1

  # Only the columns the dispatcher reads; it is deliberately not linked
  # against the archive's schema.
  psql_ "$db" "CREATE TABLE migration_history (protocol_version text, migration_version text, description text, status text, commit_start_at timestamptz DEFAULT now());"
  case "$schema" in
    prefork)  psql_ "$db" "INSERT INTO migration_history VALUES ('3.0.0','0.0.1','','applied');" ;;
    postfork) psql_ "$db" "INSERT INTO migration_history VALUES ('4.0.0','0.0.6','','applied');" ;;
  esac
  if [[ "$fork" == yes ]]; then
    psql_ "$db" "CREATE TABLE hardfork_state (id int PRIMARY KEY DEFAULT 1);"
    psql_ "$db" "INSERT INTO hardfork_state (id) VALUES (1);"
  fi

  cat > "$WORK/settings" <<EOF
RUNTIMES_BASE_PATH=$WORK/runtimes
PREFORK_RUNTIME=prefork
POSTFORK_RUNTIME=postfork
PREFORK_PROTOCOL_VERSION=3.0.0
POSTFORK_PROTOCOL_VERSION=4.0.0
PGCONN=postgresql://postgres:postgres@127.0.0.1:${PORT}/${db}
EOF

  local out got
  out=$(MINA_ARCHIVE_DISPATCH_CONFIG="$WORK/settings" \
        MINA_ARCHIVE_DISPATCH_DRYRUN=1 \
        "$DISPATCH" mina-archive --explain 2>&1)
  got=$(echo "$out" | grep -oE "chose *: [a-z]+|refused *: [a-z_]+" | head -1 \
        | sed -E 's/ *: */=/')

  if [[ "$got" == "$expected" ]]; then
    printf '  ok    %-40s %s\n' "$label" "$got"
  else
    printf '  FAIL  %-40s got %s, wanted %s\n' "$label" "${got:-nothing}" "$expected"
    printf '%s\n' "${out//$'\n'/$'\n'          }" | sed '1s/^/          /'
    FAILURES=$((FAILURES + 1))
  fi
}

say "routing"
case_ "no fork announced, pre-fork schema"  d1 prefork  no  "chose=prefork"
case_ "no fork announced, post-fork schema" d2 postfork no  "chose=prefork"
case_ "fork announced, pre-fork schema"     d3 prefork  yes "refused=schema_not_upgraded"
case_ "fork announced, post-fork schema"    d4 postfork yes "chose=postfork"

echo
if [[ "$FAILURES" -eq 0 ]]; then
  echo "=== PASS"
else
  echo "=== FAIL ($FAILURES)"
fi
exit "$FAILURES"
