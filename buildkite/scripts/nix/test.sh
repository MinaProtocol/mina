#!/usr/bin/env bash

set -eou pipefail
set +x

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 branch"
  exit 1
fi

SCRIPTPATH="$( cd "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

# shellcheck source=buildkite/scripts/nix/lib.sh
source "$SCRIPTPATH/lib.sh"

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

nix-env -i git-lfs

# Ownership fix + detached-HEAD checkout; see lib.sh for why both are
# needed. Uses BUILDKITE_BRANCH/BUILDKITE_COMMIT from the Buildkite context.
prepare_nix_workdir

# Test developer terminal with lsp server
nix "${NIX_OPTS[@]}" develop "$PWD?submodules=1#with-lsp" --command bash -c "echo tested"
nix "${NIX_OPTS[@]}" develop "$PWD?submodules=1#with-lsp" --command bash -c "dune build src" &
  nix "${NIX_OPTS[@]}" build "$PWD?submodules=1#devnet" --no-link
wait

# The portable tree the Debian packages and docker images are built from. Nearly
# free once #devnet is built -- it only copies and wraps -- but its dependency
# resolution fails closed, so building it here is what catches a library that
# stopped resolving inside the bundle.
nix "${NIX_OPTS[@]}" build "$PWD?submodules=1#mina-portable-devnet" --no-link

if [[ "$NIX_CACHE_GCP_ID" != "" ]] && [[ "$NIX_CACHE_GCP_SECRET" != "" ]]; then
  mkdir -p $HOME/.aws
  cat <<EOF> $HOME/.aws/credentials
[default]
aws_access_key_id=$NIX_CACHE_GCP_ID
aws_secret_access_key=$NIX_CACHE_GCP_SECRET
EOF

  nix --experimental-features nix-command copy --to "s3://mina-nix-cache?endpoint=https://storage.googleapis.com" --stdin </tmp/nix-paths
fi
