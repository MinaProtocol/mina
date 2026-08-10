#!/usr/bin/env bash
# Verification checks for the mina-daemon-auto-hardfork image.
#
# This image is NOT a normal daemon image, so check-daemon.sh does not apply:
#   - /usr/local/bin/mina is the mina-dispatch script, not a daemon binary. The
#     dispatcher only forwards "daemon", "client", "libp2p" and "--version";
#     every other subcommand (including "--help") exits 1 by design, so the
#     "mina --help" step of check-daemon.sh would always fail here.
#   - The image carries TWO runtimes side by side, under
#     ${RUNTIMES_BASE_PATH}/berkeley (pre-fork) and .../mesa (post-fork).
#
# Checks:
#   1. The dispatcher config /etc/default/mina-dispatch exists and defines the
#      variables the dispatcher needs.
#   2. /usr/local/bin/mina resolves to the dispatcher.
#   3. Both runtime binaries exist, are executable, and report a version.
#   4. The two runtimes report DIFFERENT commit hashes. Two identical runtimes
#      mean the image was built from the wrong deb pair and cannot hardfork.
#   5. "mina --version" works through the dispatcher. With no activation state
#      file present, the dispatcher selects the berkeley runtime, so the version
#      it reports must be the berkeley one.
#   6. If a genesis config file is shipped, its commit hash matches the berkeley
#      runtime (the pre-fork config is the only one this image carries; the
#      post-fork config comes from the mina-<network>-config package).
set -euo pipefail

DISPATCH_ENV=/etc/default/mina-dispatch

# --- 1. Dispatcher configuration -------------------------------------------
echo "Checking dispatcher configuration $DISPATCH_ENV ..."
if [ ! -f "$DISPATCH_ENV" ]; then
  echo "FAIL: $DISPATCH_ENV not found"
  exit 1
fi
cat "$DISPATCH_ENV"

# shellcheck disable=SC1090
source "$DISPATCH_ENV"

for var in MINA_NETWORK MINA_PROFILE RUNTIMES_BASE_PATH; do
  if [ -z "${!var:-}" ]; then
    echo "FAIL: $var is not defined in $DISPATCH_ENV"
    exit 1
  fi
done
echo "OK: MINA_NETWORK=$MINA_NETWORK MINA_PROFILE=$MINA_PROFILE RUNTIMES_BASE_PATH=$RUNTIMES_BASE_PATH"

# --- 2. The mina entrypoint is the dispatcher ------------------------------
MINA_BIN=$(command -v mina)
echo "Checking that $MINA_BIN is the dispatcher ..."
if [ "$(basename "$(readlink -f "$MINA_BIN")")" != "mina-dispatch" ]; then
  echo "FAIL: $MINA_BIN does not resolve to mina-dispatch"
  readlink -f "$MINA_BIN"
  exit 1
fi
echo "OK: $MINA_BIN -> mina-dispatch"

# --- 3. Both runtimes are present and runnable -----------------------------
PREFORK_BIN="$RUNTIMES_BASE_PATH/berkeley/mina"
POSTFORK_BIN="$RUNTIMES_BASE_PATH/mesa/mina"

# Extracts the first 8 characters of the commit hash from a "mina --version"
# output. Matches both the JSON ("commit_hash": "<sha>") and the plain
# ("Commit <sha>") shapes, exactly like check-daemon.sh does.
extract_commit() {
  grep -oP '(?:commit_hash": "|Commit )\K[a-f0-9]+' | head -c 8
}

for bin in "$PREFORK_BIN" "$POSTFORK_BIN"; do
  echo "Checking runtime $bin ..."
  if [ ! -x "$bin" ]; then
    echo "FAIL: $bin not found or not executable"
    exit 1
  fi
  "$bin" --version
done

PREFORK_COMMIT=$("$PREFORK_BIN" --version 2>&1 | extract_commit)
POSTFORK_COMMIT=$("$POSTFORK_BIN" --version 2>&1 | extract_commit)
echo "Pre-fork  (berkeley) commit: $PREFORK_COMMIT"
echo "Post-fork (mesa)     commit: $POSTFORK_COMMIT"

if [ -z "$PREFORK_COMMIT" ] || [ -z "$POSTFORK_COMMIT" ]; then
  echo "FAIL: could not read a commit hash from one of the runtimes"
  exit 1
fi

# --- 4. The two runtimes must differ ---------------------------------------
if [ "$PREFORK_COMMIT" = "$POSTFORK_COMMIT" ]; then
  echo "FAIL: both runtimes report the same commit ($PREFORK_COMMIT);"
  echo "      the image was built from the wrong prefork/postfork deb pair"
  exit 1
fi
echo "OK: the two runtimes are built from different commits"

# --- 5. The dispatcher passes --version through ----------------------------
echo "Running mina --version through the dispatcher ..."
DISPATCHED_COMMIT=$(mina --version 2>&1 | extract_commit)
echo "Dispatched commit: $DISPATCHED_COMMIT"

# No activation state file is present in a fresh container, so the dispatcher
# must select the pre-fork runtime.
if [ "$DISPATCHED_COMMIT" != "$PREFORK_COMMIT" ]; then
  echo "FAIL: mina --version reported $DISPATCHED_COMMIT, expected the pre-fork"
  echo "      runtime ($PREFORK_COMMIT) because no activation state file exists"
  exit 1
fi
echo "OK: the dispatcher selects the pre-fork runtime before activation"

# --- 6. Genesis config matches the pre-fork runtime ------------------------
CONFIG_FILE=$(ls /var/lib/coda/config_*.json 2>/dev/null | head -1 || true)

if [ -z "$CONFIG_FILE" ]; then
  echo "No genesis config file found in /var/lib/coda/ — skipping hash check"
  exit 0
fi

echo "Found genesis config: $CONFIG_FILE"
CONFIG_COMMIT=$(basename "$CONFIG_FILE" | grep -oP 'config_\K[a-f0-9]+')
echo "Config file commit hash: $CONFIG_COMMIT"

if [ "$PREFORK_COMMIT" = "$CONFIG_COMMIT" ]; then
  echo "OK: pre-fork runtime commit ($PREFORK_COMMIT) matches genesis config commit ($CONFIG_COMMIT)"
else
  echo "FAIL: pre-fork runtime commit ($PREFORK_COMMIT) does not match genesis config commit ($CONFIG_COMMIT)"
  exit 1
fi
