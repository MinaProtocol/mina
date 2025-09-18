#!/usr/bin/env bash

# This scripts builds compatible and current branch with nix
# It handles two cases differently:
# - When given an $1 argument, it treats itself as being run in
#   Buildkite CI and $1 to be "fork" branch that needs to be built
# - When it isn't given any arguments, it asusmes it is being
#   executed locally and builds code in $PWD as the fork branch
#
# When run locally, `compatible` branch is built in a temporary folder
# (and fetched clean from Mina's repository). When run in CI,
# `compatible` branch of git repo in $PWD is used to being the
# compatible executable.
#
# In either case at the end of its execution this script leaves
# current dir at the fork branch (in case of local run, it never
# switches the branch with git) and nix builds put to `compatible-devnet`
# and `fork-devnet` symlinks (located in $PWD).

set -exo pipefail

# Parse command line arguments
MODE="nix"
FORK_BRANCH=""
CONTEXT="local"
export NETWORK_NAME=devnet
export DUNE_PROFILE=${NETWORK_NAME}
DOCKER_TOOLCHAIN="${DOCKER_TOOLCHAIN:-gcr.io/o1labs-192920/mina-toolchain@sha256:3b17e388d8974fdbe4bbd5f77315519763c78148a4c91434d9add62de87ab792}"
OVERRIDE_COMPATIBLE_TMP_DIR="${OVERRIDE_COMPATIBLE_TMP_DIR}"

while [[ $# -gt 0 ]]; do
  case $1 in
    --mode)
      MODE="$2"
      shift 2
      ;;
    --fork-branch)
      FORK_BRANCH="$2"
      shift 2
      ;;
    --context)
      CONTEXT="$2"
      shift 2
      ;;
    --toolchain)
      DOCKER_TOOLCHAIN="$2"
      shift 2
      ;;
    --use-compatible-tmp-dir)
      OVERRIDE_COMPATIBLE_TMP_DIR="$2"
      shift 2
      ;;
    *)
      # For backwards compatibility, treat first positional arg as fork branch
      if [[ -z "$FORK_BRANCH" ]]; then
        FORK_BRANCH="$1"
      fi
      shift
      ;;
  esac
done

# Validate mode
if [[ "$MODE" != "nix" && "$MODE" != "docker" ]]; then
  echo "Error: --mode must be either 'nix' or 'docker'"
  exit 1
fi

# Validate context
if [[ "$CONTEXT" != "ci" && "$CONTEXT" != "local" ]]; then
  echo "Error: --context must be either 'ci' or 'local'"
  exit 1
fi


# For backwards compatibility, if no fork branch specified but we have positional args
# treat the script as being run in CI mode
if [[ -n "$FORK_BRANCH" ]]; then
  set -- "$FORK_BRANCH"
fi

init_nix() {
  NIX_OPTS=( --accept-flake-config --experimental-features 'nix-command flakes' )

  if [[ "$NIX_CACHE_NAR_SECRET" != "" ]]; then
    echo "$NIX_CACHE_NAR_SECRET" > /tmp/nix-cache-secret
    echo "Configuring the NAR signing secret"
    NIX_SECRET_KEY=/tmp/nix-cache-secret
  fi

  if [[ "$NIX_CACHE_GCP_ID" != "" ]] && [[ "$NIX_CACHE_GCP_SECRET" != "" ]]; then
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

  if [[ "$NIX_POST_BUILD_HOOK" != "" ]]; then
    NIX_OPTS+=( --post-build-hook "$NIX_POST_BUILD_HOOK" )
  fi
  if [[ "$NIX_SECRET_KEY" != "" ]]; then
    NIX_OPTS+=( --secret-key-files "$NIX_SECRET_KEY" )
  fi
}

