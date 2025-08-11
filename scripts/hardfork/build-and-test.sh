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

set -euo pipefail

# Source shared libraries
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
# shellcheck disable=SC1090
source "$SCRIPT_DIR/logging.sh"
# shellcheck disable=SC1090
source "$SCRIPT_DIR/cmd_exec.sh"

# Configuration setup functions
setup_nix_cache() {
    local -a nix_opts=( --accept-flake-config --experimental-features 'nix-command flakes' )
    
    if [[ "${NIX_CACHE_NAR_SECRET:-}" != "" ]]; then
        log_info "Configuring NAR signing secret"
        echo "$NIX_CACHE_NAR_SECRET" > /tmp/nix-cache-secret
        NIX_SECRET_KEY=/tmp/nix-cache-secret
    fi

    if [[ "${NIX_CACHE_GCP_ID:-}" != "" ]] && [[ "${NIX_CACHE_GCP_SECRET:-}" != "" ]]; then
        log_info "Configuring GCP uploading for nix binaries"
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

    if [[ "${NIX_POST_BUILD_HOOK:-}" != "" ]]; then
        nix_opts+=( --post-build-hook "$NIX_POST_BUILD_HOOK" )
    fi
    if [[ "${NIX_SECRET_KEY:-}" != "" ]]; then
        nix_opts+=( --secret-key-files "$NIX_SECRET_KEY" )
    fi
    
    printf '%s\n' "${nix_opts[@]}"
}

setup_ci_environment() {
    log_env_setup "CI environment"
    
    log_file_op "create" "/etc/localtime symlink"
    run_cmd ln -sf /usr/share/zoneinfo/UTC /etc/localtime

    log_file_op "chmod" "-R" "recursive ownership for ${USER} on /workdir"
    run_cmd chown -R "${USER}" /workdir
    
    log_config "set" "git safe directory"
    run_cmd git config --global --add safe.directory /workdir
    
    log_cmd git fetch
    git fetch
    
    log_info "Installing required packages via nix"
    run_cmd nix-env -iA unstable.jq
    run_cmd nix-env -iA unstable.curl
    run_cmd nix-env -iA unstable.gnused
    run_cmd nix-env -iA unstable.git-lfs
}

NIX_OPTS=()
readarray -t NIX_OPTS < <(setup_nix_cache)

build_compatible() {
    local compatible_build
    local is_ci_run=$1
    
    if [[ ! -L compatible-devnet ]]; then
        log_info "Building compatible branch"
        
        if [[ "$is_ci_run" == "false" ]]; then
            log_info "Local run: cloning compatible branch to temporary directory"
            compatible_build=$(mktemp -d)
            log_file_op "create" "temporary directory: $compatible_build"
            
            log_cmd git clone -b compatible --single-branch "https://github.com/MinaProtocol/mina.git" "$compatible_build"
            git clone -b compatible --single-branch "https://github.com/MinaProtocol/mina.git" "$compatible_build"
            cd "$compatible_build"
        else
            local branch_name="$2"
            log_info "CI run: using existing repo for compatible branch with fork branch $branch_name"
            log_cmd git checkout -f "$branch_name"
            git checkout -f "$branch_name"
            
            log_cmd git checkout -f compatible
            git checkout -f compatible
            
            log_cmd git checkout -f "$branch_name" -- scripts/hardfork
            git checkout -f "$branch_name" -- scripts/hardfork
            
            compatible_build="$INIT_DIR"
        fi
        
        log_info "Syncing submodules for compatible build"
        log_cmd git submodule sync --recursive
        git submodule sync --recursive
        
        log_cmd git submodule update --init --recursive
        git submodule update --init --recursive
        
        log_info "Building compatible devnet with nix"
        run_cmd nix "${NIX_OPTS[@]}" build "$compatible_build?submodules=1#devnet" --out-link "$INIT_DIR/compatible-devnet"
        run_cmd nix "${NIX_OPTS[@]}" build "$compatible_build?submodules=1#devnet.genesis" --out-link "$INIT_DIR/compatible-devnet-genesis"
        
        if [[ "$is_ci_run" == "false" ]]; then
            cd - > /dev/null
            log_file_op "delete" "temporary compatible build directory: $compatible_build"
            rm -rf "$compatible_build"
            log_info "Cleaned up temporary compatible build directory"
        fi
    else
        log_info "Compatible devnet already exists, skipping build"
    fi
}

