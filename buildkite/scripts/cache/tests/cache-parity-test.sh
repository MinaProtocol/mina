#!/usr/bin/env bash

# ------------------------------------------------------------------------------
# cache-parity-test.sh
# ------------------------------------------------------------------------------
# Parity gate for the CI cache manager. Exercises the two verbs mina actually
# uses — `read` and `write-to-dir` — against one of two interchangeable engines,
# selected by CACHE_ENGINE:
#
#   bash                      (default) — buildkite/scripts/cache/manager.sh
#   buildkite-cache-manager             — the Rust tool (binary on PATH, or $BCM)
#
# Both operate on the same cache layout ($CACHE_BASE_URL/$BUILDKITE_BUILD_ID/...)
# and honour the same env, so the assertions below are shared. Run once per
# engine (in CI, bash in the toolchain image and the tool in the release-toolkit
# image); identical conclusions == parity.
#
# The cache root is a throwaway temp dir (CACHE_BASE_URL), so this touches no
# real Hetzner storage.
# ------------------------------------------------------------------------------

set -eux -o pipefail

TEST_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
MANAGER_SH="$(realpath "$TEST_DIR/../manager.sh")"

CACHE_ENGINE="${CACHE_ENGINE:-bash}"
BCM="${BCM:-buildkite-cache-manager}"

log()  { echo "[cache-parity][$CACHE_ENGINE] $*"; }
fail() { echo "[cache-parity][$CACHE_ENGINE][ERROR] $*" >&2; exit 1; }

assert_file_equals() {
  local path="$1" expected="$2" actual
  [[ -f "$path" ]] || fail "expected file $path to exist"
  actual="$(cat "$path")"
  [[ "$actual" == "$expected" ]] || fail "file $path: expected '$expected', got '$actual'"
}

# Dispatch a cache verb to the selected engine. The tool renames write-to-dir to
# `write` (variadic: INPUT... DEST, same as the bash verb); everything else is a
# straight pass-through with matching argument order.
cache_verb() {
  local verb="$1"; shift
  case "$CACHE_ENGINE" in
    bash)
      "$MANAGER_SH" "$verb" "$@" ;;
    buildkite-cache-manager)
      case "$verb" in
        write-to-dir) "$BCM" write "$@" ;;
        *)            "$BCM" "$verb" "$@" ;;
      esac ;;
    *)
      fail "unknown CACHE_ENGINE '$CACHE_ENGINE' (expected 'bash' or 'buildkite-cache-manager')" ;;
  esac
}

# Both engines require a Buildkite build id (the cache namespace) and read
# CACHE_BASE_URL. Use throwaway values so nothing touches real storage.
WORKDIR="$(mktemp -d -t cache-parity-XXXXXX)"
cleanup() { rm -rf "$WORKDIR"; }
trap cleanup EXIT

export CACHE_BASE_URL="$WORKDIR/cache"
export BUILDKITE_BUILD_ID="parity-test-build"
mkdir -p "$CACHE_BASE_URL"

SRC="$WORKDIR/src"; mkdir -p "$SRC"
echo "hashes-content"  > "$SRC/hashes.json"
echo "config-content"  > "$SRC/new_config.json"
echo "ledger-a"        > "$SRC/ledger_a.tar.gz"
echo "ledger-b"        > "$SRC/ledger_b.tar.gz"

# ------------------------------------------------------------------------------
# write-to-dir: multiple explicit inputs into one destination directory
# ------------------------------------------------------------------------------
log "write-to-dir (multiple inputs)"
cache_verb write-to-dir "$SRC/hashes.json" "$SRC/new_config.json" hardfork/

CACHE_HF="$CACHE_BASE_URL/$BUILDKITE_BUILD_ID/hardfork"
assert_file_equals "$CACHE_HF/hashes.json"     "hashes-content"
assert_file_equals "$CACHE_HF/new_config.json" "config-content"

# ------------------------------------------------------------------------------
# write-to-dir: a glob input into a destination directory
# ------------------------------------------------------------------------------
log "write-to-dir (glob input)"
cache_verb write-to-dir "$SRC/ledger_*.tar.gz" hardfork/ledgers/

CACHE_LED="$CACHE_BASE_URL/$BUILDKITE_BUILD_ID/hardfork/ledgers"
assert_file_equals "$CACHE_LED/ledger_a.tar.gz" "ledger-a"
assert_file_equals "$CACHE_LED/ledger_b.tar.gz" "ledger-b"

# ------------------------------------------------------------------------------
# read: copy cached artifacts back to a local directory
# ------------------------------------------------------------------------------
log "read (single input) into a local dir"
OUT="$WORKDIR/out"; mkdir -p "$OUT"
cache_verb read hardfork/hashes.json "$OUT"
assert_file_equals "$OUT/hashes.json" "hashes-content"

log "read (glob input) into a local dir"
OUT2="$WORKDIR/out2"; mkdir -p "$OUT2"
cache_verb read "hardfork/ledgers/ledger_*.tar.gz" "$OUT2"
assert_file_equals "$OUT2/ledger_a.tar.gz" "ledger-a"
assert_file_equals "$OUT2/ledger_b.tar.gz" "ledger-b"

log "All cache operations executed and verified successfully"
