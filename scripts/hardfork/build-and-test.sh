#!/usr/bin/env bash

# This scripts builds a designated PREFORK branch and current branch with nix
# 0. Prepare environment if needed
# 1. Build PREFORK as a prefork build;
# 2. Push the prefork build to the nix cache on the storage box. Only it is
# cached: everything after this point is built from the commit under test, so
# it changes for each PR.
# 3. Build the commit under test as the postfork build, and hardfork_test;
# 4. Execute hardfork_test on them.
#
# When HARDFORK_TEST_PG_URI is set (CI starts a PostgreSQL server and sets it),
# both networks also run an archive node in that database, and the test checks
# the archive upgrade, the hard-fork data repair and rosetta-cli across the
# fork.

# Step 0. Prepare environment if needed
set -eux -o pipefail

PREFORK=""
EXTRA_ARGS=()

USAGE="Usage: $0 --fork-from <PREFORK> [ADDITONAL ARGS TO HF TEST...]"
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

# nixpkgs fetchurl passes NIX_CURL_FLAGS to curl. Its default `--retry 3` only
# covers timeouts and 5xx: a connection reset, which the Hetzner agents get
# from GitHub now and then, fails the source download and the build at once.
export NIX_CURL_FLAGS="--retry-all-errors --retry 5 --retry-delay 10"

if [[ -n "${NIX_CACHE_NAR_SECRET:-}" ]]; then
  echo "$NIX_CACHE_NAR_SECRET" > /tmp/nix-cache-secret
  echo "Configuring the NAR signing secret"
  NIX_SECRET_KEY=/tmp/nix-cache-secret
fi

# Nix binary cache on the Hetzner storage box, mounted into the job container
# (Cmds.dhall). Read through --extra-substituters; the post-build hook records
# what this run builds so step 2 can push exactly that back. The public key in
# flake.nix nixConfig covers the NARs signed with NIX_CACHE_NAR_SECRET.
NIX_STORAGEBOX_CACHE="${NIX_STORAGEBOX_CACHE:-/var/storagebox/nix-cache}"
if [[ -d "${NIX_STORAGEBOX_CACHE%/*}" ]]; then
  echo "Nix cache on the storage box: $NIX_STORAGEBOX_CACHE"
  NIX_OPTS+=( --extra-substituters "file://${NIX_STORAGEBOX_CACHE}" )
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

# Push the paths built so far to the storage box cache (zstd: xz is far
# slower). Also runs when a build step fails, so the sources fetched before the
# failure are cached and the next attempt does not download them again. Pushes
# once: outputs built after the explicit push stay out of the cache.
# /tmp/nix-paths is absent when everything came from the cache.
CACHE_PUSHED=0
push_cache() {
  if [[ "$CACHE_PUSHED" == 0 && -d "${NIX_STORAGEBOX_CACHE%/*}" && -s /tmp/nix-paths ]]; then
    nix "${NIX_OPTS[@]}" copy \
      --to "file://${NIX_STORAGEBOX_CACHE}?compression=zstd" \
      --stdin </tmp/nix-paths
  fi
  CACHE_PUSHED=1
}
trap push_cache ERR

if [[ -n "${NIX_POST_BUILD_HOOK:-}" ]]; then
  NIX_OPTS+=( --post-build-hook "$NIX_POST_BUILD_HOOK" )
fi
if [[ -n "${NIX_SECRET_KEY:-}" ]]; then
  NIX_OPTS+=( --secret-key-files "$NIX_SECRET_KEY" )
fi

pushd "$(git rev-parse --show-toplevel)"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [ -n "${BUILDKITE:-}" ]; then
  git config --global --add safe.directory /workdir
fi

TEST_COMMIT="$(git rev-parse HEAD)"


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

  # PostgreSQL for the archive across the fork. initdb refuses to run as root,
  # so the server runs as a nix build user of this image.
  nix-env -iA unstable.{postgresql_16,util-linux}
  PG_DATA=$(mktemp -d --tmpdir hardfork-pgdata.XXXXXXX)
  PG_SOCKET_DIR=$(mktemp -d --tmpdir hardfork-pgsocket.XXXXXXX)
  chown nixbld1 "$PG_DATA" "$PG_SOCKET_DIR"
  as_pg_user() { setpriv --reuid=nixbld1 --regid=nixbld --init-groups "$@"; }
  as_pg_user initdb -D "$PG_DATA" -U postgres --auth=trust >/dev/null
  as_pg_user pg_ctl -D "$PG_DATA" -l "$PG_DATA/postgres.log" -w start \
    -o "-c listen_addresses=127.0.0.1 -c port=5432 -c max_connections=200 -k $PG_SOCKET_DIR"
  export HARDFORK_TEST_PG_URI="postgres://postgres:postgres@127.0.0.1:5432/archive"