build_fork() {
    local is_ci_run=$1
    
    if [[ "$is_ci_run" == "true" ]]; then
        local branch_name="$2"
        log_info "CI run: checking out fork branch $branch_name"
        
        log_cmd git checkout -f "$branch_name"
        git checkout -f "$branch_name"
        
        log_cmd git submodule sync --recursive
        git submodule sync --recursive
        
        log_cmd git submodule update --init --recursive
        git submodule update --init --recursive
    fi
    
    log_info "Building fork devnet with nix"
    run_cmd nix "${NIX_OPTS[@]}" build "$INIT_DIR?submodules=1#devnet" --out-link "$INIT_DIR/fork-devnet"
    run_cmd nix "${NIX_OPTS[@]}" build "$INIT_DIR?submodules=1#devnet.genesis" --out-link "$INIT_DIR/fork-devnet-genesis"
}

upload_to_gcp() {
    if [[ "${NIX_CACHE_GCP_ID:-}" != "" ]] && [[ "${NIX_CACHE_GCP_SECRET:-}" != "" ]]; then
        log_info "Uploading to GCP nix cache"
        
        log_file_op "mkdir" "$HOME/.aws"
        mkdir -p "$HOME/.aws"
        
        log_file_op "create" "$HOME/.aws/credentials with GCP credentials"

        cat <<EOF > "$HOME/.aws/credentials"
[default]
aws_access_key_id=$NIX_CACHE_GCP_ID
aws_secret_access_key=$NIX_CACHE_GCP_SECRET
EOF

        log_file_op "chmod" "600" "$HOME/.aws/credentials"
        chmod 600 "$HOME/.aws/credentials"
        if [[ -f /tmp/nix-paths ]]; then
            log_info "Uploading nix paths to GCP storage"
            run_cmd nix --experimental-features nix-command copy --to "s3://mina-nix-cache?endpoint=https://storage.googleapis.com" --stdin < /tmp/nix-paths
        else
            log_error "No nix paths found to upload"
        fi
    fi
}

# Main execution
INIT_DIR="$PWD"

log_info "Starting build and test script"
log_debug "INIT_DIR: $INIT_DIR"
log_debug "SCRIPT_DIR: $SCRIPT_DIR"

IS_CI_RUN="false"
BRANCH_NAME=""

if [[ $# -gt 0 ]]; then
    IS_CI_RUN="true"
    BRANCH_NAME="$1"
    log_info "Running in CI mode with branch: $BRANCH_NAME"
    setup_ci_environment
else
    log_info "Running in local mode"
fi

build_compatible "$IS_CI_RUN" "$BRANCH_NAME"
build_fork "$IS_CI_RUN" "$BRANCH_NAME"
upload_to_gcp

# Run hard fork test
SLOT_TX_END=${SLOT_TX_END:-$((RANDOM%120+30))}
export SLOT_TX_END

log_config "set" "SLOT_TX_END=$SLOT_TX_END"
log_info "Running HF test with SLOT_TX_END=$SLOT_TX_END"

log_cmd "$SCRIPT_DIR/test.sh" \
    compatible-devnet/bin/mina \
    compatible-devnet-genesis/bin/runtime_genesis_ledger \
    fork-devnet/bin/mina \
    fork-devnet-genesis/bin/runtime_genesis_ledger

if "$SCRIPT_DIR"/test.sh \
    compatible-devnet/bin/mina \
    compatible-devnet-genesis/bin/runtime_genesis_ledger \
    fork-devnet/bin/mina \
    fork-devnet-genesis/bin/runtime_genesis_ledger; then
    log_info "HF test completed successfully"
else
    log_error "HF test failed"
    exit 1
fi
