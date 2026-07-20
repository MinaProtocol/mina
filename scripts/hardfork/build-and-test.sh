#!/usr/bin/env bash

# This scripts builds a designated PREFORK branch and current branch with nix
# 0. Prepare environment if needed
# 1. Build PREFORK as a prefork build;
# 2. Build the current (test) branch as a postfork build
# 3. Upload to nix cache, the reason for not uploading cache for following 2
# steps is that they change for each PR. 
# 4. Build hardfork_test on current branch;
# 5. Execute hardfork_test on them.

# Step 0. Prepare environment if needed
set -eux -o pipefail

PREFORK=""
POSTFORK=""
TOPOLOGY="legacy"
EXTRA_ARGS=()

USAGE="Usage: $0 --fork-from <PREFORK> [--fork-into <POSTFORK>] [--topology <NAME>] [ADDITIONAL ARGS TO HF TEST...]"
usage() {
  if (( $# > 0 )); then
    echo "$1" >&2
    echo "$USAGE"
    exit 1
  else
    echo "$USAGE"
    exit 0
  fi
}

# ---- argument parsing --------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --fork-from)
      # ensure value exists
      if [[ $# -lt 2 ]]; then
        usage "Error: $1 requires an argument."
      fi
      PREFORK="$2"
      shift 2
      ;;
    --fork-into)
      # ensure value exists
      if [[ $# -lt 2 ]]; then
        usage "Error: $1 requires an argument."
      fi
      POSTFORK="$2"
      shift 2
      ;;
    --topology)
      # ensure value exists
      if [[ $# -lt 2 ]]; then
        usage "Error: $1 requires an argument."
      fi
      TOPOLOGY="$2"
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    *)
      EXTRA_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ -z "$PREFORK" ]]; then
  usage "Error: --fork-from must be provided."
fi

export MINA_PROFILE="devnet"

NIX_OPTS=( --accept-flake-config --experimental-features 'nix-command flakes' )

if [[ -n "${NIX_CACHE_NAR_SECRET:-}" ]]; then
  echo "$NIX_CACHE_NAR_SECRET" > /tmp/nix-cache-secret
  echo "Configuring the NAR signing secret"
  NIX_SECRET_KEY=/tmp/nix-cache-secret
fi

if [[ -n "${NIX_CACHE_GCP_ID:-}" ]] && [[ -n "${NIX_CACHE_GCP_SECRET:-}" ]]; then
  echo "GCP uploading configured (for nix binaries)"
  cat <<'EOF'> /tmp/nix-post-build
#!/bin/sh

set -eu
set -f # disable globbing
export IFS=' '

echo $OUT_PATHS | tr ' ' '\n' >> /tmp/nix-paths
EOF
  chmod +x /tmp/nix-post-build
  NIX_POST_BUILD_HOOK=/tmp/nix-post-build
fi

if [[ -n "${NIX_POST_BUILD_HOOK:-}" ]]; then
  NIX_OPTS+=( --post-build-hook "$NIX_POST_BUILD_HOOK" )
fi
if [[ -n "${NIX_SECRET_KEY:-}" ]]; then
  NIX_OPTS+=( --secret-key-files "$NIX_SECRET_KEY" )
fi

pushd "$(git rev-parse --show-toplevel)"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# The topology presets live with mina-local-network, next to the schema that
# governs them. Resolving the name to a path is this script's job: hardfork_test
# is handed a file and never has to know the repo layout.
#
# Checked here, before the two nix builds, so a typo costs a second rather than
# the ~50 minutes it takes to reach the step that reads it.
TOPOLOGY_FILE="$SCRIPT_DIR/../mina-local-network/presets/hf-test-$TOPOLOGY.jsonc"
if [[ ! -f "$TOPOLOGY_FILE" ]]; then
  usage "Error: unknown topology '$TOPOLOGY' (no such preset: $TOPOLOGY_FILE)"
fi

if [ -n "${BUILDKITE:-}" ]; then
  git config --global --add safe.directory /workdir
fi

# Prefer the symbolic branch name so checkouts below leave the working tree on a
# named branch; a detached HEAD (plain `git checkout <sha>`) can confuse nix
# flake evaluation. Fall back to the commit SHA when already detached (e.g. CI).
TEST_REF="$(git symbolic-ref --quiet --short HEAD || git rev-parse HEAD)"
POSTFORK="${POSTFORK:-origin/develop}"


if [ -n "${BUILDKITE:-}" ]; then
  # This is a CI run, ensure nix docker has everything what we want.
  #
  # Only what this script's own path actually needs: curl, because the daemon
  # shells out to it to fetch genesis ledgers (src/lib/cache_dir/native/
  # cache_dir.ml); jq, because create_runtime_config.sh builds the fork config
  # with it; and python, for the venv below. The nix builds are sandboxed with
  # their own closures and do not read this profile.
  nix-env -iA unstable.{curl,jq,python311}

  # Putting the venv on PATH is all `activate` does that matters here (it sets
  # PATH, VIRTUAL_ENV and a prompt; nothing reads the latter two). Doing it
  # directly keeps the script statically analysable: `activate` does not exist
  # until the line above runs, so sourcing it is a permanent shellcheck blind
  # spot. PATH is what pip installs into, and what the `python3` that
  # hardfork_test spawns resolves through.
  python -m venv .venv
  export PATH="$PWD/.venv/bin:$PATH"
  pip install -r scripts/mina-local-network/requirements.txt

  # Manually patch zone infos, nix doesn't provide stdenv breaking janestreet's core
  zone_info=(/nix/store/*tzdata*/share/zoneinfo)
  if [ "${#zone_info[@]}" -lt 1 ]; then
    echo "Error: expected at least one tzdata path, none found" >&2
    exit 1
  fi
  unlink /usr/share && mkdir -p /usr/share
  ln -sf "${zone_info[0]}" /usr/share/zoneinfo
  ln -sf /usr/share/zoneinfo/UTC /etc/localtime
  if [ ! -L /etc/localtime ] || [ ! -e /etc/localtime ]; then
    echo "Error: timezone file invalid!" >&2
    exit 1
  fi

  git fetch origin
fi

# 1. Build PREFORK as a prefork build;
git checkout "$PREFORK"
git submodule update --init --recursive --depth 1
nix "${NIX_OPTS[@]}" build "$PWD?submodules=1#devnet" --out-link "prefork-devnet"

# 2. Build the postfork branch.
git checkout "$POSTFORK"
git submodule update --init --recursive --depth 1
nix "${NIX_OPTS[@]}" build "$PWD?submodules=1#devnet" --out-link "postfork-devnet"

# 3. Upload to nix cache 

if [[ -n "${NIX_CACHE_GCP_ID:-}" ]] && [[ -n "${NIX_CACHE_GCP_SECRET:-}" ]]; then
  mkdir -p "$HOME/.aws"
  cat <<EOF> "$HOME/.aws/credentials"
[default]
aws_access_key_id=$NIX_CACHE_GCP_ID
aws_secret_access_key=$NIX_CACHE_GCP_SECRET
EOF

  nix "${NIX_OPTS[@]}" copy \
    --to "s3://mina-nix-cache?endpoint=https://storage.googleapis.com" \
    --stdin </tmp/nix-paths
fi

# 4. Build hardfork_test on current branch;
git checkout "$TEST_REF"
git submodule update --init --recursive --depth 1
nix "${NIX_OPTS[@]}" build "$PWD?submodules=1#hardfork_test" --out-link "hardfork_test"

# 5. Execute hardfork_test on them.

NETWORK_ROOT=$(mktemp -d --tmpdir hardfork-network.XXXXXXX)

# The network root holds a config directory per daemon: rocksdb databases, the
# genesis and epoch ledgers, precomputed-block logs and any crash reports. It
# grows with the length of the run and nothing else ever reclaims it, so leaving
# it behind is a disk leak on whatever host the test ran on. Remove it on every
# exit path — failures included, which is precisely when a leak would otherwise
# happen. Set HARDFORK_KEEP_NETWORK_ROOT=1 to retain it for local debugging.
cleanup_network_root() {
  local status=$?
  if [[ -n "${HARDFORK_KEEP_NETWORK_ROOT:-}" ]]; then
    echo "Keeping network root for debugging: $NETWORK_ROOT" >&2
  else
    echo "Removing network root: $NETWORK_ROOT" >&2
    rm -rf "$NETWORK_ROOT" || echo "Warning: could not remove $NETWORK_ROOT" >&2
  fi
  return "$status"
}
trap cleanup_network_root EXIT

# The slot schedule is hardfork_test's to decide: it randomizes slot-tx-end,
# derives slot-chain-end from it, and logs both. Deriving it needs the network's
# consensus parameters, which only hardfork_test reads (from the topology), so
# this script cannot compute it without keeping a second copy of them.
#
# To pin a run to a known fork point, pass --slot-tx-end through as an extra
# argument; hardfork_test logs whatever it settled on.
hardfork_test/bin/hardfork_test \
  --main-mina-exe prefork-devnet/bin/mina \
  --main-runtime-genesis-ledger prefork-devnet/bin/runtime_genesis_ledger \
  --fork-mina-exe postfork-devnet/bin/mina \
  --fork-runtime-genesis-ledger postfork-devnet/bin/runtime_genesis_ledger \
  --script-dir "$SCRIPT_DIR" \
  --topology-file "$TOPOLOGY_FILE" \
  --root "$NETWORK_ROOT" \
  "${EXTRA_ARGS[@]}"

popd
