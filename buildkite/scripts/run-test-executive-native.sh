#!/bin/bash
set -oe pipefail -x

# Dump the job container's memory-cgroup limit, current/peak usage, and — most
# importantly — the kernel OOM-kill counter for this cgroup. If [oom_kill]
# increments across the run, the cgroup OOM-killer is what terminates the
# daemons' provers, confirming that the native daemons hit the pod's memory
# limit (whereas the docker engine's daemons run under dockerd, outside it).
# Also logs host MemTotal, to show the k8s "process sees host meminfo, not the
# cgroup cap" gap. Writes to an artifact-collected file.
MEM_DIAG_FILE=""
dump_cgroup_mem() {
  local tag="$1"
  [ -n "$MEM_DIAG_FILE" ] || return 0
  {
    echo "=== [${tag}] $(date -u +%FT%TZ) ==="
    if [ -f /sys/fs/cgroup/memory.max ]; then
      echo "cgroup=v2"
      echo "memory.max=$(cat /sys/fs/cgroup/memory.max 2>/dev/null)"
      echo "memory.current=$(cat /sys/fs/cgroup/memory.current 2>/dev/null)"
      echo "memory.peak=$(cat /sys/fs/cgroup/memory.peak 2>/dev/null)"
      echo "memory.events:"
      cat /sys/fs/cgroup/memory.events 2>/dev/null
    elif [ -f /sys/fs/cgroup/memory/memory.limit_in_bytes ]; then
      echo "cgroup=v1"
      echo "memory.limit_in_bytes=$(cat /sys/fs/cgroup/memory/memory.limit_in_bytes 2>/dev/null)"
      echo "memory.usage_in_bytes=$(cat /sys/fs/cgroup/memory/memory.usage_in_bytes 2>/dev/null)"
      echo "memory.max_usage_in_bytes=$(cat /sys/fs/cgroup/memory/memory.max_usage_in_bytes 2>/dev/null)"
      echo "memory.failcnt=$(cat /sys/fs/cgroup/memory/memory.failcnt 2>/dev/null)"
    else
      echo "cgroup=unknown"
    fi
    echo "host MemTotal: $(awk '/MemTotal/{print $2" "$3}' /proc/meminfo 2>/dev/null)"
    free -m 2>/dev/null | sed 's/^/free: /'
  } >>"$MEM_DIAG_FILE" 2>&1 || true
}

function cleanup
{
  # Capture the final memory state (incl. the cumulative OOM-kill count) before
  # tearing down the process group.
  dump_cgroup_mem "cleanup (after test)"
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
MEM_DIAG_FILE="${TEST_NAME}-cgroupmem.local.test.log"

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
  # Give the postgres role a password so the archive node can authenticate
  # over TCP (postgres:password@127.0.0.1:5432); the engine creates and drops
  # a per-test database itself.
  psql -U postgres -c "ALTER USER postgres WITH PASSWORD 'password';" 2>/dev/null || true
  echo "PostgreSQL is ready"
fi

source buildkite/scripts/debian/update.sh --verbose

# Install all required Debian packages
source buildkite/scripts/debian/install.sh "mina-devnet-generic,mina-archive-devnet,mina-test-executive"

MINA_BIN="/usr/local/bin/mina"
ARCHIVE_BIN="/usr/local/bin/mina-archive"

echo "Verifying binary paths..."
ls -la "$MINA_BIN" "$ARCHIVE_BIN"

# Record the starting memory state and sample it every 10s in the background,
# so we can see usage climb toward the cgroup limit right before a prover dies.
dump_cgroup_mem "start (before test)"
( while true; do
    sleep 10
    dump_cgroup_mem "sample"
  done ) &

mina-test-executive native "$TEST_NAME" \
  --mina-image "$MINA_BIN" \
  --archive-image "$ARCHIVE_BIN" \
  | tee "$TEST_NAME.local.test.log" \
  | mina-logproc -i inline -f '!(.level in ["Debug", "Spam"])'

