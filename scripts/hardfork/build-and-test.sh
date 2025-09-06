#!/usr/bin/env bash

# This script builds compatible and current branch with nix
# It handles two cases differently:
# - When given an $1 argument, it treats itself as being run in
#   Buildkite CI and $1 to be "fork" branch that needs to be built
# - When it isn't given any arguments, it assumes it is being
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

# Global variables
declare -g INIT_DIR="$PWD"
declare -g NIX_OPTS=( --accept-flake-config --experimental-features 'nix-command flakes' )
declare -g NIX_SECRET_KEY=""
declare -g NIX_POST_BUILD_HOOK=""

#=============================================================================
# NIX FUNCTIONS
#=============================================================================

# Configure NIX cache with NAR signing secret
setup_nix_cache_secret() {
    if [[ "${NIX_CACHE_NAR_SECRET:-}" != "" ]]; then
        run_cmd_capture bash -c "echo '$NIX_CACHE_NAR_SECRET' > /tmp/nix-cache-secret"
        log_config "set" "NAR signing secret configured"
        NIX_SECRET_KEY=/tmp/nix-cache-secret
    fi
}

# Configure NIX cache with GCP post-build hook
setup_nix_cache_gcp_hook() {
    if [[ "${NIX_CACHE_GCP_ID:-}" != "" ]] && [[ "${NIX_CACHE_GCP_SECRET:-}" != "" ]]; then
        log_config "set" "GCP uploading configured for nix binaries"
        log_file_op "create" "/tmp/nix-post-build"
        cat <<'EOF'> /tmp/nix-post-build
#!/bin/sh

set -eu
set -f # disable globbing
export IFS=' '

echo $OUT_PATHS | tr ' ' '\n' >> /tmp/nix-paths
EOF
        run_cmd chmod +x /tmp/nix-post-build
        NIX_POST_BUILD_HOOK=/tmp/nix-post-build
    fi
}

# Configure NIX options with hooks and secrets
configure_nix_options() {
    if [[ "${NIX_POST_BUILD_HOOK:-}" != "" ]]; then
        NIX_OPTS+=( --post-build-hook "$NIX_POST_BUILD_HOOK" )
    fi
    if [[ "${NIX_SECRET_KEY:-}" != "" ]]; then
        NIX_OPTS+=( --secret-key-files "$NIX_SECRET_KEY" )
    fi
}

# Build NIX targets for a given source directory and output prefix
nix_build_devnet() {
    local source_dir="$1"
    local output_prefix="$2"
    
    log_info "Building devnet for $output_prefix from $source_dir"
    run_cmd nix "${NIX_OPTS[@]}" build "$source_dir?submodules=1#devnet" --out-link "$INIT_DIR/$output_prefix"
    run_cmd nix "${NIX_OPTS[@]}" build "$source_dir?submodules=1#devnet.genesis" --out-link "$INIT_DIR/$output_prefix"
}

# Upload NIX paths to GCP cache
upload_nix_cache_to_gcp() {
    if [[ "${NIX_CACHE_GCP_ID:-}" != "" ]] && [[ "${NIX_CACHE_GCP_SECRET:-}" != "" ]]; then
        log_env_setup "AWS credentials" "for GCP storage"
        run_cmd mkdir -p "$HOME/.aws"
        log_file_op "create" "$HOME/.aws/credentials"
        cat <<EOF > "$HOME/.aws/credentials"
[default]
aws_access_key_id=$NIX_CACHE_GCP_ID
aws_secret_access_key=$NIX_CACHE_GCP_SECRET
EOF
        run_cmd bash -c "nix --experimental-features nix-command copy --to 's3://mina-nix-cache?endpoint=https://storage.googleapis.com' --stdin </tmp/nix-paths"
    fi
}

#=============================================================================
# GIT FUNCTIONS
#=============================================================================

# Clone compatible branch to temporary directory
git_clone_compatible_branch() {
    local temp_dir
    temp_dir=$(run_cmd_capture mktemp -d)
    run_cmd git clone -b compatible --single-branch "https://github.com/MinaProtocol/mina.git" "$temp_dir"
    echo "$temp_dir"
}

# Checkout and prepare branches for CI build
git_prepare_ci_branches() {
    local fork_branch="$1"
    
    log_info "Preparing CI branches: fork=$fork_branch, compatible=compatible"
    run_cmd git checkout -f "$fork_branch"
    run_cmd git checkout -f compatible
    run_cmd git checkout -f "$fork_branch" -- scripts/hardfork
}

# Update git submodules
git_update_submodules() {
    local target_dir="$1"
    
    log_info "Updating git submodules in $target_dir"
    if [[ "$target_dir" != "$PWD" ]]; then
        run_cmd cd "$target_dir"
    fi
    run_cmd git submodule sync --recursive
    run_cmd git submodule update --init --recursive
    if [[ "$target_dir" != "$PWD" ]]; then
        run_cmd cd -
    fi
}

