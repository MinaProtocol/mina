#!/bin/sh

set -eou pipefail
set +x

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 branch"
  exit 1
fi

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

# There's an error in CI syncing submodules saying
# "...' is not owned by current user"
# run chown to the current user to fix it
chown -R "${USER}" /workdir

git config --global --add safe.directory /workdir

git fetch
# Nix has issue when performing operations on detached head
# On Ci machine it spit out issues like:
# fatal: reference is not a tree: ....
# error:
#       … while fetching the input 'git+file:///workdir'
#
#       error: program 'git' failed with exit code 128
# That is why we checkout branch explicitly
git checkout $1

git submodule sync
git submodule update --init --recursive

nix "${NIX_OPTS[@]}" build "$PWD?submodules=1#devnet" --no-link

# Test developer terminal with lsp server
nix "${NIX_OPTS[@]}" develop "$PWD?submodules=1#with-lsp" --command bash -c "echo tested"

if [[ "$NIX_CACHE_GCP_ID" != "" ]] && [[ "$NIX_CACHE_GCP_SECRET" != "" ]]; then
  mkdir -p $HOME/.aws
  cat <<EOF> $HOME/.aws/credentials
[default]
aws_access_key_id=$NIX_CACHE_GCP_ID
aws_secret_access_key=$NIX_CACHE_GCP_SECRET
EOF

  nix --experimental-features nix-command copy --to "s3://mina-nix-cache?endpoint=https://storage.googleapis.com" --stdin </tmp/nix-paths
fi
