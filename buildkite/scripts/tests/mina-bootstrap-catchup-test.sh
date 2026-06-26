#!/bin/bash

# End-to-end integration test for `mina-bootstrap catchup`.
#
# Dogfoods the full operator flow against a live, real network:
#   1. mina-bootstrap archive  -> download + restore a real archive dump
#   2. mina-bootstrap catchup  -> backfill the forward diff from the bucket
#   3. assert no gap + every expected block inserted (the integration-tagged
#      Go test TestCatchupNoGap)
#
# Runs inside the mina toolchain container with a sibling Postgres container
# (both on the host network), wired up by RunWithPostgres.runInDockerWithPostgresConn.
# This is a heavy, manually-triggered job (BootstrapRelease scope only).
#
# Tunables (env):
#   NETWORK                 network to exercise (default: devnet)
#   CATCHUP_BLOCKS          bounded forward window to backfill (default: 25)
#   POSTGRES_URI            base server URI, no db (set by RunWithPostgres)
#   PG_CONN                 full URI incl. /archive (set by RunWithPostgres)

set -euo pipefail

NETWORK="${NETWORK:-devnet}"
CATCHUP_BLOCKS="${CATCHUP_BLOCKS:-25}"
PG_BASE="${POSTGRES_URI:-postgres://postgres:postgres@localhost:5432}"
PG_ADMIN_URI="${PG_BASE}/postgres"
PG_ARCHIVE_URI="${PG_CONN:-${PG_BASE}/archive}"

echo "--- Marking the checkout safe for git"
# The container user does not own /workdir, so git refuses to operate on it
# ("dubious ownership"), which breaks `go build` VCS stamping and the dune
# mina_version git stamp. Mark everything (repo + submodules) safe.
git config --global --add safe.directory '*'

echo "--- Ensuring psql client is available"
if ! command -v psql >/dev/null 2>&1; then
  sudo apt-get update -y && sudo apt-get install -y postgresql-client
fi

echo "--- Provisioning Go >= 1.21"
GO_BIN="$(scripts/ensure-go.sh)"
echo "Using Go: $("$GO_BIN" version)"

echo "--- Building mina-bootstrap"
make build-mina-bootstrap
BOOTSTRAP_BIN="$(pwd)/_build/mina-bootstrap"

echo "--- Building mina-archive-blocks"
# shellcheck disable=SC1090
source ~/.profile
dune build src/app/archive_blocks/archive_blocks.exe
ARCHIVE_BLOCKS_BIN="$(pwd)/_build/default/src/app/archive_blocks/archive_blocks.exe"

echo "--- Downloading + extracting a recent ${NETWORK} archive dump"
WORK_DIR="$(pwd)/_build/bootstrap-it"
mkdir -p "$WORK_DIR"
# Dumps are hourly; the most recent midnight dump may not exist yet early in the
# UTC day, so walk back a few days until a download succeeds.
DUMP_OK=false
for offset in 0 1 2 3; do
  DATE="$(date -u -d "-${offset} day" +%Y-%m-%d)"
  echo "Trying ${NETWORK} dump for ${DATE} 0000 ..."
  if "$BOOTSTRAP_BIN" archive \
       --network "$NETWORK" \
       --date "$DATE" \
       --work-dir "$WORK_DIR" \
       --skip-pg; then
    DUMP_OK=true
    break
  fi
  echo "No dump for ${DATE}, trying an earlier day."
done
if [ "$DUMP_OK" != true ]; then
  echo "Could not find a recent ${NETWORK} archive dump to restore" >&2
  exit 1
fi

SQL_FILE="$(find "$WORK_DIR" -maxdepth 1 -name '*.sql' | head -n1)"
if [ -z "$SQL_FILE" ]; then
  echo "No .sql file extracted into ${WORK_DIR}" >&2
  exit 1
fi
echo "Restoring from $SQL_FILE"

# Prod dumps are produced by pg_dump on PG 17; the CI Postgres is 12.x. Strip the
# two settings PG 12 rejects (see the mina-dev archive-dump notes):
#   - `SET transaction_timeout = 0;`  (PG 17 only)
#   - `LOCALE_PROVIDER = libc LOCALE = 'en_US.UTF-8'`  (PG 15+ only)
sed -i -e '/^SET transaction_timeout/d' \
       -e "s/ LOCALE_PROVIDER = libc LOCALE = 'en_US.UTF-8'//" \
       "$SQL_FILE"

echo "--- Restoring dump into Postgres (dropping any pre-existing archive db)"
psql "$PG_ADMIN_URI" -v ON_ERROR_STOP=1 -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname='archive' AND pid<>pg_backend_pid();"
psql "$PG_ADMIN_URI" -v ON_ERROR_STOP=1 -c "DROP DATABASE IF EXISTS archive;"
# The dump re-creates the `archive` database and \connect's into it, so restore
# against the admin (postgres) db.
psql "$PG_ADMIN_URI" -f "$SQL_FILE"

echo "--- Running catchup integration test (no-gap + every-block-inserted)"
cd src/app/bootstrap

# Wire the test to this network's restored DB. The test reads
# BOOTSTRAP_TEST_<NET>_PG_URI; map NETWORK -> the right env var.
NET_UPPER="$(echo "$NETWORK" | tr '[:lower:]' '[:upper:]')"
export "BOOTSTRAP_TEST_${NET_UPPER}_PG_URI=${PG_ARCHIVE_URI}"
export BOOTSTRAP_TEST_ARCHIVE_BLOCKS_BIN="$ARCHIVE_BLOCKS_BIN"
export BOOTSTRAP_TEST_CATCHUP_BLOCKS="$CATCHUP_BLOCKS"

"$GO_BIN" test -tags integration ./cmd/... -run TestCatchupNoGap -v