# Checkout fork branch for final build
git_checkout_fork_branch() {
    local fork_branch="$1"
    
    log_info "Checking out fork branch: $fork_branch"
    run_cmd git checkout -f "$fork_branch"
    git_update_submodules "$PWD"
}

#=============================================================================
# ENVIRONMENT SETUP FUNCTIONS
#=============================================================================

# Setup CI environment (timezone, permissions, tools)
setup_ci_environment() {
    log_info "Setting up CI environment"
    
    log_env_setup "timezone" "UTC"
    run_cmd ln -sf /usr/share/zoneinfo/UTC /etc/localtime
    
    run_cmd chown -R "${USER}" /workdir
    run_cmd git config --global --add safe.directory /workdir
    run_cmd git fetch
    
    log_info "Installing required tools"
    run_cmd nix-env -iA unstable.jq
    run_cmd nix-env -iA unstable.curl
    run_cmd nix-env -iA unstable.gnused
    run_cmd nix-env -iA unstable.git-lfs
}

# Initialize NIX cache configuration
init_nix_cache() {
    log_info "Initializing NIX cache configuration"
    setup_nix_cache_secret
    setup_nix_cache_gcp_hook
    configure_nix_options
}

#=============================================================================
# BUILD FUNCTIONS
#=============================================================================

# Build compatible devnet (handles both local and CI modes)
build_compatible_devnet() {
    local fork_branch="${1:-}"
    local compatible_build_dir
    
    if [[ ! -L compatible-devnet ]]; then
        log_info "Building compatible devnet"
        
        if [[ -z "$fork_branch" ]]; then
            # Local mode: clone to temporary directory
            log_info "Local mode: cloning compatible branch to temporary directory"
            compatible_build_dir=$(git_clone_compatible_branch)
            git_update_submodules "$compatible_build_dir"
        else
            # CI mode: use current repository
            log_info "CI mode: using current repository for compatible build"
            git_prepare_ci_branches "$fork_branch"
            compatible_build_dir="$INIT_DIR"
            git_update_submodules "$compatible_build_dir"
        fi
        
        nix_build_devnet "$compatible_build_dir" "compatible-devnet"
        
        if [[ -z "$fork_branch" ]]; then
            # Clean up temporary directory in local mode
            log_info "Cleaning up temporary build directory"
            run_cmd rm -Rf "$compatible_build_dir"
        fi
    else
        log_info "Compatible devnet already exists, skipping build"
    fi
}

# Build fork devnet
build_fork_devnet() {
    local fork_branch="${1:-}"
    
    log_info "Building fork devnet"
    
    if [[ -n "$fork_branch" ]]; then
        git_checkout_fork_branch "$fork_branch"
    fi
    
    nix_build_devnet "$INIT_DIR" "fork-devnet"
}

#=============================================================================
# TEST EXECUTION FUNCTIONS
#=============================================================================

# Generate random slot transaction end if not set
generate_slot_tx_end() {
    SLOT_TX_END=${SLOT_TX_END:-$((RANDOM%120+30))}
    export SLOT_TX_END
    log_info "Using SLOT_TX_END=$SLOT_TX_END"
}

# Execute the hardfork test
run_hardfork_test() {
    log_info "Starting hardfork test execution"
    
    local compatible_mina="compatible-devnet/bin/mina"
    local compatible_genesis="compatible-devnet-genesis/bin/runtime_genesis_ledger"
    local fork_mina="fork-devnet/bin/mina"
    local fork_genesis="fork-devnet-genesis/bin/runtime_genesis_ledger"
    
    run_cmd "$SCRIPT_DIR/test.sh" \
        "$compatible_mina" "$compatible_genesis" \
        "$fork_mina" "$fork_genesis"
        
    log_info "HF test completed successfully"
}

#=============================================================================
# MAIN ORCHESTRATION
#=============================================================================

# Main function that orchestrates the entire build and test process
main() {
    local fork_branch="${1:-}"
    
    log_info "Starting hardfork build and test process"
    if [[ -n "$fork_branch" ]]; then
        log_info "Running in CI mode with fork branch: $fork_branch"
    else
        log_info "Running in local mode"
    fi
    
    # Initialize NIX cache configuration
    init_nix_cache
    
    # Setup CI environment if branch is specified
    if [[ -n "$fork_branch" ]]; then
        setup_ci_environment
    fi
    
    # Build compatible and fork devnets
    build_compatible_devnet "$fork_branch"
    build_fork_devnet "$fork_branch"
    
    # Upload to NIX cache if configured
    upload_nix_cache_to_gcp
    
    # Generate test parameters and run test
    generate_slot_tx_end
    run_hardfork_test
    
    log_info "Build and test process completed successfully"
}

#=============================================================================
# SCRIPT ENTRY POINT
#=============================================================================

# Execute main function with all provided arguments
main "$@"