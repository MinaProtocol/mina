#!/bin/bash
set -oe pipefail -x

function cleanup
{
  echo "Cleaning up mina processes..."
  # Prefer terminating only processes in this script's process group,
  # instead of killing all mina/mina-archive processes on the host.
  pgid=$(ps -o pgid= $$ 2>/dev/null | tr -d ' ')
  if [ -n "$pgid" ]; then
    echo "Sending SIGTERM to process group $pgid..."
    kill -TERM -"${pgid}" 2>/dev/null || true
    sleep 5
    echo "Sending SIGKILL to remaining processes in process group $pgid..."
    kill -KILL -"${pgid}" 2>/dev/null || true
  fi

  # Drop test databases if they exist
  if command -v psql &>/dev/null; then
    for db in $(psql -U postgres -t -c "SELECT datname FROM pg_database WHERE datname LIKE 'test_%';" 2>/dev/null); do
      db=$(echo "$db" | xargs)
      if [ -n "$db" ]; then
        echo "Dropping test database: $db"
        psql -U postgres -c "DROP DATABASE IF EXISTS \"$db\";" 2>/dev/null || true
      fi
    done
  fi
}

trap cleanup EXIT

TEST_NAME="$1"

if [[ "${TEST_NAME:0:15}" == "block-prod-prio" ]] && [[ "$RUN_OPT_TESTS" == "" ]]; then
  echo "Skipping $TEST_NAME"
  exit 0
fi

git config --global --add safe.directory /workdir

# Set up PostgreSQL for archive node tests
if command -v pg_isready &>/dev/null; then
  if ! pg_isready -q 2>/dev/null; then
    echo "Starting PostgreSQL..."
    # shellcheck disable=SC2046
    pg_ctlcluster $(pg_lsclusters -h | head -1 | awk '{print $1, $2}') start || true
  fi
  echo "PostgreSQL is ready"
fi

source buildkite/scripts/debian/update.sh --verbose

# Install all required Debian packages
source buildkite/scripts/debian/install.sh "mina-devnet-generic,mina-archive,mina-test-executive"

MINA_BIN="/usr/local/bin/mina"
ARCHIVE_BIN="/usr/local/bin/mina-archive"

echo "Verifying binary paths..."
ls -la "$MINA_BIN" "$ARCHIVE_BIN"

mina-test-executive app "$TEST_NAME" \
  --mina-image "$MINA_BIN" \
  --archive-image "$ARCHIVE_BIN" \
  | tee "$TEST_NAME.local.test.log" \
  | mina-logproc -i inline -f '!(.level in ["Debug", "Spam"])'