build_branch() {
    local build_dir="$1"
    local output_link="$2"

    export BYPASS_OPAM_SWITCH_UPDATE=1

    if [[ "$MODE" == "nix" ]]; then
      nix "${NIX_OPTS[@]}" build "$build_dir?submodules=1#devnet" --out-link "$output_link"
      nix "${NIX_OPTS[@]}" build "$build_dir?submodules=1#devnet.genesis" --out-link "$output_link"
    elif [[ "$MODE" == "docker" ]]; then
      cd "$build_dir"
      if [[ "$CONTEXT" == "local" ]]; then
        make build
        make build-logproc
        make build-devnet-sigs
        make build-daemon-utils
        make debian-build-logproc
        DEBIAN_SKIP_LEDGERS_COPY=y make debian-build-daemon-${NETWORK_NAME}
      else
        export DEBIAN_FRONTEND=noninteractive
        export DUNE_PROFILE=${NETWORK_NAME}
        export DOCKER_TOOLCHAIN
        export OPAMSWITCH=4.14.2

        docker run --rm --env OPAMSWITCH --env BYPASS_OPAM_SWITCH_UPDATE -v "$PWD:/workdir" -v /var/storagebox:/var/storagebox --env DUNE_PROFILE -w /workdir "$DOCKER_TOOLCHAIN" bash -c "
          sudo chown -R opam . \
          && source ~/.profile \
          && git config --global --add safe.directory /workdir \
          && make libp2p_helper \
          && make build-logproc \
          && make build-devnet-sigs \
          && make build-daemon-utils \
          && make debian-build-logproc \
          && BACKEND=local make debian-download-create-legacy-hardfork \
          && DEBIAN_SKIP_LEDGERS_COPY=y make debian-build-daemon-devnet \
        "
      fi

      make docker-build-daemon-devnet
    fi
}

if [[ "$MODE" == "nix" ]]; then
  init_nix
fi

INIT_DIR="$PWD"
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [[ "$CONTEXT" == "ci"  ]] && [[ "$MODE" == "nix" ]]; then
    # Branch is specified, this is a CI run
    ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    chown -R "${USER}" /workdir
    git config --global --add safe.directory /workdir
    git fetch

    nix-env -iA unstable.jq
    nix-env -iA unstable.curl
    nix-env -iA unstable.gnused
    nix-env -iA unstable.git-lfs
fi

if [[ ! -L compatible-devnet ]]; then
  if [[ "$CONTEXT" == "local" ]]; then
    if [[ -n "$OVERRIDE_COMPATIBLE_TMP_DIR" ]]; then
      compatible_build="$OVERRIDE_COMPATIBLE_TMP_DIR"
    else
      compatible_build=$(mktemp -d /tmp/compatible-build.XXXXXX)
      git clone -b compatible --single-branch "https://github.com/MinaProtocol/mina.git" "$compatible_build"
    fi
    cd "$compatible_build"
  else
    git checkout -f $1
    git pull
    git checkout -f $1 -- Makefile
    git checkout -f $1 -- scripts/hardfork
    compatible_build="$INIT_DIR"
  fi
  git submodule sync --recursive
  git submodule update --init --recursive

  build_branch "$compatible_build" "$INIT_DIR/compatible-devnet"
  if [[ "$CONTEXT" == "local" ]]; then
      cd -
      if [[ -z "$OVERRIDE_COMPATIBLE_TMP_DIR" ]]; then
        rm -Rf "$compatible_build"
      fi
  fi
fi

if [[ "$CONTEXT" == "ci" ]]; then
  # Branch is specified, this is a CI run
  git checkout -f $1
  git submodule sync --recursive
  git submodule update --init --recursive
fi


build_branch "$INIT_DIR" "$INIT_DIR/fork-devnet"

if  [[ "$MODE" == "nix" ]] && [[ "$NIX_CACHE_GCP_ID" != "" ]] && [[ "$NIX_CACHE_GCP_SECRET" != "" ]]; then
  mkdir -p $HOME/.aws
  cat << EOF > $HOME/.aws/credentials
[default]
aws_access_key_id=$NIX_CACHE_GCP_ID
aws_secret_access_key=$NIX_CACHE_GCP_SECRET
EOF

  nix --experimental-features nix-command copy --to "s3://mina-nix-cache?endpoint=https://storage.googleapis.com" --stdin </tmp/nix-paths
fi

SLOT_TX_END=${SLOT_TX_END:-$((RANDOM%120+30))}
export SLOT_TX_END

echo "Running HF test with SLOT_TX_END=$SLOT_TX_END"


MINA_DEB_CODENAME=focal source ./scripts/export-git-env-vars.sh
export FORK_BRANCH

if [[ "$MODE" == "docker" ]]; then
  CONTEXT=$CONTEXT "$SCRIPT_DIR"/test.sh --mina-docker "gcr.io/o1labs-192920/mina-daemon:$MINA_DOCKER_TAG-devnet" && echo "HF test completed successfully"
else
  CONTEXT=$CONTEXT "$SCRIPT_DIR"/test.sh --mina-app compatible-devnet/bin/mina \
    --runtime-genesis-ledger compatible-devnet/bin/runtime_genesis_ledger \
    --fork-mina-app fork-devnet/bin/mina \
    --fork-runtime-genesis-ledger fork-devnet/bin/runtime_genesis_ledger \
   && echo "HF test completed successfully"
fi
