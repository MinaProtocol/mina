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

# Push everything this job used to the storage-box cache (see lib.sh). The
# store started empty, so "everything" is exactly the closure of the build and
# the dev shell: the paths built here plus the ones substituted, which is what
# seeds the cache on the first run and keeps it complete afterwards.
if [[ -d "${NIX_STORAGEBOX_CACHE%/*}" ]]; then
  nix "${NIX_OPTS[@]}" copy --all --to "$NIX_STORAGEBOX_CACHE_PUSH_URL"
fi
