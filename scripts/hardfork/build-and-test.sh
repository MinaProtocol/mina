#!/usr/bin/env bash

# This scripts builds a designated PREFORK branch and current branch with nix
# 0. Prepare environment if needed
# 1. Build PREFORK as a prefork build;
# 2. Build "mesa" branch as a postfork build
# 3. Upload to nix cache, the reason for not uploading cache for following 2 
# steps is that they change for each PR. 
# 4. Build hardfork_test on current branch;
# 5. Execute hardfork_test on them.

# Step 0. Prepare environment if needed
set -eux -o pipefail

PREFORK=""
FORK_METHOD="legacy"

USAGE="Usage: $0 --fork-from <PREFORK> [--fork-method <FORK_METHOD>]"
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
    --fork-method)
      # ensure value exists
      if [[ $# -lt 2 ]]; then
        usage "Error: $1 requires an argument."
      fi
      case "$2" in
        legacy|advanced)
          FORK_METHOD="$2"
          ;;
        *)
          usage "Error: $1 must be either 'legacy' or 'advanced'."
          ;;
      esac
      shift 2
      ;;
    --help|-h)
      usage
      ;;
    --*)
      usage "Unknown option: $1"
      ;;
    *)
      # positional arg — store if needed later
      usage "Unexpected argument: $1"
      ;;
  esac
done

if [[ -z "$PREFORK" ]]; then
  usage "Error: --fork-from must be provided."
fi

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

if [ -n "${BUILDKITE:-}" ]; then
  # This is a CI run, ensure nix docker has everything what we want.
  nix-env -iA unstable.{curl,gawk,git-lfs,gnused,jq,python311}

  python -m venv .venv
  source .venv/bin/activate
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
git checkout $PREFORK
git submodule update --init --recursive --depth 1
nix "${NIX_OPTS[@]}" build "$PWD?submodules=1#devnet" --out-link "prefork-devnet"

# 2. Build "mesa" branch as a postfork build
git checkout mesa
git submodule update --init --recursive --depth 1
nix "${NIX_OPTS[@]}" build "$PWD?submodules=1#devnet" --out-link "postfork-devnet"

# 3. Upload to nix cache 

if [[ -n "${NIX_CACHE_GCP_ID:-}" ]] && [[ -n "${NIX_CACHE_GCP_SECRET:-}" ]]; then
  mkdir -p $HOME/.aws
  cat <<EOF> $HOME/.aws/credentials
[default]
aws_access_key_id=$NIX_CACHE_GCP_ID
aws_secret_access_key=$NIX_CACHE_GCP_SECRET
EOF

  nix "${NIX_OPTS[@]}" copy \
    --to "s3://mina-nix-cache?endpoint=https://storage.googleapis.com" \
    --stdin </tmp/nix-paths
fi

# 4. Build hardfork_test on current branch;
git checkout "$BUILDKITE_COMMIT"
git submodule update --init --recursive --depth 1
nix "${NIX_OPTS[@]}" build "$PWD?submodules=1#hardfork_test" --out-link "hardfork_test"

# 5. Execute hardfork_test on them.

SLOT_TX_END=${SLOT_TX_END:-$((RANDOM%120+30))}      
SLOT_CHAIN_END=${SLOT_CHAIN_END:-$((SLOT_TX_END+16))}

NETWORK_ROOT=$(mktemp -d --tmpdir hardfork-network.XXXXXXX)

hardfork_test/bin/hardfork_test \
  --main-mina-exe prefork-devnet/bin/mina \
  --main-runtime-genesis-ledger prefork-devnet/bin/runtime_genesis_ledger \
  --fork-mina-exe postfork-devnet/bin/mina \
  --fork-runtime-genesis-ledger postfork-devnet/bin/runtime_genesis_ledger \
  --slot-tx-end "$SLOT_TX_END" \
  --slot-chain-end "$SLOT_CHAIN_END" \
  --script-dir "$SCRIPT_DIR" \
  --root "$NETWORK_ROOT" \
  --fork-method "$FORK_METHOD"

popd
