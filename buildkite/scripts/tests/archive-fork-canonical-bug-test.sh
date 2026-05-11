#!/bin/bash

# archive-fork-canonical-bug-test.sh
#
# Reproduces the archive-side bug from the Bundle 5 dry-run hardfork:
# update_chain_status branch 2 mis-classifies post-fork (chain B) blocks
# as `orphaned` when they land at heights below the prefork archive's
# greatest_canonical_height.
#
# The test alcotest case lives at src/test/archive/archive_node_tests/
# archive_fork_canonical_bug_test.ml; this script just pulls the fixture,
# sets the env vars, and invokes dune.
#
# USAGE:
#   ./archive-fork-canonical-bug-test.sh <user> <password> <postgres_host_port>
#
#     user                  postgres superuser (must own CREATE DATABASE)
#     password              postgres password
#     postgres_host_port    e.g. "localhost:5432"
#
# ENV VARS:
#   FORK_BUG_FIXTURE_DIR  Local path to a pre-staged fixture folder.
#                         If unset, the fixture is fetched from the storage
#                         box (mounted at $STORAGEBOX_BASE in CI, or via
#                         rsync over ssh for local dev).
#   STORAGEBOX_BASE       Local mount of the Hetzner storage box on the CI
#                         agent. Defaults to /var/storagebox (the mount point
#                         used by buildkite/scripts/cache/manager.sh).
#   HETZNER_KEY           SSH key path for the Hetzner storage box (used when
#                         the mount isn't available, e.g. local dev).
#                         Defaults to ~/work/secrets/storagebox.key.
#   HETZNER_USER          Hetzner user. Defaults to u434410.
#   HETZNER_HOST          Hetzner host. Defaults to
#                         u434410-sub2.your-storagebox.de.
#   STORAGEBOX_FIXTURE_PATH  Path under the storage box root. Defaults to
#                         test_data/archive_fork_canonical_bug.
#
# FIXTURE LAYOUT (after staging):
#   $FORK_BUG_FIXTURE_DIR/
#     prefork_archive_dump.sql.tar.gz   (gzipped tar of pg_dump plain SQL)
#     genesis.json                       (post-fork runtime config)
#     precomputed_blocks.tar.xz          (chain B extensional blocks 6816-6819)
#
# PREREQUISITES:
#   - Run from the repo root (where dune-project lives).
#   - OPAM env available; mina_fresh switch selected by `opam config env`.
#   - postgres reachable as superuser at <postgres_host_port>.

set -euo pipefail

if [[ ! -f dune-project ]]; then
  echo "Error: must be run from repo root (where dune-project lives)." >&2
  exit 1
fi

if [[ $# -lt 3 ]]; then
  echo "Usage: $0 <user> <password> <postgres_host_port>" >&2
  exit 1
fi

user="$1"
password="$2"
host_port="$3"

# Bring up postgres + provision the superuser on the CI agent. Mirrors the
# setup that ArchiveNodeUnitTest uses. The third arg is a placeholder db
# name; the test creates its own DB from the dump so the value is unused
# afterwards, but the setup script still requires it.
if [[ -x ./buildkite/scripts/setup-database-for-archive-node.sh ]]; then
  echo "Provisioning postgres via setup-database-for-archive-node.sh..."
  # shellcheck disable=SC1091
  source ./buildkite/scripts/setup-database-for-archive-node.sh \
    "$user" "$password" "fork_canonical_bug_placeholder"
fi

STORAGEBOX_BASE="${STORAGEBOX_BASE:-/var/storagebox}"
STORAGEBOX_FIXTURE_PATH="${STORAGEBOX_FIXTURE_PATH:-test_data/archive_fork_canonical_bug}"
HETZNER_KEY="${HETZNER_KEY:-$HOME/work/secrets/storagebox.key}"
HETZNER_USER="${HETZNER_USER:-u434410}"
HETZNER_HOST="${HETZNER_HOST:-u434410-sub2.your-storagebox.de}"

if [[ -n "${FORK_BUG_FIXTURE_DIR:-}" ]]; then
  fixture_dir="$FORK_BUG_FIXTURE_DIR"
  echo "Using pre-staged fixture at $fixture_dir"
elif [[ -d "$STORAGEBOX_BASE/$STORAGEBOX_FIXTURE_PATH" ]]; then
  fixture_dir="$STORAGEBOX_BASE/$STORAGEBOX_FIXTURE_PATH"
  echo "Using storage-box-mounted fixture at $fixture_dir"
else
  fixture_dir="$(mktemp -d -t fork-bug-fixture-XXXXXX)"
  echo "Pulling fixture from Hetzner into $fixture_dir (no local mount found)"
  rsync -avz --progress \
    -e "ssh -p 23 -i $HETZNER_KEY -o StrictHostKeyChecking=no" \
    "$HETZNER_USER@$HETZNER_HOST:/home/o1labs-generic/pvc-4d294645-6466-4260-b933-1b909ff9c3a1/$STORAGEBOX_FIXTURE_PATH/" \
    "$fixture_dir/"
fi

for required in prefork_archive_dump.sql.tar.gz genesis.json precomputed_blocks.tar.xz; do
  if [[ ! -f "$fixture_dir/$required" ]]; then
    echo "Error: fixture missing $required at $fixture_dir/$required" >&2
    exit 1
  fi
done

eval "$(opam config env)"

export MINA_TEST_POSTGRES_URI="postgres://${user}:${password}@${host_port}"
export MINA_TEST_NETWORK_DATA="$fixture_dir"

echo "Running archive fork-canonical-bug test..."
dune build src/test/archive/archive_node_tests/archive_node_tests.exe
dune exec src/test/archive/archive_node_tests/archive_node_tests.exe -- \
  test 'fork_canonical_bug'