fi

# create_schema.sql of the prefork version, copied while it is checked out.
ARCHIVE_SQL_DIR=$(mktemp -d --tmpdir hardfork-archive-sql.XXXXXXX)

# 1. Build PREFORK as a prefork build;
git checkout $PREFORK
git submodule update --init --recursive --depth 1
nix "${NIX_OPTS[@]}" build "$PWD?submodules=1#devnet^out,archive" --out-link "prefork-devnet"
cp src/app/archive/create_schema.sql "$ARCHIVE_SQL_DIR/prefork_create_schema.sql"

# 2. Push what was built to the storage box cache.
push_cache

# 3. Build the commit under test as the postfork build, and hardfork_test.
# The postfork daemon must come from the commit under test, not from a fixed
# branch: otherwise a PR that changes the postfork daemon -- such as a
# protocol_version_transaction bump -- is never exercised by this job, and the
# nightly on a given branch tests some other branch's daemon.
git checkout "$TEST_COMMIT"
git submodule update --init --recursive --depth 1
nix "${NIX_OPTS[@]}" build "$PWD?submodules=1#devnet^out,archive" --out-link "postfork-devnet"
nix "${NIX_OPTS[@]}" build "$PWD?submodules=1#hardfork_test" --out-link "hardfork_test"
nix "${NIX_OPTS[@]}" build "$PWD?submodules=1#mina-graphql-client" --out-link "mina-graphql-client"
nix "${NIX_OPTS[@]}" build "$PWD?submodules=1#rosetta-cli" --out-link "rosetta-cli"

# 3. Execute hardfork_test on them.

SLOT_TX_END=${SLOT_TX_END:-$((RANDOM%120+30))}      
# WARN: ensure SLOT_CHAIN_END - SLOT_TX_END > k is always true!
SLOT_CHAIN_END=${SLOT_CHAIN_END:-$((SLOT_TX_END+8))}

NETWORK_ROOT=$(mktemp -d --tmpdir hardfork-network.XXXXXXX)

ARCHIVE_ARGS=()
if [[ -n "${HARDFORK_TEST_PG_URI:-}" ]]; then
  ARCHIVE_ARGS=(
    --pg-uri "$HARDFORK_TEST_PG_URI"
    --main-archive-exe "$PWD/prefork-devnet-archive/bin/mina-archive"
    --main-archive-schema "$ARCHIVE_SQL_DIR/prefork_create_schema.sql"
    --fork-archive-exe "$PWD/postfork-devnet-archive/bin/mina-archive"
    --fork-archive-upgrade-script "$PWD/src/app/archive/upgrade.sql"
    --fork-archive-toolbox-exe "$PWD/postfork-devnet-archive/bin/mina-archive-hardfork-toolbox"
    --fork-rosetta-exe "$PWD/postfork-devnet/bin/rosetta"
    --fork-signer-exe "$PWD/postfork-devnet/bin/mina-ocaml-signer"
    --rosetta-cli-exe "$PWD/rosetta-cli/bin/rosetta-cli"
    --rosetta-cli-config-dir "$PWD/src/app/rosetta/rosetta-cli-config"
  )
fi

hardfork_test/bin/hardfork_test \
  --main-mina-exe prefork-devnet/bin/mina \
  --main-runtime-genesis-ledger prefork-devnet/bin/runtime_genesis_ledger \
  --fork-mina-exe postfork-devnet/bin/mina \
  --fork-runtime-genesis-ledger postfork-devnet/bin/runtime_genesis_ledger \
  --mina-graphql-client-exe mina-graphql-client/bin/mina-graphql-client \
  --slot-tx-end "$SLOT_TX_END" \
  --slot-chain-end "$SLOT_CHAIN_END" \
  --script-dir "$SCRIPT_DIR" \
  --root "$NETWORK_ROOT" \
  "${ARCHIVE_ARGS[@]}" \
  "${EXTRA_ARGS[@]}"

popd
